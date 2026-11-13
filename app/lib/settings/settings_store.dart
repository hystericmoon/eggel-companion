import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Small key-value file for app settings. No plugin: a JSON file in the
/// per-user app folder. Every failure falls back to defaults, never a crash.
abstract class SettingsStore {
  Map<String, Object?> load();
  void save(Map<String, Object?> values);
}

class MemorySettingsStore implements SettingsStore {
  Map<String, Object?> data = {};

  @override
  Map<String, Object?> load() => Map.of(data);

  @override
  void save(Map<String, Object?> values) => data = Map.of(values);
}

class FileSettingsStore implements SettingsStore {
  FileSettingsStore(this.file);

  final File file;

  /// Finds the per-user folder for this platform, or null if unknown.
  static Future<FileSettingsStore?> open() async {
    try {
      String? dir;
      final env = Platform.environment;
      if (Platform.isWindows) {
        final base = env['APPDATA'];
        if (base != null) dir = '$base${Platform.pathSeparator}EggelCompanion';
      } else if (Platform.isMacOS) {
        final home = env['HOME'];
        if (home != null)
          dir = '$home/Library/Application Support/EggelCompanion';
      } else if (Platform.isAndroid) {
        dir = await const MethodChannel('eggel/media')
            .invokeMethod<String>('storageDir');
      }
      if (dir == null) return null;
      await Directory(dir).create(recursive: true);
      return FileSettingsStore(
        File('$dir${Platform.pathSeparator}settings.json'),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, Object?> load() {
    try {
      if (!file.existsSync()) return {};
      final v = jsonDecode(file.readAsStringSync());
      return v is Map<String, Object?> ? v : {};
    } catch (_) {
      return {};
    }
  }

  @override
  void save(Map<String, Object?> values) {
    try {
      final tmp = File('${file.path}.tmp');
      tmp.writeAsStringSync(jsonEncode(values), flush: true);
      tmp.renameSync(file.path);
    } catch (_) {
      // Losing a save is better than crashing the app.
    }
  }
}

/// Loaded settings plus the store they are written back to.
class AppSettings {
  AppSettings(this._store) : _values = _store.load();

  final SettingsStore _store;
  final Map<String, Object?> _values;

  T? get<T>(String key) {
    final v = _values[key];
    return v is T ? v : null;
  }

  void set(String key, Object? value) {
    _values[key] = value;
    _store.save(_values);
  }
}
