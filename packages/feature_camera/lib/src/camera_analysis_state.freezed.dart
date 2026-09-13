// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'camera_analysis_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CameraAnalysisState {

 ExerciseType get exercise; Map<ExerciseType, double> get probabilities; int get repetitions; List<CoachingTip> get coaching; bool get showSkeleton; bool get showFps; double get minimumConfidence; PoseFrame? get pose; double get fps;
/// Create a copy of CameraAnalysisState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CameraAnalysisStateCopyWith<CameraAnalysisState> get copyWith => _$CameraAnalysisStateCopyWithImpl<CameraAnalysisState>(this as CameraAnalysisState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CameraAnalysisState&&(identical(other.exercise, exercise) || other.exercise == exercise)&&const DeepCollectionEquality().equals(other.probabilities, probabilities)&&(identical(other.repetitions, repetitions) || other.repetitions == repetitions)&&const DeepCollectionEquality().equals(other.coaching, coaching)&&(identical(other.showSkeleton, showSkeleton) || other.showSkeleton == showSkeleton)&&(identical(other.showFps, showFps) || other.showFps == showFps)&&(identical(other.minimumConfidence, minimumConfidence) || other.minimumConfidence == minimumConfidence)&&(identical(other.pose, pose) || other.pose == pose)&&(identical(other.fps, fps) || other.fps == fps));
}


@override
int get hashCode => Object.hash(runtimeType,exercise,const DeepCollectionEquality().hash(probabilities),repetitions,const DeepCollectionEquality().hash(coaching),showSkeleton,showFps,minimumConfidence,pose,fps);

@override
String toString() {
  return 'CameraAnalysisState(exercise: $exercise, probabilities: $probabilities, repetitions: $repetitions, coaching: $coaching, showSkeleton: $showSkeleton, showFps: $showFps, minimumConfidence: $minimumConfidence, pose: $pose, fps: $fps)';
}


}

/// @nodoc
abstract mixin class $CameraAnalysisStateCopyWith<$Res>  {
  factory $CameraAnalysisStateCopyWith(CameraAnalysisState value, $Res Function(CameraAnalysisState) _then) = _$CameraAnalysisStateCopyWithImpl;
@useResult
$Res call({
 ExerciseType exercise, Map<ExerciseType, double> probabilities, int repetitions, List<CoachingTip> coaching, bool showSkeleton, bool showFps, double minimumConfidence, PoseFrame? pose, double fps
});




}
/// @nodoc
class _$CameraAnalysisStateCopyWithImpl<$Res>
    implements $CameraAnalysisStateCopyWith<$Res> {
  _$CameraAnalysisStateCopyWithImpl(this._self, this._then);

  final CameraAnalysisState _self;
  final $Res Function(CameraAnalysisState) _then;

/// Create a copy of CameraAnalysisState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? exercise = null,Object? probabilities = null,Object? repetitions = null,Object? coaching = null,Object? showSkeleton = null,Object? showFps = null,Object? minimumConfidence = null,Object? pose = freezed,Object? fps = null,}) {
  return _then(_self.copyWith(
exercise: null == exercise ? _self.exercise : exercise // ignore: cast_nullable_to_non_nullable
as ExerciseType,probabilities: null == probabilities ? _self.probabilities : probabilities // ignore: cast_nullable_to_non_nullable
as Map<ExerciseType, double>,repetitions: null == repetitions ? _self.repetitions : repetitions // ignore: cast_nullable_to_non_nullable
as int,coaching: null == coaching ? _self.coaching : coaching // ignore: cast_nullable_to_non_nullable
as List<CoachingTip>,showSkeleton: null == showSkeleton ? _self.showSkeleton : showSkeleton // ignore: cast_nullable_to_non_nullable
as bool,showFps: null == showFps ? _self.showFps : showFps // ignore: cast_nullable_to_non_nullable
as bool,minimumConfidence: null == minimumConfidence ? _self.minimumConfidence : minimumConfidence // ignore: cast_nullable_to_non_nullable
as double,pose: freezed == pose ? _self.pose : pose // ignore: cast_nullable_to_non_nullable
as PoseFrame?,fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [CameraAnalysisState].
extension CameraAnalysisStatePatterns on CameraAnalysisState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CameraAnalysisState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CameraAnalysisState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CameraAnalysisState value)  $default,){
final _that = this;
switch (_that) {
case _CameraAnalysisState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CameraAnalysisState value)?  $default,){
final _that = this;
switch (_that) {
case _CameraAnalysisState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ExerciseType exercise,  Map<ExerciseType, double> probabilities,  int repetitions,  List<CoachingTip> coaching,  bool showSkeleton,  bool showFps,  double minimumConfidence,  PoseFrame? pose,  double fps)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CameraAnalysisState() when $default != null:
return $default(_that.exercise,_that.probabilities,_that.repetitions,_that.coaching,_that.showSkeleton,_that.showFps,_that.minimumConfidence,_that.pose,_that.fps);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ExerciseType exercise,  Map<ExerciseType, double> probabilities,  int repetitions,  List<CoachingTip> coaching,  bool showSkeleton,  bool showFps,  double minimumConfidence,  PoseFrame? pose,  double fps)  $default,) {final _that = this;
switch (_that) {
case _CameraAnalysisState():
return $default(_that.exercise,_that.probabilities,_that.repetitions,_that.coaching,_that.showSkeleton,_that.showFps,_that.minimumConfidence,_that.pose,_that.fps);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ExerciseType exercise,  Map<ExerciseType, double> probabilities,  int repetitions,  List<CoachingTip> coaching,  bool showSkeleton,  bool showFps,  double minimumConfidence,  PoseFrame? pose,  double fps)?  $default,) {final _that = this;
switch (_that) {
case _CameraAnalysisState() when $default != null:
return $default(_that.exercise,_that.probabilities,_that.repetitions,_that.coaching,_that.showSkeleton,_that.showFps,_that.minimumConfidence,_that.pose,_that.fps);case _:
  return null;

}
}

}

