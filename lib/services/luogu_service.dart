import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/problem.dart';

/// 洛谷 API 爬虫服务
class LuoguService {
  static const String _baseUrl = 'https://www.luogu.com.cn';
  static const Duration _timeout = Duration(seconds: 20);

  static const Map<int, String> _difficultyMap = {
    0: '暂无评定', 1: '入门', 2: '普及-', 3: '普及/提高-',
    4: '提高+', 5: '省选-', 6: '省选/NOI', 7: 'NOI',
  };

  static const Map<int, String> _tagMap = {
    1: '模拟', 2: '字符串', 3: '动态规划', 5: '数学', 7: '贪心',
    10: '高精度', 12: '递推', 13: '二分', 42: 'LIS',
    45: '二分答案', 53: '树状数组', 54: '递归', 55: '线段树',
    62: '哈希', 63: '并查集', 82: 'NOIP 普及组', 83: 'NOIP 提高组',
    90: 'KMP', 104: '枚举', 111: '枚举', 112: '分治',
    125: 'BFS', 127: 'DFS', 128: '剪枝', 129: '记忆化搜索',
    139: '背包 DP', 144: '区间 DP', 147: '状压 DP',
    160: '最短路', 162: 'Dijkstra', 177: 'Tarjan',
    185: '树链剖分', 186: 'LCA', 187: '树形 DP',
    239: '素数判断', 241: '最大公约数', 244: '进制',
    252: '莫队', 261: '卡特兰数', 287: '栈',
    289: 'Manacher', 464: '贪心', 476: '高精度',
  };

  // ── HTTP 请求（纯 JSON & Lencille HTML 两种模式） ──

  /// 发送请求，返回原始 body 文本
  static Future<String?> _fetchRaw(String path,
      [Map<String, String>? params, bool useLentille = true]) async {
    final uri = Uri.https('www.luogu.com.cn', path, params);
    debugPrint('[Luogu] $uri (lentille=$useLentille)');
    try {
      final client = HttpClient()
        ..connectionTimeout = _timeout
        ..badCertificateCallback = (_, __, ___) => true;
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      if (useLentille) req.headers.set('x-lentille-request', 'content-only');
      req.headers.set('Referer', '$_baseUrl/');
      final resp = await req.close().timeout(_timeout);
      final bytes = <int>[];
      await for (final chunk in resp) bytes.addAll(chunk);
      client.close(force: true);
      if (resp.statusCode != 200) {
        debugPrint('[Luogu] HTTP ${resp.statusCode}');
        return null;
      }
      return utf8.decode(bytes);
    } catch (e) {
      debugPrint('[Luogu] 请求失败: $e');
      return null;
    }
  }

  /// 从 HTML 中提取 lentille-context JSON
  /// 查找 <script id="lentille-context" type="application/json">{...}</script>
  static Map<String, dynamic>? _extractLentille(String html) {
    try {
      final startTag = '<script id="lentille-context" type="application/json">';
      final start = html.indexOf(startTag);
      if (start == -1) return null;
      final jsonStart = start + startTag.length;
      final endTag = '</script>';
      final end = html.indexOf(endTag, jsonStart);
      if (end == -1) return null;
      final jsonStr = html.substring(jsonStart, end).trim();
      return json.decode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[Luogu] 提取 lentille-context 失败: $e');
      return null;
    }
  }

