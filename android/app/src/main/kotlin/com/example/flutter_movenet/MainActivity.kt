package com.example.flutter_movenet

import android.content.res.AssetManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.graphics.RectF
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.graphics.Matrix
import org.tensorflow.lite.Interpreter
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.UUID
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val sessions = mutableMapOf<Int, VideoAnalysisSession>()
    private var nextId = 0
    private val moveNet by lazy { runCatching { MoveNetMultiPose(assets) }.getOrNull() }
    private val moViNet by lazy { runCatching { MoViNetClassifier(assets) }.getOrNull() }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "movenet/video_analysis")
            .setMethodCallHandler { call, result ->
                executor.execute {
                    val reply = { value: Any? -> mainHandler.post { result.success(value) } }
                    try {
                        when (call.method) {
                            "open" -> {
                                val poseModel = moveNet
                                    ?: throw IllegalStateException("MoveNet 모델을 불러오지 못했습니다.")
                                val session = VideoAnalysisSession(
                                    call.argument<String>("path")!!,
                                    call.argument<Double>("fps") ?: 15.0,
                                    poseModel,
                                    filesDir,
                                )
                                nextId += 1
                                sessions[nextId] = session
                                reply(
                                    mapOf(
                                        "id" to nextId,
                                        "durationUs" to session.durationUs,
                                        "estimatedFrameCount" to session.estimatedFrameCount,
                                        "width" to session.width,
                                        "height" to session.height,
                                    )
                                )
                            }
                            "next" -> reply(sessions[call.argument<Int>("id")]?.next())
                            "snapshot" -> reply(sessions[call.argument<Int>("id")]?.snapshotLastFrame())
                            "classify" -> {
                                val session = sessions[call.argument<Int>("id")]
                                reply(session?.let { moViNet?.logits(it.clipFrames) }?.map { it.toDouble() })
                            }
                            "close" -> {
                                sessions.remove(call.argument<Int>("id"))?.close()
                                reply(null)
                            }
                            else -> mainHandler.post { result.notImplemented() }
                        }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("video_analysis", e.message, null) }
                    }
                }
            }
    }
}

