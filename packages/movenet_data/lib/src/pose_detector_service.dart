import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:movenet_domain/movenet_domain.dart';

class PoseDetectorService {
  PoseDetectorService({PoseDetectionMode mode = PoseDetectionMode.stream})
    : _detector = PoseDetector(options: PoseDetectorOptions(mode: mode));

  PoseDetectorService.single()
    : _detector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.single),
      );

  final PoseDetector _detector;

  Future<PoseFrame?> detectFile(String path, Duration timestamp) async {
    final image = await _decodeSize(path);
    final poses = await _detector.processImage(InputImage.fromFilePath(path));
    if (poses.isEmpty) return null;
    return _mapPose(
      poses.first,
      image.width.toDouble(),
      image.height.toDouble(),
      timestamp,
    );
  }

  Future<PoseFrame?> detectCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation orientation,
    required Duration timestamp,
  }) async {
    final input = _cameraInputImage(image, camera, orientation);
    if (input == null) return null;
    final poses = await _detector.processImage(input.$1);
    if (poses.isEmpty) return null;
    return _mapPose(poses.first, input.$2, input.$3, timestamp);
  }

  Future<void> close() => _detector.close();

  Future<ui.Image> _decodeSize(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }

  (InputImage, double, double)? _cameraInputImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation orientation,
  ) {
    final rotation = _rotation(camera, orientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null || image.planes.length != 1) {
      return null;
    }
    if (defaultTargetPlatform == TargetPlatform.android &&
        format != InputImageFormat.nv21) {
      return null;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        format != InputImageFormat.bgra8888) {
      return null;
    }
    final metadata = InputImageMetadata(
      size: ui.Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );
    final rotated =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    return (
      InputImage.fromBytes(bytes: image.planes.first.bytes, metadata: metadata),
      (rotated ? image.height : image.width).toDouble(),
      (rotated ? image.width : image.height).toDouble(),
    );
  }

  InputImageRotation? _rotation(
    CameraDescription camera,
    DeviceOrientation orientation,
  ) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    }
    const compensation = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final device = compensation[orientation];
    if (device == null) return null;
    final value = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + device) % 360
        : (camera.sensorOrientation - device + 360) % 360;
    return InputImageRotationValue.fromRawValue(value);
  }

  PoseFrame _mapPose(
    Pose pose,
    double width,
    double height,
    Duration timestamp,
  ) {
    final points = <Joint, PosePoint>{};
    for (final entry in _landmarks.entries) {
      final landmark = pose.landmarks[entry.value];
      if (landmark != null) {
        points[entry.key] = PosePoint(
          x: (landmark.x / width).clamp(0, 1),
          y: (landmark.y / height).clamp(0, 1),
          confidence: landmark.likelihood,
        );
      }
    }
    return PoseFrame(points: points, timestamp: timestamp);
  }

  static const _landmarks = {
    Joint.nose: PoseLandmarkType.nose,
    Joint.leftShoulder: PoseLandmarkType.leftShoulder,
    Joint.rightShoulder: PoseLandmarkType.rightShoulder,
    Joint.leftElbow: PoseLandmarkType.leftElbow,
    Joint.rightElbow: PoseLandmarkType.rightElbow,
    Joint.leftWrist: PoseLandmarkType.leftWrist,
    Joint.rightWrist: PoseLandmarkType.rightWrist,
    Joint.leftHip: PoseLandmarkType.leftHip,
    Joint.rightHip: PoseLandmarkType.rightHip,
    Joint.leftKnee: PoseLandmarkType.leftKnee,
    Joint.rightKnee: PoseLandmarkType.rightKnee,
    Joint.leftAnkle: PoseLandmarkType.leftAnkle,
    Joint.rightAnkle: PoseLandmarkType.rightAnkle,
  };
}