  /// 智能获取 JSON：先尝试直接解析，不行再从 HTML 提取
  static Future<Map<String, dynamic>?> _fetchJson(String path,
      [Map<String, String>? params]) async {
    final raw = await _fetchRaw(path, params);
    if (raw == null) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      // 不是纯 JSON，尝试从 HTML 提取 lentille-context
      return _extractLentille(raw);
    }
  }

  /// 从 HTML 页面获取完整 lentille-context（用于需要完整数据的场景，如题单详情）
  static Future<Map<String, dynamic>?> _fetchLentilleJson(String path,
      [Map<String, String>? params]) async {
    final raw = await _fetchRaw(path, params, false); // 不用 lentille，获取完整 HTML
    if (raw == null) return null;
    return _extractLentille(raw);
  }

  // ── 题目 API ──

  static Future<LuoguPageResult> fetchProblemList({
    int page = 1,
    String? keyword,
    int? difficulty,
  }) async {
    final params = <String, String>{'page': page.toString()};
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    if (difficulty != null) params['difficulty'] = difficulty.toString();
    final json = await _fetchJson('/problem/list', params);
    if (json == null) return LuoguPageResult(error: '网络请求失败');
    try {
      final pd = json['data']?['problems'] as Map?;
      if (pd == null) return LuoguPageResult(error: '响应格式异常');
      final list = pd['result'] as List? ?? [];
      final total = pd['count'] as int? ?? 0;
      return LuoguPageResult(
        problems: list.map((item) {
          final p = item as Map<String, dynamic>;
          final dn = p['difficulty'] as int? ?? 0;
          return ProblemSummary(
            pid: p['pid'] ?? '', name: p['name'] ?? '',
            difficulty: _difficultyMap[dn] ?? '暂无', difficultyNum: dn,
            tags: (p['tags'] as List?)?.cast<int>() ?? [],
            totalSubmit: p['totalSubmit'] ?? 0, totalAccepted: p['totalAccepted'] ?? 0,
          );
        }).toList(),
        total: total, page: page, hasMore: list.length >= 50,
      );
    } catch (e) {
      return LuoguPageResult(error: '解析异常: $e');
    }
  }

  static Future<LuoguProblemDetail?> fetchProblemDetail(String pid) async {
    final json = await _fetchJson('/problem/$pid');
    if (json == null) return null;
    try {
      final p = json['data']?['problem'] as Map<String, dynamic>?;
      if (p == null) return null;
      final c = p['contenu'] as Map<String, dynamic>? ?? {};
      final dn = p['difficulty'] as int? ?? 0;
      final samples = (p['samples'] as List? ?? []).map((s) {
        if (s is List && s.length >= 2) return SampleCase(input: _norm((s[0] as String?) ?? ''), output: _norm((s[1] as String?) ?? ''));
        return const SampleCase(input: '', output: '');
      }).toList();
      final limits = p['limits'] as Map<String, dynamic>?;
      final tl = limits?['time'] as List?;
      final ml = limits?['memory'] as List?;
      return LuoguProblemDetail(
        pid: p['pid'] ?? '', name: p['name'] ?? '',
        difficulty: _difficultyMap[dn] ?? '暂无', difficultyNum: dn,
        tags: (p['tags'] as List?)?.cast<int>() ?? [],
        description: _norm((c['description'] as String?) ?? ''),
        inputFormat: _norm((c['formatI'] as String?) ?? ''),
        outputFormat: _norm((c['formatO'] as String?) ?? ''),
        hint: _norm((c['hint'] as String?) ?? ''),
        background: _norm((c['background'] as String?) ?? ''),
        samples: samples,
        timeLimit: (tl?.isNotEmpty == true) ? tl!.first as int : 1000,
        memoryLimit: (ml?.isNotEmpty == true) ? (ml!.first ~/ 1024) as int : 256,
        totalSubmit: p['totalSubmit'] ?? 0, totalAccepted: p['totalAccepted'] ?? 0,
      );
    } catch (e) {
      debugPrint('[Luogu] 详情解析失败: $e'); return null;
    }
  }

  // ── 题单 API ──

  /// 获取题单列表（公开题单，需要 category 参数）
  static Future<LuoguTrainingListResult> fetchTrainingList({
    int page = 1,
    String category = 'all',
  }) async {
    final json = await _fetchJson('/training/list', {
      'page': page.toString(),
      'category': category,
    });
    if (json == null) return LuoguTrainingListResult(error: '网络请求失败');
    try {
      // 响应结构: {"data":{"trainings":{"perPage":18,"count":18,"result":[...]}}}
      final td = json['data']?['trainings'] as Map?;
      if (td == null) return LuoguTrainingListResult(error: '响应格式异常');
      final list = td['result'] as List? ?? [];
      final total = td['count'] as int? ?? 0;
      return LuoguTrainingListResult(
        trainings: list.map((item) {
          final t = item as Map<String, dynamic>;
          final prov = t['provider'] as Map<String, dynamic>?;
          return TrainingSummary(
            id: t['id'] as int? ?? 0,
            name: t['name'] as String? ?? '',
            problemCount: t['problemCount'] as int? ?? 0,
            markCount: t['markCount'] as int? ?? 0,
            type: t['type'] as int? ?? 1,
            providerName: prov?['name'] as String? ?? '洛谷',
            providerColor: prov?['color'] as String? ?? 'Purple',
            createTime: t['createTime'] as int? ?? 0,
          );
        }).toList(),
        page: page,
        total: total,
        hasMore: list.length >= (td['perPage'] as int? ?? 18),
      );
    } catch (e) {
      return LuoguTrainingListResult(error: '解析异常: $e');
    }
  }

  /// 获取题单详情（从 HTML 页面提取 lentille-context，包含完整题目列表）
  static Future<LuoguTrainingDetail?> fetchTrainingDetail(int id) async {
    // 用普通请求获取完整 HTML，lentille-context 里才有 problems 字段
    final json = await _fetchLentilleJson('/training/$id');
    if (json == null) return null;
    try {
      final t = json['data']?['training'] as Map<String, dynamic>?;
      if (t == null) return null;
      // HTML 页面里题目列表在 problems 字段（不是 trainingProblems）
      final problems = (t['problems'] as List?) ?? [];
      debugPrint('[Luogu] 题单 $id 解析到 ${problems.length} 道题目');
      return LuoguTrainingDetail(
        id: t['id'] as int? ?? 0,
        name: t['name'] as String? ?? '',
        description: _norm((t['description'] as String?) ?? ''),
        problemCount: t['problemCount'] as int? ?? 0,
        markCount: t['markCount'] as int? ?? 0,
        problemPids: problems.map((tp) {
          if (tp is Map) return tp['pid'] as String? ?? '';
          return '';
        }).where((s) => s.isNotEmpty).toList(),
        problemNames: problems.map((tp) {
          if (tp is Map) return tp['name'] as String? ?? '';
          return '';
        }).where((s) => s.isNotEmpty).toList(),
      );
    } catch (e) {
      debugPrint('[Luogu] 题单详情解析失败: $e'); return null;
    }
  }

  static List<String> tagsToNames(List<int> ids) {
    return ids.map((id) => _tagMap[id] ?? '标签$id').toList();
  }

  static String _norm(String s) => s
      .replaceAll('\\n', '\n').replaceAll('\\t', '\t')
      .replaceAll('\\"', '"').replaceAll("\\'", "'")
      .replaceAll('\\/', '/').replaceAll('\\', '').trim();
}

