import AVFoundation
import CoreImage
import CoreML
import Flutter

/// `movenet/video_analysis`: 영상을 AVAssetReader로 순차 디코드하면서 프레임마다
/// MoveNet MultiPose Lightning으로 포즈를 추정하고, MoViNet A0 분류용 클립 프레임을 모은다.
/// 분석 순서는 iOS 앱(Movenet_iOS)의 VideoAnalysisPreprocessor와 같다.
final class VideoAnalysisChannel {
  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "movenet.video-analysis")
  private var sessions: [Int: VideoAnalysisSession] = [:]
  private var nextID = 0
  private lazy var moveNet = MoveNetMultiPose()
  private lazy var moViNet = MoViNetClassifier()

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "movenet/video_analysis", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.queue.async { self?.handle(call, result: result) }
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let reply: (Any?) -> Void = { value in DispatchQueue.main.async { result(value) } }
    switch call.method {
    case "open":
      guard let path = args["path"] as? String else {
        return reply(FlutterError(code: "bad_args", message: "path required", details: nil))
      }
      guard let moveNet else {
        return reply(FlutterError(code: "model_unavailable", message: "MoveNet 모델을 불러오지 못했습니다.", details: nil))
      }
      do {
        let session = try VideoAnalysisSession(
          url: URL(fileURLWithPath: path),
          fps: args["fps"] as? Double ?? 15,
          moveNet: moveNet
        )
        nextID += 1
        sessions[nextID] = session
        reply([
          "id": nextID,
          "durationUs": session.durationUs,
          "estimatedFrameCount": session.estimatedFrameCount,
          "width": session.displaySize.width,
          "height": session.displaySize.height,
        ])
      } catch {
        reply(FlutterError(code: "open_failed", message: error.localizedDescription, details: nil))
      }
    case "next":
      guard let id = args["id"] as? Int, let session = sessions[id] else { return reply(nil) }
      reply(session.next())
    case "snapshot":
      guard let id = args["id"] as? Int, let session = sessions[id] else { return reply(nil) }
      reply(session.snapshotLastFrame())
    case "classify":
      guard let id = args["id"] as? Int, let session = sessions[id], let moViNet else { return reply(nil) }
      reply(moViNet.logits(frames: session.clipFrames).map { $0.map(Double.init) })
    case "close":
      if let id = args["id"] as? Int { sessions.removeValue(forKey: id)?.cancel() }
      reply(nil)
    default:
      reply(FlutterMethodNotImplemented)
    }
  }
}

// MARK: - 세션: 순차 디코드 + 포즈 + 클립 수집

final class VideoAnalysisSession {
  enum SessionError: Error { case noVideoTrack, cannotStartReading }

  /// MoViNet 분류용으로 보관할 최대 프레임 수(iOS 앱과 동일).
  private static let maxClipFrames = 48

  let estimatedFrameCount: Int
  let durationUs: Int
  let displaySize: CGSize
  private(set) var clipFrames: [[UInt8]] = []
  private let reader: AVAssetReader
  private let output: AVAssetReaderTrackOutput
  private let orientation: CGImagePropertyOrientation
  private let sampleInterval: Double
  private let keepEvery: Int
  private let moveNet: MoveNetMultiPose
  private let context = CIContext(options: [.cacheIntermediates: false])
  private var lastEmitted = -Double.greatestFiniteMagnitude
  private var processed = 0
  private var thumbnailSaved = false
  /// 마지막으로 내보낸 프레임(표시 방향). 위험 각도 스냅샷 저장에 쓴다.
  private var lastFrame: CIImage?

  init(url: URL, fps: Double, moveNet: MoveNetMultiPose) throws {
    self.moveNet = moveNet
    let asset = AVURLAsset(url: url)
    guard let track = asset.tracks(withMediaType: .video).first else { throw SessionError.noVideoTrack }
    let transform = track.preferredTransform
    if abs(transform.b) == 1, abs(transform.c) == 1 {
      orientation = transform.b > 0 ? .right : .left
    } else if transform.a < 0, transform.d < 0 {
      orientation = .down
    } else {
      orientation = .up
    }
    let natural = track.naturalSize
    let swaps = orientation == .left || orientation == .right
    displaySize = swaps ? CGSize(width: natural.height, height: natural.width) : natural
    sampleInterval = fps > 0 ? 1 / fps : 0
    let seconds = asset.duration.seconds.isFinite ? asset.duration.seconds : 0
    durationUs = Int((seconds * 1_000_000).rounded())
    estimatedFrameCount = max(1, Int((seconds * fps).rounded()))
    keepEvery = max(1, estimatedFrameCount / Self.maxClipFrames)

    reader = try AVAssetReader(asset: asset)
    output = AVAssetReaderTrackOutput(
      track: track,
      outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    )
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else { throw SessionError.cannotStartReading }
    reader.add(output)
    guard reader.startReading() else { throw SessionError.cannotStartReading }
  }

