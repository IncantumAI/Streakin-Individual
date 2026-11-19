// lib/core/platform/startup_registration.dart
// "Keep running in tray for reminders" — launch at login without extra
// packages: HKCU Run key on Windows, ~/.config/autostart/*.desktop on Linux.

import 'dart:io';

import 'package:path/path.dart' as p;

class StartupRegistration {
  StartupRegistration._();

  // TODO(rename): launcher name / id.
  static const _name = 'Streakin';
  static const _desktopFile = 'in.incantum.streakin.individual.desktop';

  static bool get supported => Platform.isWindows || Platform.isLinux;

  static Future<bool> isEnabled() async {
    if (Platform.isWindows) {
      final r = await Process.run('reg', [
        'query',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
        '/v',
        _name,
      ]);
      return r.exitCode == 0;
    }
    if (Platform.isLinux) return File(_autostartPath()).existsSync();
    return false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final exe = Platform.resolvedExecutable;
    if (Platform.isWindows) {
      if (enabled) {
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
          '/v',
          _name,
          '/t',
          'REG_SZ',
          '/d',
          '"$exe" --minimized',
          '/f',
        ]);
      } else {
        await Process.run('reg', [
          'delete',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
          '/v',
          _name,
          '/f',
        ]);
      }
    } else if (Platform.isLinux) {
      final f = File(_autostartPath());
      if (enabled) {
        await f.parent.create(recursive: true);
        await f.writeAsString(
          '[Desktop Entry]\n'
          'Type=Application\n'
          'Name=$_name\n'
          'Exec="$exe" --minimized\n'
          'X-GNOME-Autostart-enabled=true\n'
          'Terminal=false\n',
        );
      } else if (f.existsSync()) {
        await f.delete();
      }
    }
  }

  static String _autostartPath() {
    final home = Platform.environment['HOME'] ?? '';
    final base =
        Platform.environment['XDG_CONFIG_HOME'] ?? p.join(home, '.config');
    return p.join(base, 'autostart', _desktopFile);
  }
}