// ── 数据类 ──

class ProblemSummary {
  final String pid;
  final String name;
  final String difficulty;
  final int difficultyNum;
  final List<int> tags;
  final int totalSubmit;
  final int totalAccepted;
  ProblemSummary({required this.pid, required this.name, required this.difficulty, required this.difficultyNum, this.tags = const [], this.totalSubmit = 0, this.totalAccepted = 0});
}

class LuoguPageResult {
  final List<ProblemSummary>? problems;
  final int total;
  final int page;
  final bool hasMore;
  final String? error;
  LuoguPageResult({this.problems, this.total = 0, this.page = 1, this.hasMore = false, this.error});
  bool get isSuccess => error == null && problems != null;
}

class LuoguProblemDetail {
  final String pid;
  final String name;
  final String difficulty;
  final int difficultyNum;
  final List<int> tags;
  final String description;
  final String inputFormat;
  final String outputFormat;
  final String hint;
  final String background;
  final List<SampleCase> samples;
  final int timeLimit;
  final int memoryLimit;
  final int totalSubmit;
  final int totalAccepted;
  LuoguProblemDetail({required this.pid, required this.name, required this.difficulty, required this.difficultyNum, this.tags = const [], this.description = '', this.inputFormat = '', this.outputFormat = '', this.hint = '', this.background = '', this.samples = const [], this.timeLimit = 1000, this.memoryLimit = 256, this.totalSubmit = 0, this.totalAccepted = 0});
}

// ── 题单数据类 ──

class TrainingSummary {
  final int id;
  final String name;
  final int problemCount;
  final int markCount;
  final int type;
  final String providerName;
  final String providerColor;
  final int createTime;
  TrainingSummary({
    required this.id,
    required this.name,
    this.problemCount = 0,
    this.markCount = 0,
    this.type = 1,
    this.providerName = '洛谷',
    this.providerColor = 'Purple',
    this.createTime = 0,
  });
}

class LuoguTrainingListResult {
  final List<TrainingSummary>? trainings;
  final int page;
  final int total;
  final bool hasMore;
  final String? error;
  LuoguTrainingListResult({
    this.trainings,
    this.page = 1,
    this.total = 0,
    this.hasMore = false,
    this.error,
  });
  bool get isSuccess => error == null && trainings != null;
}

class LuoguTrainingDetail {
  final int id;
  final String name;
  final String description;
  final int problemCount;
  final int markCount;
  final List<String> problemPids;
  final List<String> problemNames;
  LuoguTrainingDetail({required this.id, required this.name, this.description = '', this.problemCount = 0, this.markCount = 0, this.problemPids = const [], this.problemNames = const []});
}
