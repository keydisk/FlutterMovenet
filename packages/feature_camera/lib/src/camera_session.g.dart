// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'camera_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CameraSession)
final cameraSessionProvider = CameraSessionProvider._();

final class CameraSessionProvider
    extends $AsyncNotifierProvider<CameraSession, CameraAnalysisState> {
  CameraSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cameraSessionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cameraSessionHash();

  @$internal
  @override
  CameraSession create() => CameraSession();
}

String _$cameraSessionHash() => r'a5dc7ee3fd6df92cb6822cc3cad0527267b290c0';

abstract class _$CameraSession extends $AsyncNotifier<CameraAnalysisState> {
  FutureOr<CameraAnalysisState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<CameraAnalysisState>, CameraAnalysisState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CameraAnalysisState>, CameraAnalysisState>,
              AsyncValue<CameraAnalysisState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