/** 정확한 프레임(OPTION_CLOSEST)을 목표 fps 간격으로 순서대로 추출해 포즈를 추정하고 MoViNet 클립을 모은다. */
private class VideoAnalysisSession(
    path: String,
    fps: Double,
    private val moveNet: MoveNetMultiPose,
    private val cacheDir: File,
) {
    private val retriever = MediaMetadataRetriever().apply { setDataSource(path) }
    private val intervalUs: Long = (1_000_000 / fps).toLong()
    private val scaledWidth: Int
    private val scaledHeight: Int
    private val keepEvery: Int
    private val rotation: Int
    private var timeUs = 0L
    private var processed = 0
    private var thumbnailSaved = false
    /** 마지막으로 내보낸 프레임. 위험 각도 스냅샷 저장에 쓴다. */
    private var lastFrame: Bitmap? = null
    val clipFrames = mutableListOf<IntArray>()
    val durationUs: Long
    val width: Int
    val height: Int
    val estimatedFrameCount: Int

    init {
        fun meta(key: Int) = retriever.extractMetadata(key)?.toIntOrNull() ?: 0
        durationUs = meta(MediaMetadataRetriever.METADATA_KEY_DURATION).toLong() * 1000
        rotation = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
        val rawWidth = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
        val rawHeight = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
        val swaps = rotation == 90 || rotation == 270
        width = if (swaps) rawHeight else rawWidth
        height = if (swaps) rawWidth else rawHeight
        val scale = min(1.0, MAX_DIMENSION.toDouble() / max(max(width, height), 1))
        scaledWidth = max(1, (width * scale).roundToInt())
        scaledHeight = max(1, (height * scale).roundToInt())
        estimatedFrameCount = max(1, (durationUs / 1_000_000.0 * fps).roundToInt())
        keepEvery = max(1, estimatedFrameCount / MAX_CLIP_FRAMES)
    }

    /** {timeUs, keypoints?(17×[x,y,score]), score?}. 끝이면 null. */
    fun next(): Map<String, Any>? {
        while (timeUs <= durationUs) {
            val current = timeUs
            timeUs += intervalUs
            val bitmap = frameAt(current) ?: continue
            lastFrame?.recycle()
            lastFrame = bitmap.copy(Bitmap.Config.ARGB_8888, false)
            val frame = mutableMapOf<String, Any>("timeUs" to current)
            moveNet.bestPose(bitmap)?.let { (keypoints, score) ->
                frame["keypoints"] = keypoints
                frame["score"] = score.toDouble()
                // 사람이 처음 잡힌 프레임을 히스토리 섬네일로 저장.
                if (!thumbnailSaved) {
                    saveThumbnail(bitmap)?.let {
                        thumbnailSaved = true
                        frame["thumbnailPath"] = it
                    }
                }
                // iOS 앱과 동일하게 회전 전(인코딩) 방향 프레임을 MoViNet에 넣는다.
                if (clipFrames.size < MAX_CLIP_FRAMES && processed % keepEvery == 0) {
                    clipFrames.add(MoViNetClassifier.centerCropPixels(bitmap, -rotation))
                }
            }
            bitmap.recycle()
            processed++
            return frame
        }
        return null
    }

    /** 마지막 프레임을 JPEG로 저장하고 경로를 돌려준다(위험 각도 스냅샷). */
    fun snapshotLastFrame(): String? = lastFrame?.let { saveJpeg(it, "risk") }

    private fun saveThumbnail(bitmap: Bitmap): String? = saveJpeg(bitmap, "thumb")

    private fun saveJpeg(bitmap: Bitmap, prefix: String): String? = runCatching {
        val scale = min(1.0, 320.0 / max(bitmap.width, bitmap.height))
        val thumb = Bitmap.createScaledBitmap(
            bitmap, max(1, (bitmap.width * scale).roundToInt()), max(1, (bitmap.height * scale).roundToInt()), true
        )
        val file = File(cacheDir, "movenet-$prefix-${UUID.randomUUID()}.jpg")
        FileOutputStream(file).use { thumb.compress(Bitmap.CompressFormat.JPEG, 85, it) }
        thumb.recycle()
        file.path
    }.getOrNull()

    private fun frameAt(timeUs: Long): Bitmap? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            retriever.getScaledFrameAtTime(
                timeUs, MediaMetadataRetriever.OPTION_CLOSEST, scaledWidth, scaledHeight
            )
        } else {
            retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST)
        }

    fun close() {
        lastFrame?.recycle()
        lastFrame = null
        retriever.release()
    }

    companion object {
        const val MAX_DIMENSION = 720
        const val MAX_CLIP_FRAMES = 48
    }
}

private fun AssetManager.directBuffer(name: String): ByteBuffer {
    val bytes = open(name).use { it.readBytes() }
    return ByteBuffer.allocateDirect(bytes.size).order(ByteOrder.nativeOrder()).put(bytes).apply { rewind() }
}

/** 입력 uint8 [1,256,256,3](레터박스 RGB), 출력 [1,6,56](사람별 17×[y,x,score] + box + score). */
private class MoveNetMultiPose(assets: AssetManager) {
    private val interpreter = Interpreter(assets.directBuffer("models/movenet_multipose_lightning.tflite")).apply {
        resizeInput(0, intArrayOf(1, SIDE, SIDE, 3))
        allocateTensors()
    }
    private val input = ByteBuffer.allocateDirect(SIDE * SIDE * 3).order(ByteOrder.nativeOrder())
    private val pixels = IntArray(SIDE * SIDE)
    private val output = Array(1) { Array(6) { FloatArray(56) } }

