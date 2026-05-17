import 'dart:io';

/// VSCode 集成服务 - 支持多种方式找到 VSCode
class VscodeLauncher {
  /// 可能安装路径
  static final List<String> _possiblePaths = () {
    if (!Platform.isWindows) return ['code'];
    final home = Platform.environment['USERPROFILE'] ?? '';
    return [
      'code',
      '$home\\AppData\\Local\\Programs\\Microsoft VS Code\\Code.exe',
      '${Platform.environment['ProgramFiles']}\\Microsoft VS Code\\Code.exe',
      '${Platform.environment['ProgramFiles(x86)']}\\Microsoft VS Code\\Code.exe',
    ];
  }();

  /// 找到可用的 VSCode 路径
  static Future<String?> _findVscode() async {
    for (final p in _possiblePaths) {
      try {
        if (p == 'code') {
          final r = await Process.run('where', ['code'], runInShell: true);
          if (r.exitCode == 0 && (r.stdout as String).trim().isNotEmpty) {
            return 'code';
          }
        } else if (await File(p).exists()) {
          return p;
        }
      } catch (_) {}
    }
    return null;
  }

  /// 在 VSCode 中打开
  static Future<String?> openInVscode(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) await dir.create(recursive: true);

      final vscode = await _findVscode();
      if (vscode == null) return '未找到 VSCode，请确认已安装';

      final result = await Process.run(vscode, [path], runInShell: true);
      if (result.exitCode != 0) {
        return '启动失败（${result.exitCode}）';
      }
      return null;
    } catch (e) {
      return '启动出错：$e';
    }
  }

  /// 打开问题的解决方案目录
  static Future<String?> openProblem(String problemId, String solutionDir) async {
    return openInVscode('$solutionDir\\$problemId');
  }
}
