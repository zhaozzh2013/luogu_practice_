import 'dart:io';
import '../models/problem.dart';

/// 解决方案文件管理器
/// 用 dart:io 直接管理文件，避免 path_provider 的 symlink 依赖
class SolutionManager {
  static const String _rootDirName = 'luogu-solutions';

  static SolutionManager? _instance;
  late String _basePath;

  SolutionManager._();

  static Future<SolutionManager> getInstance() async {
    if (_instance == null) {
      final instance = SolutionManager._();
      await instance._init();
      _instance = instance;
    }
    return _instance!;
  }

  Future<void> _init() async {
    // 使用用户文档目录
    String docsPath;
    if (Platform.isWindows) {
      docsPath = '${Platform.environment['USERPROFILE']}\\Documents';
    } else {
      docsPath = '${Platform.environment['HOME']}/Documents';
    }
    _basePath = '$docsPath\\$_rootDirName';
    final dir = Directory(_basePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  String get basePath => _basePath;

  /// 获取某道题的目录路径
  String problemDir(String problemId) => '$_basePath\\$problemId';

  /// 获取 C++ 模板文件路径
  String cppFilePath(String problemId) => '${problemDir(problemId)}\\main.cpp';

  /// 获取 Python 文件路径
  String pyFilePath(String problemId) => '${problemDir(problemId)}\\main.py';

  /// 获取笔记文件路径
  String noteFilePath(String problemId) => '${problemDir(problemId)}\\notes.md';

  /// 创建题目的解决方案模板
  Future<void> createSolutionTemplate(Problem problem, {String lang = 'cpp'}) async {
    final dir = Directory(problemDir(problem.id));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 写入问题描述
    await _writeIfNotExists(
      noteFilePath(problem.id),
      _buildProblemNote(problem),
    );

    // 写入代码模板
    if (lang == 'cpp') {
      await _writeIfNotExists(
        cppFilePath(problem.id),
        _buildCppTemplate(problem),
      );
    } else {
      await _writeIfNotExists(
        pyFilePath(problem.id),
        _buildPyTemplate(problem),
      );
    }
  }

  /// 检查题目是否有本地文件
  Future<bool> hasLocalFiles(String problemId) async {
    return await Directory(problemDir(problemId)).exists();
  }

  /// 读取当前的代码内容
  Future<String> readCode(String problemId) async {
    final file = File(cppFilePath(problemId));
    if (await file.exists()) {
      return await file.readAsString();
    }
    return '';
  }

  // ── 辅助 ──

  Future<void> _writeIfNotExists(String path, String content) async {
    final file = File(path);
    if (!await file.exists()) {
      await file.writeAsString(content);
    }
  }

  String _buildProblemNote(Problem problem) {
    return '''# ${problem.id} - ${problem.title}

**难度**：${problem.difficulty}
**标签**：${problem.tags.join(', ')}

## 题目描述

${problem.description}

## 输入格式

${problem.inputFormat}

## 输出格式

${problem.outputFormat}

## 样例

${problem.samples.asMap().entries.map((e) => '### 样例 ${e.key + 1}\n输入：\n```\n${e.value.input}\n```\n输出：\n```\n${e.value.output}\n```\n${e.value.explanation.isNotEmpty ? '\n> ${e.value.explanation}' : ''}').join('\n\n')}

${problem.hint.isNotEmpty ? '\n## 提示\n\n${problem.hint}' : ''}

---
> 由洛谷刷题助手自动生成
''';
  }

  String _buildCppTemplate(Problem problem) {
    return '''// ${problem.id} - ${problem.title}
// 难度: ${problem.difficulty}
// 标签: ${problem.tags.join(', ')}

#include <bits/stdc++.h>
using namespace std;

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);
    
    // TODO: 在这里编写你的代码
    
    return 0;
}
''';
  }

  String _buildPyTemplate(Problem problem) {
    return '''# ${problem.id} - ${problem.title}
# 难度: ${problem.difficulty}
# 标签: ${problem.tags.join(', ')}

def main():
    # TODO: 在这里编写你的代码
    pass

if __name__ == "__main__":
    main()
''';
  }
}