    /** 가장 점수가 높은 사람의 키포인트(표시 이미지 기준 정규화 [x,y,score]×17)와 점수. */
    fun bestPose(bitmap: Bitmap): Pair<FloatArray, Float>? {
        val scale = min(SIDE.toFloat() / bitmap.width, SIDE.toFloat() / bitmap.height)
        val drawW = bitmap.width * scale
        val drawH = bitmap.height * scale
        val offsetX = (SIDE - drawW) / 2
        val offsetY = (SIDE - drawH) / 2
        val letterbox = Bitmap.createBitmap(SIDE, SIDE, Bitmap.Config.ARGB_8888)
        Canvas(letterbox).apply {
            drawColor(Color.BLACK)
            drawBitmap(bitmap, Rect(0, 0, bitmap.width, bitmap.height), RectF(offsetX, offsetY, offsetX + drawW, offsetY + drawH), null)
        }
        letterbox.getPixels(pixels, 0, SIDE, 0, 0, SIDE, SIDE)
        letterbox.recycle()
        input.rewind()
        for (pixel in pixels) {
            input.put((pixel shr 16 and 0xFF).toByte())
            input.put((pixel shr 8 and 0xFF).toByte())
            input.put((pixel and 0xFF).toByte())
        }
        input.rewind()
        interpreter.run(input, output)

        var best: Pair<FloatArray, Float>? = null
        for (person in output[0]) {
            val score = person[55]
            if (score < MIN_PERSON_SCORE || score <= (best?.second ?: 0f)) continue
            val keypoints = FloatArray(17 * 3)
            for (joint in 0 until 17) {
                val y = person[joint * 3]
                val x = person[joint * 3 + 1]
                keypoints[joint * 3] = (x * SIDE - offsetX) / scale / bitmap.width
                keypoints[joint * 3 + 1] = (y * SIDE - offsetY) / scale / bitmap.height
                keypoints[joint * 3 + 2] = person[joint * 3 + 2]
            }
            best = keypoints to score
        }
        return best
    }

    companion object {
        const val SIDE = 256
        const val MIN_PERSON_SCORE = 0.2f
    }
}

/** MoViNet A2 int8(ONNX). 입력 `video` Float32 [1,3,16,224,224](RGB [0,1]), 출력 [1,600] 로짓. iOS 앱 Config.a2와 같은 모델. */
private class MoViNetClassifier(assets: AssetManager) {
    private val env = OrtEnvironment.getEnvironment()
    private val session: OrtSession =
        env.createSession(assets.open("models/movinet_a2_int8.onnx").use { it.readBytes() })

    /** 클립에서 16프레임을 균등 샘플링(부족하면 마지막 프레임 반복)해 600개 로짓을 얻는다. */
    fun logits(frames: List<IntArray>): FloatArray? {
        if (frames.isEmpty()) return null
        val sampled = if (frames.size > FRAME_COUNT) {
            List(FRAME_COUNT) { frames[(it.toDouble() / (FRAME_COUNT - 1) * (frames.size - 1)).toInt()] }
        } else {
            frames
        }
        val plane = SIDE * SIDE
        val channel = FRAME_COUNT * plane
        val data = FloatBuffer.allocate(3 * channel)
        for (t in 0 until FRAME_COUNT) {
            val frame = sampled[min(t, sampled.size - 1)]
            for (pixel in 0 until plane) {
                val argb = frame[pixel]
                data.put(t * plane + pixel, (argb shr 16 and 0xFF) / 255f)
                data.put(channel + t * plane + pixel, (argb shr 8 and 0xFF) / 255f)
                data.put(2 * channel + t * plane + pixel, (argb and 0xFF) / 255f)
            }
        }
        val shape = longArrayOf(1, 3, FRAME_COUNT.toLong(), SIDE.toLong(), SIDE.toLong())
        OnnxTensor.createTensor(env, data, shape).use { tensor ->
            session.run(mapOf("video" to tensor)).use { result ->
                @Suppress("UNCHECKED_CAST")
                return (result[0].value as Array<FloatArray>)[0]
            }
        }
    }

    companion object {
        const val SIDE = 224
        const val FRAME_COUNT = 16

        /** 짧은 변 기준 fill + 중앙 크롭한 SIDE×SIDE ARGB 픽셀(rotationDegrees만큼 회전). */
        fun centerCropPixels(bitmap: Bitmap, rotationDegrees: Int): IntArray {
            val crop = min(bitmap.width, bitmap.height)
            val left = (bitmap.width - crop) / 2
            val top = (bitmap.height - crop) / 2
            var square = Bitmap.createBitmap(SIDE, SIDE, Bitmap.Config.ARGB_8888)
            Canvas(square).drawBitmap(bitmap, Rect(left, top, left + crop, top + crop), Rect(0, 0, SIDE, SIDE), null)
            if (rotationDegrees % 360 != 0) {
                val rotated = Bitmap.createBitmap(
                    square, 0, 0, SIDE, SIDE, Matrix().apply { postRotate(rotationDegrees.toFloat()) }, false
                )
                square.recycle()
                square = rotated
            }
            return IntArray(SIDE * SIDE).also {
                square.getPixels(it, 0, SIDE, 0, 0, SIDE, SIDE)
                square.recycle()
            }
        }
    }
}
