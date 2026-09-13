import 'package:movenet_data/movenet_data.dart';
import 'package:movenet_domain/movenet_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_controller.g.dart';

@Riverpod(keepAlive: true)
class SettingsController extends _$SettingsController {
  final _storage = SettingsStorage();

  @override
  Future<AppSettings> build() => _storage.load();

  Future<void> saveChanged(
    AppSettings Function(AppSettings current) change,
  ) async {
    final current = state.value ?? const AppSettings();
    final next = change(current);
    state = AsyncData(next);
    await _storage.save(next);
  }
}