  /// 다음 샘플 프레임의 {timeUs, keypoints?(17×[x,y,score]), score?, thumbnailPath?}. 끝이면 nil.
  func next() -> [String: Any]? {
    while reader.status == .reading, let sample = output.copyNextSampleBuffer() {
      let pts = CMSampleBufferGetPresentationTimeStamp(sample).seconds
      guard pts.isFinite, pts - lastEmitted >= sampleInterval,
            let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }
      lastEmitted = pts
      var image = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
      image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))

      lastFrame = image
      var frame: [String: Any] = ["timeUs": Int((pts * 1_000_000).rounded())]
      if let cgImage = context.createCGImage(image, from: image.extent),
         let pose = moveNet.bestPose(in: cgImage) {
        frame["keypoints"] = FlutterStandardTypedData(float32: pose.keypoints.withUnsafeBufferPointer { Data(buffer: $0) })
        frame["score"] = Double(pose.score)
        // 사람이 처음 잡힌 프레임을 히스토리 섬네일로 저장(iOS 앱과 동일).
        if !thumbnailSaved, let path = saveThumbnail(cgImage) {
          thumbnailSaved = true
          frame["thumbnailPath"] = path
        }
        // iOS 앱과 동일하게 회전 전(인코딩) 버퍼를 MoViNet에 넣는다.
        if clipFrames.count < Self.maxClipFrames, processed % keepEvery == 0,
           let rgba = MoViNetClassifier.rgbaBytes(
             from: CIImage(cvPixelBuffer: pixelBuffer), context: context
           ) {
          clipFrames.append(rgba)
        }
      }
      processed += 1
      return frame
    }
    return nil
  }

  /// 마지막 프레임을 JPEG로 저장하고 경로를 돌려준다(위험 각도 스냅샷).
  func snapshotLastFrame() -> String? {
    guard let frame = lastFrame, let image = context.createCGImage(frame, from: frame.extent)
    else { return nil }
    return saveJPEG(image, prefix: "risk")
  }

  private func saveThumbnail(_ image: CGImage) -> String? { saveJPEG(image, prefix: "thumb") }

  private func saveJPEG(_ image: CGImage, prefix: String) -> String? {
    let side = max(image.width, image.height)
    let scale = min(1, 320 / CGFloat(side))
    let scaled = CIImage(cgImage: image).transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let data = context.jpegRepresentation(of: scaled, colorSpace: colorSpace, options: [:]),
          let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
          ) else { return nil }
    let file = directory.appendingPathComponent("movenet-\(prefix)-\(UUID().uuidString).jpg")
    return (try? data.write(to: file)) == nil ? nil : file.path
  }

  func cancel() {
    if reader.status == .reading { reader.cancelReading() }
  }
}

// MARK: - MoveNet MultiPose Lightning

/// 입력 `input` Int32 [1,256,256,3](레터박스 RGB), 출력 `Identity` [1,6,56]
/// (사람별 17×[y,x,score] + [ymin,xmin,ymax,xmax,score]).
final class MoveNetMultiPose {
  struct Pose {
    /// 17×[x,y,score], 표시 이미지 기준 정규화 좌표.
    let keypoints: [Float]
    let score: Float
  }

  private static let side = 256
  private static let minPersonScore: Float = 0.2
  private let model: MLModel

  init?() {
    guard let url = Bundle.main.url(forResource: "movenet_multipose_lightning", withExtension: "mlmodelc"),
          let model = try? MLModel(contentsOf: url) else { return nil }
    self.model = model
  }