/// @nodoc


class _CameraAnalysisState implements CameraAnalysisState {
  const _CameraAnalysisState({required this.exercise, required final  Map<ExerciseType, double> probabilities, required this.repetitions, required final  List<CoachingTip> coaching, required this.showSkeleton, required this.showFps, required this.minimumConfidence, this.pose, this.fps = 0}): _probabilities = probabilities,_coaching = coaching;
  

@override final  ExerciseType exercise;
 final  Map<ExerciseType, double> _probabilities;
@override Map<ExerciseType, double> get probabilities {
  if (_probabilities is EqualUnmodifiableMapView) return _probabilities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_probabilities);
}

@override final  int repetitions;
 final  List<CoachingTip> _coaching;
@override List<CoachingTip> get coaching {
  if (_coaching is EqualUnmodifiableListView) return _coaching;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_coaching);
}

@override final  bool showSkeleton;
@override final  bool showFps;
@override final  double minimumConfidence;
@override final  PoseFrame? pose;
@override@JsonKey() final  double fps;

/// Create a copy of CameraAnalysisState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CameraAnalysisStateCopyWith<_CameraAnalysisState> get copyWith => __$CameraAnalysisStateCopyWithImpl<_CameraAnalysisState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CameraAnalysisState&&(identical(other.exercise, exercise) || other.exercise == exercise)&&const DeepCollectionEquality().equals(other._probabilities, _probabilities)&&(identical(other.repetitions, repetitions) || other.repetitions == repetitions)&&const DeepCollectionEquality().equals(other._coaching, _coaching)&&(identical(other.showSkeleton, showSkeleton) || other.showSkeleton == showSkeleton)&&(identical(other.showFps, showFps) || other.showFps == showFps)&&(identical(other.minimumConfidence, minimumConfidence) || other.minimumConfidence == minimumConfidence)&&(identical(other.pose, pose) || other.pose == pose)&&(identical(other.fps, fps) || other.fps == fps));
}


@override
int get hashCode => Object.hash(runtimeType,exercise,const DeepCollectionEquality().hash(_probabilities),repetitions,const DeepCollectionEquality().hash(_coaching),showSkeleton,showFps,minimumConfidence,pose,fps);

@override
String toString() {
  return 'CameraAnalysisState(exercise: $exercise, probabilities: $probabilities, repetitions: $repetitions, coaching: $coaching, showSkeleton: $showSkeleton, showFps: $showFps, minimumConfidence: $minimumConfidence, pose: $pose, fps: $fps)';
}


}

/// @nodoc
abstract mixin class _$CameraAnalysisStateCopyWith<$Res> implements $CameraAnalysisStateCopyWith<$Res> {
  factory _$CameraAnalysisStateCopyWith(_CameraAnalysisState value, $Res Function(_CameraAnalysisState) _then) = __$CameraAnalysisStateCopyWithImpl;
@override @useResult
$Res call({
 ExerciseType exercise, Map<ExerciseType, double> probabilities, int repetitions, List<CoachingTip> coaching, bool showSkeleton, bool showFps, double minimumConfidence, PoseFrame? pose, double fps
});




}
/// @nodoc
class __$CameraAnalysisStateCopyWithImpl<$Res>
    implements _$CameraAnalysisStateCopyWith<$Res> {
  __$CameraAnalysisStateCopyWithImpl(this._self, this._then);

  final _CameraAnalysisState _self;
  final $Res Function(_CameraAnalysisState) _then;

/// Create a copy of CameraAnalysisState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? exercise = null,Object? probabilities = null,Object? repetitions = null,Object? coaching = null,Object? showSkeleton = null,Object? showFps = null,Object? minimumConfidence = null,Object? pose = freezed,Object? fps = null,}) {
  return _then(_CameraAnalysisState(
exercise: null == exercise ? _self.exercise : exercise // ignore: cast_nullable_to_non_nullable
as ExerciseType,probabilities: null == probabilities ? _self._probabilities : probabilities // ignore: cast_nullable_to_non_nullable
as Map<ExerciseType, double>,repetitions: null == repetitions ? _self.repetitions : repetitions // ignore: cast_nullable_to_non_nullable
as int,coaching: null == coaching ? _self._coaching : coaching // ignore: cast_nullable_to_non_nullable
as List<CoachingTip>,showSkeleton: null == showSkeleton ? _self.showSkeleton : showSkeleton // ignore: cast_nullable_to_non_nullable
as bool,showFps: null == showFps ? _self.showFps : showFps // ignore: cast_nullable_to_non_nullable
as bool,minimumConfidence: null == minimumConfidence ? _self.minimumConfidence : minimumConfidence // ignore: cast_nullable_to_non_nullable
as double,pose: freezed == pose ? _self.pose : pose // ignore: cast_nullable_to_non_nullable
as PoseFrame?,fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
