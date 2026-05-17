import 'dart:convert';
import 'dart:io';
import '../models/problem.dart';

/// 代码检测 Provider
enum CodeCheckerProvider {
  deepseek('DeepSeek', 'deepseek-chat', 'https://api.deepseek.com/v1'),
  zhipu('智谱 GLM', 'glm-4-flash', 'https://open.bigmodel.cn/api/paas/v4'),
  minimax('Minimax', 'abab6.5s-chat', 'https://api.minimax.chat/v1'),
  tencent('腾讯混元', 'hunyuan', 'https://hunyuan.cloud.tencent.com/openai/v1'),
  openai('ChatGPT', 'gpt-4o-mini', 'https://api.openai.com/v1');

  final String label;
  final String defaultModel;
  final String baseUrl;

  const CodeCheckerProvider(this.label, this.defaultModel, this.baseUrl);
}

/// 代码检测结果
class CodeCheckResult {
  final bool correct;
  final int score;
  final String feedback;
  final List<String> issues;
  final List<String> suggestions;
  final List<CounterExample> counterExamples;

  CodeCheckResult({
    required this.correct,
    required this.score,
    required this.feedback,
    required this.issues,
    required this.suggestions,
    required this.counterExamples,
  });

  factory CodeCheckResult.fromJson(Map<String, dynamic> json) {
    return CodeCheckResult(
      correct: json['correct'] == true,
      score: (json['score'] ?? 0).toInt().clamp(0, 100),
      feedback: json['feedback'] ?? '',
      issues: (json['issues'] as List?)?.map((e) => e.toString()).toList() ?? [],
      suggestions: (json['suggestions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      counterExamples: (json['counterExamples'] as List?)
              ?.map((e) => CounterExample.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class CounterExample {
  final String input;
  final String expected;
  final String reason;

  CounterExample({required this.input, required this.expected, required this.reason});

  factory CounterExample.fromJson(Map<String, dynamic> json) {
    return CounterExample(
      input: json['input'] ?? '',
      expected: json['expected'] ?? '',
      reason: json['reason'] ?? '',
    );
  }
}

/// Provider 配置
class ProviderConfig {
  String apiKey;
  String model;
  String baseUrl;

  ProviderConfig({
    required this.apiKey,
    required this.model,
    required this.baseUrl,
  });
}

/// 代码检测服务
class CodeCheckerService {
  static final Map<CodeCheckerProvider, ProviderConfig> _configs = {
    for (var p in CodeCheckerProvider.values)
      p: ProviderConfig(apiKey: '', model: p.defaultModel, baseUrl: p.baseUrl),
  };

  static Map<CodeCheckerProvider, ProviderConfig> get configs => Map.unmodifiable(_configs);

  static void updateConfig(CodeCheckerProvider provider, String apiKey, {String? model, String? baseUrl}) {
    final cfg = _configs[provider]!;
    cfg.apiKey = apiKey;
    if (model != null) cfg.model = model;
    if (baseUrl != null) cfg.baseUrl = baseUrl;
  }

  /// 检测代码
  /// [pid] 题号
  /// [code] 用户代码
  /// [lang] 语言 cpp / py
  /// [provider] AI 提供商
  /// [problemDesc] 题目描述（完整，包含输入输出格式、样例）
  /// [samples] 样例
  static Future<CodeCheckResult?> check({
    required String pid,
    required String code,
    required String lang,
    required CodeCheckerProvider provider,
    required String problemDesc,
    List<SampleCase>? samples,
  }) async {
    final cfg = _configs[provider]!;
    if (cfg.apiKey.isEmpty) return null;

    final prompt = _buildPrompt(pid, code, lang, problemDesc, samples);

    String? raw;
    try {
      raw = await _callChat(provider, cfg, prompt);
    } catch (e) {
      return null;
    }

    if (raw == null) return null;

    // 尝试从响应中提取 JSON
    final json = _extractJson(raw);
    if (json == null) return null;

    try {
      return CodeCheckResult.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  static String _buildPrompt(
    String pid,
    String code,
    String lang,
    String problemDesc,
    List<SampleCase>? samples,
  ) {
    final sampleText = samples != null && samples.isNotEmpty
        ? samples.asMap().entries.map((e) {
            final s = e.value;
            return '样例 ${e.key + 1}:\n输入:\n${s.input}\n输出:\n${s.output}${s.explanation.isNotEmpty ? '\n说明: ${s.explanation}' : ''}';
          }).join('\n\n')
        : '无';

    return '''你是一个严格的代码审查员。请仔细分析用户的代码是否正确解决了给定的题目。

## 题目信息
$problemDesc

## 样例
$sampleText

## 用户代码（$lang）
```$lang
$code
```

## 你的任务
1. 仔细阅读题目，确认题目的所有要求
2. 分析用户代码，判断是否正确解决了题目
3. **重要**：即使题目没有明确说明，你也需要考虑以下潜在问题：
   - 整数溢出（如 a+b 当结果超过 int 范围）
   - 空输入或边界输入（0、负数、超大规模数据）
   - 数组越界或指针越界
   - 未处理的特殊情况
   - 算法复杂度是否合适
4. 为每个发现的问题提供具体的行号或代码片段
5. **必须**生成至少 2-3 个题目中未提及但值得注意的边界情况反例

## 输出格式
请严格输出以下 JSON 格式，不要输出任何其他内容：
{
  "correct": true或false，代码是否完全正确，
  "score": 0-100的分数，0表示完全错误，100表示完全正确，
  "feedback": "总体评价，1-2句话",
  "issues": ["问题描述1", "问题描述2"],
  "suggestions": ["建议1", "建议2"],
  "counterExamples": [
    {"input": "反例输入", "expected": "期望输出", "reason": "为什么这个反例重要"},
    {"input": "反例输入2", "expected": "期望输出2", "reason": "原因"}
  ]
}

注意：counterExamples 中的反例应该是题目没有明确测试但值得用户注意的边界情况，例如：
- 整数溢出的边界（如最大/最小 int 值）
- 题目说"正整数"但没说明范围时的0和负数
- 空输入或空字符串
- 大规模数据
- 特殊格式输入''';
  }

  static Future<String?> _callChat(
    CodeCheckerProvider provider,
    ProviderConfig cfg,
    String prompt,
  ) async {
    final httpClient = HttpClient();

    // 根据不同 provider 调用不同的 API
    switch (provider) {
      case CodeCheckerProvider.deepseek:
        return _callDeepSeek(httpClient, cfg, prompt);
      case CodeCheckerProvider.zhipu:
        return _callZhipu(httpClient, cfg, prompt);
      case CodeCheckerProvider.minimax:
        return _callMinimax(httpClient, cfg, prompt);
      case CodeCheckerProvider.tencent:
        return _callTencent(httpClient, cfg, prompt);
      case CodeCheckerProvider.openai:
        return _callOpenAI(httpClient, cfg, prompt);
    }
  }

  static Future<String?> _callDeepSeek(HttpClient httpClient, ProviderConfig cfg, String prompt) async {
    final uri = Uri.parse('${cfg.baseUrl}/chat/completions');
    final req = await httpClient.postUrl(uri);
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Authorization', 'Bearer ${cfg.apiKey}');

    final body = json.encode({
      'model': cfg.model,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'temperature': 0.1,
    });
    req.write(body);

    final response = await req.close();
    final resp = await response.transform(utf8.decoder).join();
    final jsonResp = json.decode(resp) as Map<String, dynamic>;
    final choices = jsonResp['choices'] as List?;
    if (choices == null || choices.isEmpty) return null;
    return choices[0]['message']['content'] as String?;
  }

  static Future<String?> _callZhipu(HttpClient httpClient, ProviderConfig cfg, String prompt) async {
    final uri = Uri.parse('${cfg.baseUrl}/chat/completions');
    final req = await httpClient.postUrl(uri);
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Authorization', 'Bearer ${cfg.apiKey}');

    final body = json.encode({
      'model': cfg.model,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'temperature': 0.1,
    });
    req.write(body);

    final response = await req.close();
    final resp = await response.transform(utf8.decoder).join();
    final jsonResp = json.decode(resp) as Map<String, dynamic>;
    final choices = jsonResp['choices'] as List?;
    if (choices == null || choices.isEmpty) return null;
    return choices[0]['message']['content'] as String?;
  }

  static Future<String?> _callMinimax(HttpClient httpClient, ProviderConfig cfg, String prompt) async {
    final uri = Uri.parse('${cfg.baseUrl}/text/chatcompletion_v2');
    final req = await httpClient.postUrl(uri);
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Authorization', 'Bearer ${cfg.apiKey}');

    final body = json.encode({
      'model': cfg.model,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'temperature': 0.1,
    });
    req.write(body);

    final response = await req.close();
    final resp = await response.transform(utf8.decoder).join();
    final jsonResp = json.decode(resp) as Map<String, dynamic>;
    final choices = jsonResp['choices'] as List?;
    if (choices == null || choices.isEmpty) return null;
    return choices[0]['message']['content'] as String?;
  }

  static Future<String?> _callTencent(HttpClient httpClient, ProviderConfig cfg, String prompt) async {
    final uri = Uri.parse('${cfg.baseUrl}/chat/completions');
    final req = await httpClient.postUrl(uri);
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Authorization', 'Bearer ${cfg.apiKey}');

    final body = json.encode({
      'model': cfg.model,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'temperature': 0.1,
    });
    req.write(body);

    final response = await req.close();
    final resp = await response.transform(utf8.decoder).join();
    final jsonResp = json.decode(resp) as Map<String, dynamic>;
    final choices = jsonResp['choices'] as List?;
    if (choices == null || choices.isEmpty) return null;
    return choices[0]['message']['content'] as String?;
  }

  static Future<String?> _callOpenAI(HttpClient httpClient, ProviderConfig cfg, String prompt) async {
    final uri = Uri.parse('${cfg.baseUrl}/chat/completions');
    final req = await httpClient.postUrl(uri);
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Authorization', 'Bearer ${cfg.apiKey}');

    final body = json.encode({
      'model': cfg.model,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'temperature': 0.1,
    });
    req.write(body);

    final response = await req.close();
    final resp = await response.transform(utf8.decoder).join();
    final jsonResp = json.decode(resp) as Map<String, dynamic>;
    final choices = jsonResp['choices'] as List?;
    if (choices == null || choices.isEmpty) return null;
    return choices[0]['message']['content'] as String?;
  }

  /// 从字符串中提取 JSON 对象
  static Map<String, dynamic>? _extractJson(String raw) {
    // 尝试找 ```json ... ``` 包裹的
    final codeBlockMatch = RegExp(r'```json\s*(\{.*?\})\s*```', dotAll: true).firstMatch(raw);
    if (codeBlockMatch != null) {
      try {
        return json.decode(codeBlockMatch.group(1)!) as Map<String, dynamic>;
      } catch (_) {}
    }

    // 尝试找 { ... } 包裹的
    final firstBrace = raw.indexOf('{');
    final lastBrace = raw.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      try {
        return json.decode(raw.substring(firstBrace, lastBrace + 1)) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }
}