  /// 가장 점수가 높은 사람의 키포인트.
  func bestPose(in image: CGImage) -> Pose? {
    let side = Self.side
    let imageW = CGFloat(image.width), imageH = CGFloat(image.height)
    guard imageW > 0, imageH > 0 else { return nil }
    let scale = min(CGFloat(side) / imageW, CGFloat(side) / imageH)
    let drawW = imageW * scale, drawH = imageH * scale
    let offsetX = (CGFloat(side) - drawW) / 2, offsetY = (CGFloat(side) - drawH) / 2

    let bytesPerRow = side * 4
    var buffer = [UInt8](repeating: 0, count: bytesPerRow * side)
    let drawn: Bool = buffer.withUnsafeMutableBytes { raw in
      guard let context = CGContext(
        data: raw.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
      ) else { return false }
      context.draw(image, in: CGRect(x: offsetX, y: offsetY, width: drawW, height: drawH))
      return true
    }
    guard drawn,
          let input = try? MLMultiArray(shape: [1, NSNumber(value: side), NSNumber(value: side), 3], dataType: .int32)
    else { return nil }
    let pointer = input.dataPointer.bindMemory(to: Int32.self, capacity: input.count)
    for pixel in 0..<(side * side) {
      pointer[pixel * 3] = Int32(buffer[pixel * 4])
      pointer[pixel * 3 + 1] = Int32(buffer[pixel * 4 + 1])
      pointer[pixel * 3 + 2] = Int32(buffer[pixel * 4 + 2])
    }

    guard let provider = try? MLDictionaryFeatureProvider(dictionary: ["input": input]),
          let output = try? model.prediction(from: provider),
          let array = output.featureValue(for: "Identity")?.multiArrayValue else { return nil }

    var best: Pose?
    for person in 0..<6 {
      let base = person * 56
      let score = array[base + 55].floatValue
      guard score >= Self.minPersonScore, score > (best?.score ?? 0) else { continue }
      var keypoints = [Float](repeating: 0, count: 17 * 3)
      for joint in 0..<17 {
        let y = CGFloat(array[base + joint * 3].floatValue)
        let x = CGFloat(array[base + joint * 3 + 1].floatValue)
        keypoints[joint * 3] = Float((x * CGFloat(side) - offsetX) / scale / imageW)
        keypoints[joint * 3 + 1] = Float((y * CGFloat(side) - offsetY) / scale / imageH)
        keypoints[joint * 3 + 2] = array[base + joint * 3 + 2].floatValue
      }
      best = Pose(keypoints: keypoints, score: score)
    }
    return best
  }
}

// MARK: - MoViNet A2 (Kinetics-600)

/// 입력 `video` Float32 [1,3,16,224,224](RGB [0,1]), 출력 [1,600] 로짓. iOS 앱 Config.a2와 동일.
final class MoViNetClassifier {
  static let side = 224
  private static let frameCount = 16
  private let model: MLModel

  init?() {
    guard let url = Bundle.main.url(forResource: "movinet_a2_int8", withExtension: "mlmodelc"),
          let model = try? MLModel(contentsOf: url) else { return nil }
    self.model = model
  }

  /// 짧은 변 기준 fill + 중앙 크롭한 side×side RGBA8 바이트(iOS 앱과 동일).
  static func rgbaBytes(from image: CIImage, context: CIContext) -> [UInt8]? {
    let extent = image.extent
    guard extent.width > 0, extent.height > 0 else { return nil }
    let fill = CGFloat(side) / min(extent.width, extent.height)
    let scaled = image.transformed(by: CGAffineTransform(scaleX: fill, y: fill))
    let crop = CGRect(
      x: scaled.extent.minX + (scaled.extent.width - CGFloat(side)) / 2,
      y: scaled.extent.minY + (scaled.extent.height - CGFloat(side)) / 2,
      width: CGFloat(side), height: CGFloat(side)
    )
    var bytes = [UInt8](repeating: 0, count: side * side * 4)
    bytes.withUnsafeMutableBytes { raw in
      context.render(
        scaled.cropped(to: crop), toBitmap: raw.baseAddress!, rowBytes: side * 4,
        bounds: crop, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()
      )
    }
    return bytes
  }

  /// 클립에서 16프레임을 균등 샘플링(부족하면 마지막 프레임 반복)해 600개 로짓을 얻는다.
  func logits(frames: [[UInt8]]) -> [Float]? {
    guard !frames.isEmpty else { return nil }
    let t = Self.frameCount, s = Self.side
    let sampled: [[UInt8]] = frames.count > t
      ? (0..<t).map { frames[Int(Double($0) / Double(t - 1) * Double(frames.count - 1))] }
      : frames
    guard let input = try? MLMultiArray(
      shape: [1, 3, NSNumber(value: t), NSNumber(value: s), NSNumber(value: s)], dataType: .float32
    ) else { return nil }
    let pointer = input.dataPointer.bindMemory(to: Float.self, capacity: input.count)
    let plane = s * s, channel = t * plane
    for ti in 0..<t {
      let rgba = sampled[min(ti, sampled.count - 1)]
      for pixel in 0..<plane {
        pointer[ti * plane + pixel] = Float(rgba[pixel * 4]) / 255
        pointer[channel + ti * plane + pixel] = Float(rgba[pixel * 4 + 1]) / 255
        pointer[2 * channel + ti * plane + pixel] = Float(rgba[pixel * 4 + 2]) / 255
      }
    }
    guard let provider = try? MLDictionaryFeatureProvider(dictionary: ["video": input]),
          let output = try? model.prediction(from: provider) else { return nil }
    for name in output.featureNames {
      if let array = output.featureValue(for: name)?.multiArrayValue {
        return (0..<array.count).map { array[$0].floatValue }
      }
    }
    return nil
  }
}
