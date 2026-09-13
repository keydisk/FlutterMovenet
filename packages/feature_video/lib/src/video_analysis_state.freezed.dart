// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_analysis_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VideoAnalysisState {

 List<AnalysisRecord> get history; bool get isAnalyzing; double get progress; String? get selectedPath; AnalysisRecord? get latest;
/// Create a copy of VideoAnalysisState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoAnalysisStateCopyWith<VideoAnalysisState> get copyWith => _$VideoAnalysisStateCopyWithImpl<VideoAnalysisState>(this as VideoAnalysisState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoAnalysisState&&const DeepCollectionEquality().equals(other.history, history)&&(identical(other.isAnalyzing, isAnalyzing) || other.isAnalyzing == isAnalyzing)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.selectedPath, selectedPath) || other.selectedPath == selectedPath)&&(identical(other.latest, latest) || other.latest == latest));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(history),isAnalyzing,progress,selectedPath,latest);

@override
String toString() {
  return 'VideoAnalysisState(history: $history, isAnalyzing: $isAnalyzing, progress: $progress, selectedPath: $selectedPath, latest: $latest)';
}


}

/// @nodoc
abstract mixin class $VideoAnalysisStateCopyWith<$Res>  {
  factory $VideoAnalysisStateCopyWith(VideoAnalysisState value, $Res Function(VideoAnalysisState) _then) = _$VideoAnalysisStateCopyWithImpl;
@useResult
$Res call({
 List<AnalysisRecord> history, bool isAnalyzing, double progress, String? selectedPath, AnalysisRecord? latest
});




}
/// @nodoc
class _$VideoAnalysisStateCopyWithImpl<$Res>
    implements $VideoAnalysisStateCopyWith<$Res> {
  _$VideoAnalysisStateCopyWithImpl(this._self, this._then);

  final VideoAnalysisState _self;
  final $Res Function(VideoAnalysisState) _then;

/// Create a copy of VideoAnalysisState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? history = null,Object? isAnalyzing = null,Object? progress = null,Object? selectedPath = freezed,Object? latest = freezed,}) {
  return _then(_self.copyWith(
history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as List<AnalysisRecord>,isAnalyzing: null == isAnalyzing ? _self.isAnalyzing : isAnalyzing // ignore: cast_nullable_to_non_nullable
as bool,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,selectedPath: freezed == selectedPath ? _self.selectedPath : selectedPath // ignore: cast_nullable_to_non_nullable
as String?,latest: freezed == latest ? _self.latest : latest // ignore: cast_nullable_to_non_nullable
as AnalysisRecord?,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoAnalysisState].
extension VideoAnalysisStatePatterns on VideoAnalysisState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoAnalysisState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoAnalysisState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoAnalysisState value)  $default,){
final _that = this;
switch (_that) {
case _VideoAnalysisState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoAnalysisState value)?  $default,){
final _that = this;
switch (_that) {
case _VideoAnalysisState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AnalysisRecord> history,  bool isAnalyzing,  double progress,  String? selectedPath,  AnalysisRecord? latest)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoAnalysisState() when $default != null:
return $default(_that.history,_that.isAnalyzing,_that.progress,_that.selectedPath,_that.latest);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AnalysisRecord> history,  bool isAnalyzing,  double progress,  String? selectedPath,  AnalysisRecord? latest)  $default,) {final _that = this;
switch (_that) {
case _VideoAnalysisState():
return $default(_that.history,_that.isAnalyzing,_that.progress,_that.selectedPath,_that.latest);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AnalysisRecord> history,  bool isAnalyzing,  double progress,  String? selectedPath,  AnalysisRecord? latest)?  $default,) {final _that = this;
switch (_that) {
case _VideoAnalysisState() when $default != null:
return $default(_that.history,_that.isAnalyzing,_that.progress,_that.selectedPath,_that.latest);case _:
  return null;

}
}

}

/// @nodoc


class _VideoAnalysisState implements VideoAnalysisState {
  const _VideoAnalysisState({required final  List<AnalysisRecord> history, this.isAnalyzing = false, this.progress = 0, this.selectedPath, this.latest}): _history = history;
  

 final  List<AnalysisRecord> _history;
@override List<AnalysisRecord> get history {
  if (_history is EqualUnmodifiableListView) return _history;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_history);
}

@override@JsonKey() final  bool isAnalyzing;
@override@JsonKey() final  double progress;
@override final  String? selectedPath;
@override final  AnalysisRecord? latest;

/// Create a copy of VideoAnalysisState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoAnalysisStateCopyWith<_VideoAnalysisState> get copyWith => __$VideoAnalysisStateCopyWithImpl<_VideoAnalysisState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoAnalysisState&&const DeepCollectionEquality().equals(other._history, _history)&&(identical(other.isAnalyzing, isAnalyzing) || other.isAnalyzing == isAnalyzing)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.selectedPath, selectedPath) || other.selectedPath == selectedPath)&&(identical(other.latest, latest) || other.latest == latest));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_history),isAnalyzing,progress,selectedPath,latest);

@override
String toString() {
  return 'VideoAnalysisState(history: $history, isAnalyzing: $isAnalyzing, progress: $progress, selectedPath: $selectedPath, latest: $latest)';
}


}

/// @nodoc
abstract mixin class _$VideoAnalysisStateCopyWith<$Res> implements $VideoAnalysisStateCopyWith<$Res> {
  factory _$VideoAnalysisStateCopyWith(_VideoAnalysisState value, $Res Function(_VideoAnalysisState) _then) = __$VideoAnalysisStateCopyWithImpl;
@override @useResult
$Res call({
 List<AnalysisRecord> history, bool isAnalyzing, double progress, String? selectedPath, AnalysisRecord? latest
});




}
/// @nodoc
class __$VideoAnalysisStateCopyWithImpl<$Res>
    implements _$VideoAnalysisStateCopyWith<$Res> {
  __$VideoAnalysisStateCopyWithImpl(this._self, this._then);

  final _VideoAnalysisState _self;
  final $Res Function(_VideoAnalysisState) _then;

/// Create a copy of VideoAnalysisState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? history = null,Object? isAnalyzing = null,Object? progress = null,Object? selectedPath = freezed,Object? latest = freezed,}) {
  return _then(_VideoAnalysisState(
history: null == history ? _self._history : history // ignore: cast_nullable_to_non_nullable
as List<AnalysisRecord>,isAnalyzing: null == isAnalyzing ? _self.isAnalyzing : isAnalyzing // ignore: cast_nullable_to_non_nullable
as bool,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,selectedPath: freezed == selectedPath ? _self.selectedPath : selectedPath // ignore: cast_nullable_to_non_nullable
as String?,latest: freezed == latest ? _self.latest : latest // ignore: cast_nullable_to_non_nullable
as AnalysisRecord?,
  ));
}


}

// dart format on
