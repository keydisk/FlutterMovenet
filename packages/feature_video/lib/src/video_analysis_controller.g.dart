// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_analysis_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VideoAnalysisController)
final videoAnalysisControllerProvider = VideoAnalysisControllerProvider._();

final class VideoAnalysisControllerProvider
    extends
        $AsyncNotifierProvider<VideoAnalysisController, VideoAnalysisState> {
  VideoAnalysisControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoAnalysisControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoAnalysisControllerHash();

  @$internal
  @override
  VideoAnalysisController create() => VideoAnalysisController();
}

String _$videoAnalysisControllerHash() =>
    r'00f258ab68cd7cafb61d49b695f01f674db16798';

abstract class _$VideoAnalysisController
    extends $AsyncNotifier<VideoAnalysisState> {
  FutureOr<VideoAnalysisState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<VideoAnalysisState>, VideoAnalysisState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VideoAnalysisState>, VideoAnalysisState>,
              AsyncValue<VideoAnalysisState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
