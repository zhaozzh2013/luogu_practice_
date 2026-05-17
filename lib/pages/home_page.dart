import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/luogu_service.dart';
import '../services/vscode_launcher.dart';
import '../services/solution_manager.dart';
import '../services/code_checker_service.dart';
import '../models/problem.dart';
import '../widgets/problem_widgets.dart';
import 'problem_detail_page.dart';

/// 主页面 - 深空风格 UI
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late SolutionManager _solutionManager;

  // ── 导航 ──
  int _navIndex = 0;

  // ── 题库 ──
  List<ProblemSummary> _netProblems = [];
  int _totalProblemsOnline = 0;
  int _problemPage = 1;
  bool _probLoading = true;
  bool _probLoadingMore = false;
  String? _probError;
  bool get _hasNetProbs => _netProblems.isNotEmpty;

  // ── 题单 ──
  List<TrainingSummary> _trainings = [];
  bool _trainLoading = true;
  String? _trainError;

  // ── 选中 ──
  LuoguTrainingDetail? _selectedTraining;
  ProblemSummary? _selectedProblem;
  AsyncSnapshot<LuoguProblemDetail?> _detailSnapshot = const AsyncSnapshot.nothing();
  Problem? _localDetail;

  // ── 训练进度追踪 ──
  /// 已做的题目（在当前训练中）
  final Set<String> _solvedInTraining = {};
  /// 当前训练中正在查看的题目 PID（用于中间栏高亮）
  String? _activeTrainingProblemPid;

  // ── 筛选 ──
  final Set<int> _selectedDifficulties = {};
  String _searchQuery = '';

  // ── 本地 ──
  final Set<String> _localFilesCache = {};

  // ── 控制器 ──
  final _searchCtrl = TextEditingController();
  final _jumpCtrl = TextEditingController();

  // ── 动画 ──
  late AnimationController _navAnimController;
  late Animation<double> _navScaleAnim;

  // ── 数据 ──
  List<ProblemSummary> get _localProblems => sampleProblems.map((p) => ProblemSummary(
    pid: p.id, name: p.title, difficulty: p.difficulty, difficultyNum: _d2n(p.difficulty),
    tags: [], totalSubmit: 0, totalAccepted: 0,
  )).toList();

  int _d2n(String d) => ({'入门':1,'普及-':2,'普及':2,'普及/提高-':3,'提高+':4,'省选-':5,'省选':6,'省选/NOI':6,'NOI':7,'NOI+':7}[d] ?? 0);
  static const _dnames = {1:'入门',2:'普及-',3:'普及/提高-',4:'提高+',5:'省选-',6:'省选/NOI',7:'NOI'};

  List<ProblemSummary> get _displayProbs => _hasNetProbs ? _netProblems : _localProblems;
  Set<int> get _allDiffs => _displayProbs.map((p) => p.difficultyNum).toSet();

  List<ProblemSummary> get _filteredProbs {
    return _displayProbs.where((p) {
      if (_selectedDifficulties.isNotEmpty && !_selectedDifficulties.contains(p.difficultyNum)) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!p.pid.toLowerCase().contains(q) && !p.name.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  // ── 应用页数据 ──
  List<int> _weeklySolved = [3, 5, 2, 8, 4, 6, 7];
  int _totalSolved = 128;
  int _todaySolved = 5;
  final List<String> _updateLogs = [
    '✅ v1.2.2 - 全新 UI 设计，更精致的深空暗色主题',
    '✅ v1.2.1 - 题单数据修复，支持洛谷官方题单浏览',
    '🐛 v1.2.0 - 修复题库加载失败问题',
    '✨ v1.1.0 - 新增 VSCode 外联功能',
    '🎨 v1.0.0 - 全新 UI 设计，Tokyo Night 暗色主题',
  ];

  // ── 初始化 ──
  @override
  void initState() {
    super.initState();
    _navAnimController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _navScaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _navAnimController, curve: Curves.easeInOut));
    _init();
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    _searchCtrl.dispose();
    _jumpCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _solutionManager = await SolutionManager.getInstance();
    _loadProblems();
    _loadTrainings();
  }

  // ── 题库 ──
  Future<void> _loadProblems({bool append = false}) async {
    if (!append) setState(() { _probLoading = true; _probError = null; });
    final r = await LuoguService.fetchProblemList(
      page: append ? _problemPage + 1 : 1,
      keyword: _searchQuery.isNotEmpty ? _searchQuery : null,
    );
    if (!mounted) return;
    if (r.isSuccess) {
      setState(() {
        if (append) { _netProblems.addAll(r.problems!); _problemPage++; }
        else { _netProblems = r.problems!; _problemPage = 1; }
        _totalProblemsOnline = r.total; _probLoading = false; _probLoadingMore = false;
      });
      _refreshLocalFiles();
    } else {
      setState(() { _probError = r.error; _probLoading = false; _probLoadingMore = false; });
    }
  }

  // ── 题单 ──
  String _trainCategory = 'all';
  final List<TrainingSummary> _customTrainings = []; // 用户手动添加的题单

  Future<void> _loadTrainings() async {
    setState(() { _trainLoading = true; _trainError = null; });
    final r = await LuoguService.fetchTrainingList(category: _trainCategory);
    if (!mounted) return;
    if (r.isSuccess && r.trainings != null && r.trainings!.isNotEmpty) {
      setState(() { _trainings = r.trainings!; _trainLoading = false; });
    } else {
      setState(() {
        _trainings = _customTrainings;
        _trainLoading = false;
        if (r.error != null && _trainings.isEmpty) _trainError = r.error;
      });
    }
  }

  Future<void> _addTrainingById(int id) async {
    // 先尝试从 API 获取
    final detail = await LuoguService.fetchTrainingDetail(id);
    if (!mounted) return;
    if (detail != null) {
      final summary = TrainingSummary(
        id: detail.id,
        name: detail.name,
        problemCount: detail.problemCount,
        markCount: detail.markCount,
        type: 0, // 标记为用户添加
      );
      if (!_customTrainings.any((t) => t.id == id)) {
        setState(() => _customTrainings.add(summary));
      }
      setState(() => _selectedTraining = detail);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('题单 $id 不存在或无法访问'),
        backgroundColor: AppTheme.red,
      ));
    }
  }

  Future<void> _selectTraining(int id) async {
    setState(() { _selectedTraining = null; _selectedProblem = null; });
    final detail = await LuoguService.fetchTrainingDetail(id);
    if (!mounted) return;
    setState(() => _selectedTraining = detail);
  }

  void _selectProblem(ProblemSummary p, {bool fromTraining = false}) {
    // 从训练点过来时：保留 _selectedTraining，只切走到题库模式
    setState(() {
      _selectedProblem = p;
      _localDetail = null;
      _activeTrainingProblemPid = fromTraining ? p.pid : null;
      if (!fromTraining) _selectedTraining = null;
    });
    if (_hasNetProbs) _fetchDetail(p.pid); else _showLocalDetail(p.pid);
  }

  /// 从训练点击题目：保留训练上下文
  void _selectTrainingProblem(ProblemSummary p) {
    _selectProblem(p, fromTraining: true);
  }

  /// 标记当前训练中的题为已做
  void _markTrainingSolved(String pid) {
    setState(() => _solvedInTraining.add(pid));
  }

  /// 跳到当前训练的下一道未做题
  void _nextUnsolvedProblem() {
    if (_selectedTraining == null) return;
    final unsolved = _selectedTraining!.problemPids
        .where((pid) => !_solvedInTraining.contains(pid))
        .toList();
    if (unsolved.isEmpty) return;
    final nextPid = unsolved.first;
    final idx = _selectedTraining!.problemPids.indexOf(nextPid);
    final name = idx < _selectedTraining!.problemNames.length
        ? _selectedTraining!.problemNames[idx]
        : nextPid;
    final ps = ProblemSummary(pid: nextPid, name: name, difficulty: '未知', difficultyNum: 0);
    _selectTrainingProblem(ps);
  }

  Future<void> _fetchDetail(String pid) async {
    setState(() => _detailSnapshot = const AsyncSnapshot.waiting());
    final d = await LuoguService.fetchProblemDetail(pid);
    if (!mounted) return;
    setState(() => _detailSnapshot = AsyncSnapshot.withData(ConnectionState.done, d));
  }

  void _showLocalDetail(String pid) {
    setState(() => _localDetail = sampleProblems.where((s) => s.id == pid).firstOrNull);
  }

  void _toggleDifficulty(int diff) {
    setState(() { if (_selectedDifficulties.contains(diff)) _selectedDifficulties.remove(diff); else _selectedDifficulties.add(diff); });
  }

  void _switchNav(int idx) {
    if (_navIndex == idx) return;
    // 从训练模式切走：保留训练上下文，只切走题库/应用模式
    setState(() {
      _navIndex = idx;
      if (idx == 0 || idx == 1) {
        _selectedProblem = null;
        _detailSnapshot = const AsyncSnapshot.nothing();
        _localDetail = null;
      }
    });
  }

  Future<void> _refreshLocalFiles() async {
    _localFilesCache.clear();
    for (final p in _netProblems) { if (await _solutionManager.hasLocalFiles(p.pid)) _localFilesCache.add(p.pid); }
    if (mounted) setState(() {});
  }

  Future<void> _handleOpenVscode(String pid, String name) async {
    final detail = _detailSnapshot.data;
    if (detail == null) return;
    final problem = Problem(id: pid, title: name, difficulty: detail.difficulty, tags: LuoguService.tagsToNames(detail.tags), description: detail.description, inputFormat: detail.inputFormat, outputFormat: detail.outputFormat, samples: detail.samples, hint: detail.hint, timeLimit: detail.timeLimit, memoryLimit: detail.memoryLimit);
    if (!_localFilesCache.contains(pid)) { await _solutionManager.createSolutionTemplate(problem); _localFilesCache.add(pid); }
    final err = await VscodeLauncher.openProblem(pid, _solutionManager.basePath);
    if (mounted) _showSnack(err != null ? err : '已在 VSCode 中打开 $pid', isError: err != null);
  }

  Future<void> _handleAiAssist(String pid, String name, String desc) async {
    await Clipboard.setData(ClipboardData(text: '洛谷 $pid - $name\n\n$desc\n\n请帮我分析这道题并给出解题思路。'));
    if (mounted) _showSnack('✅ 题目已复制！粘贴到 WorkBuddy 让 AI 帮你分析');
  }

  Future<void> _handleCodeCheck() async {
    final pid = _selectedProblem!.pid;
    final name = _selectedProblem!.name;

    // 获取题目信息
    String description = '';
    String inputFormat = '';
    String outputFormat = '';
    List<SampleCase> samples = [];
    if (_detailSnapshot.data != null) {
      final d = _detailSnapshot.data!;
      description = d.description;
      inputFormat = d.inputFormat;
      outputFormat = d.outputFormat;
      samples = d.samples;
    } else if (_localDetail != null) {
      description = _localDetail!.description;
      inputFormat = _localDetail!.inputFormat;
      outputFormat = _localDetail!.outputFormat;
      samples = _localDetail!.samples;
    }

    final problemText = '$description\n\n输入格式：$inputFormat\n\n输出格式：$outputFormat';

    // 读取本地代码
    final code = await _solutionManager.readCode(pid);

    // 读取当前选择的 provider（默认 deepseek）
    final provider = _selectedCheckProvider;

    // 检查是否配置了 API key
    final cfg = CodeCheckerService.configs[provider]!;
    if (cfg.apiKey.isEmpty) {
      _showSnack('请先在设置中配置 ${provider.label} 的 API Key', isError: true);
      return;
    }

    if (code.trim().isEmpty) {
      _showSnack('请先在 VSCode 中编写代码，再进行检测', isError: true);
      return;
    }

    // 显示加载中
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text('${provider.label} 正在检测…', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ]),
        ),
      ),
    );

    final result = await CodeCheckerService.check(
      pid: pid,
      code: code,
      lang: 'cpp',
      provider: provider,
      problemDesc: problemText,
      samples: samples,
    );

    if (!mounted) return;
    Navigator.pop(context); // 关闭 loading

    if (result == null) {
      _showSnack('检测失败，请检查 API 配置和网络', isError: true);
      return;
    }

    _showCodeCheckResult(pid, name, result);
  }

  // 当前选择的 AI provider
  CodeCheckerProvider _selectedCheckProvider = CodeCheckerProvider.deepseek;

  void _showCodeCheckResult(String pid, String name, CodeCheckResult result) {
    showDialog(
      context: context,
      builder: (ctx) => _CodeCheckResultDialog(
        pid: pid,
        name: name,
        result: result,
        onProviderChanged: (p) => setState(() => _selectedCheckProvider = p),
        currentProvider: _selectedCheckProvider,
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: isError ? AppTheme.red : AppTheme.textPrimary)),
      backgroundColor: AppTheme.surface, duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _jumpToProblem() {
    final pid = _jumpCtrl.text.trim().toUpperCase();
    if (pid.isEmpty) return;
    _jumpCtrl.clear();
    _switchNav(1);
    final existing = _displayProbs.where((p) => p.pid == pid).firstOrNull;
    if (existing != null) { _selectProblem(existing); return; }
    setState(() {
      _selectedProblem = ProblemSummary(pid: pid, name: pid, difficulty: '未知', difficultyNum: 0);
      _detailSnapshot = const AsyncSnapshot.waiting();
    });
    _fetchDetail(pid);
  }

  void _onSearch(String q) {
    setState(() { _searchQuery = q; _problemPage = 1; });
    _loadProblems();
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() { _searchQuery = ''; });
    _loadProblems();
  }

  // ═══════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Row(children: [
        // ── 左侧导航 ──
        _SideNav(currentIndex: _navIndex, onTap: _switchNav),
        // ── 中间列表 ──
        Container(
          width: 320,
          decoration: const BoxDecoration(color: AppTheme.surface, border: Border(right: BorderSide(color: AppTheme.border))),
          child: Column(children: [
            _buildTopBar(),
            // 用 IndexedStack 保持列表滚动位置，返回时不会重置
            Expanded(child: _buildContent()),
          ]),
        ),
        // ── 右侧详情 ──
        Expanded(child: _buildDetailPanel()),
      ]),
    );
  }

  Widget _buildTopBar() {
    final now = DateTime.now();
    final dateStr = '${now.month}月${now.day}日 周${'一二三四五六日'[now.weekday - 1]}';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: const BoxDecoration(color: AppTheme.surface, border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _NavLabel(label: _navIndex == 0 ? '应用' : (_navIndex == 1 ? '题库' : '题单')),
            const Spacer(),
            Text(dateStr, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ]),
          if (_navIndex != 0) ...[
            const SizedBox(height: 10),
            // 跳转框
            _SearchField(
              controller: _jumpCtrl,
              hint: '题号跳转…',
              icon: Icons.arrow_forward,
              iconColor: AppTheme.accent,
              onSubmit: _jumpToProblem,
            ),
            const SizedBox(height: 8),
            // 搜索框
            _SearchField(
              controller: _searchCtrl,
              hint: _navIndex == 1 ? '搜索题号或标题…' : '搜索题单…',
              icon: Icons.search,
              onChanged: _onSearch,
              onClear: _searchQuery.isNotEmpty ? _clearSearch : null,
            ),
          ],
          if (_navIndex == 1) ...[
            const SizedBox(height: 8),
            _buildDifficultyRow(),
          ],
          if (_navIndex == 2) ...[
            const SizedBox(height: 8),
            _buildCategoryRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildDifficultyRow() {
    final diffs = _allDiffs.toList()..sort();
    return Row(children: [
      const Text('难度', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      const SizedBox(width: 8),
      Expanded(child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: diffs.map((diff) {
          final sel = _selectedDifficulties.contains(diff);
          final dn = _dnames[diff] ?? '级$diff';
          final color = AppTheme.difficultyColors[dn] ?? AppTheme.textMuted;
          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: _DiffChip(label: dn, color: color, selected: sel, onTap: () => _toggleDifficulty(diff)),
          );
        }).toList()),
      )),
      if (_selectedDifficulties.isNotEmpty)
        GestureDetector(
          onTap: () => setState(() => _selectedDifficulties.clear()),
          child: const Text('清除', style: TextStyle(color: AppTheme.primary, fontSize: 11)),
        ),
    ]);
  }

  static const List<MapEntry<String, String>> _trainCategories = [
    MapEntry('all', '全部'),
    MapEntry('recommend', '推荐'),
    MapEntry('public', '公开'),
  ];

  Widget _buildCategoryRow() {
    return Row(children: [
      Expanded(child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _trainCategories.map((e) {
          final sel = _trainCategory == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                if (_trainCategory != e.key) {
                  setState(() { _trainCategory = e.key; _trainings = _customTrainings; });
                  _loadTrainings();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: sel ? AppTheme.accentGrad : null,
                  color: sel ? null : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? Colors.transparent : AppTheme.border),
                ),
                child: Text(e.value, style: TextStyle(color: sel ? Colors.white : AppTheme.textMuted, fontSize: 11)),
              ),
            ),
          );
        }).toList()),
      )),
      GestureDetector(
        onTap: _showAddTrainingDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withAlpha(40)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add, size: 12, color: AppTheme.primary.withAlpha(200)),
            const SizedBox(width: 3),
            Text('添加', style: TextStyle(color: AppTheme.primary.withAlpha(200), fontSize: 11)),
          ]),
        ),
      ),
    ]);
  }

  void _showAddTrainingDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('添加题单', style: TextStyle(color: AppTheme.textPrimary)),
      content: TextField(
        controller: ctrl,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: '输入题单 ID 或完整 URL',
          hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          filled: true,
          fillColor: AppTheme.surfaceLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            final raw = ctrl.text.trim();
            if (raw.isEmpty) return;
            // 支持完整 URL 或纯数字 ID
            final uri = Uri.tryParse(raw);
            int? id;
            if (uri != null && uri.pathSegments.isNotEmpty) {
              id = int.tryParse(uri.pathSegments.last);
            }
            if (id == null) id = int.tryParse(raw);
            if (id != null) {
              _addTrainingById(id);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('请输入有效的题单 ID'),
                backgroundColor: AppTheme.red,
              ));
            }
          },
          child: const Text('添加'),
        ),
      ],
    ));
  }

  Widget _buildContent() {
    // 有训练选中时：优先显示训练题目列表（即使右侧在显示题目内容）
    if (_selectedTraining != null) return _buildTrainingProblemList();
    switch (_navIndex) {
      case 0: return _buildAppPage();
      case 1: return _buildProblemList();
      case 2: return _buildTrainingList();
      default: return const SizedBox();
    }
  }

  // ── 训练题目列表（中间栏） ──
  Widget _buildTrainingProblemList() {
    final t = _selectedTraining!;
    if (t.problemPids.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.lock_outline, size: 36, color: AppTheme.textMuted),
        const SizedBox(height: 12),
        const Text('题目列表需要登录后才能查看', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        Text('题单 ID: ${t.id}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ]));
    }
    return Column(children: [
      // 进度栏
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(color: AppTheme.surface, border: Border(bottom: BorderSide(color: AppTheme.border))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            // 进度条
            Row(children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: t.problemPids.isEmpty ? 0 : _solvedInTraining.length / t.problemPids.length,
                  backgroundColor: AppTheme.surfaceLight,
                  valueColor: AlwaysStoppedAnimation(AppTheme.green),
                  minHeight: 5,
                ),
              )),
              const SizedBox(width: 8),
              Text('$_solvedInTraining.length/${t.problemPids.length}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            ]),
          ])),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _nextUnsolvedProblem,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGrad,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('下一题', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                SizedBox(width: 3),
                Icon(Icons.arrow_forward, size: 12, color: Colors.white),
              ]),
            ),
          ),
        ]),
      ),
      // 题目列表
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: t.problemPids.length,
        itemBuilder: (_, i) {
          final pid = t.problemPids[i];
          final name = i < t.problemNames.length ? t.problemNames[i] : pid;
          final solved = _solvedInTraining.contains(pid);
          final active = _activeTrainingProblemPid == pid;
          return _TrainingProblemTile(
            index: i + 1,
            pid: pid,
            name: name,
            solved: solved,
            isActive: active,
            onTap: () {
              final ps = ProblemSummary(pid: pid, name: name, difficulty: '未知', difficultyNum: 0);
              _selectTrainingProblem(ps);
            },
          );
        },
      )),
    ]);
  }

  // ── 应用页 ──
  Widget _buildAppPage() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 顶栏：日期 + 运势
        _FortuneCard(),
        const SizedBox(height: 10),
        // 三个统计
        _StatsRow(total: _totalSolved, today: _todaySolved, weekly: _weeklySolved),
        const SizedBox(height: 10),
        // 折线图
        _WeeklyChart(weekly: _weeklySolved, total: _totalSolved),
        const SizedBox(height: 10),
        // 更新日志
        _UpdateLog(logs: _updateLogs),
        const SizedBox(height: 10),
      ],
    );
  }

  // ── 问题列表 ──
  Widget _buildProblemList() {
    if (_probLoading && _netProblems.isEmpty && _localProblems.isEmpty) {
      return const Center(child: _LoadingIndicator());
    }
    final filtered = _filteredProbs;
    if (filtered.isEmpty && _probError != null && !_hasNetProbs) {
      return _ErrorView(error: _probError!, onRetry: _loadProblems);
    }
    if (filtered.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off, size: 36, color: AppTheme.textMuted),
        SizedBox(height: 8),
        Text('没有找到题目', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      ]));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (s) {
        if (_hasNetProbs && s is ScrollEndNotification && s.metrics.pixels >= s.metrics.maxScrollExtent - 200 && !_probLoadingMore) {
          setState(() => _probLoadingMore = true);
          _loadProblems(append: true);
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: filtered.length + (_probLoadingMore ? 1 : 0),
        itemBuilder: (c, i) {
          if (i >= filtered.length) return const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))));
          final p = filtered[i];
          return ProblemCard(
            id: p.pid, title: p.name, difficulty: p.difficulty,
            tags: LuoguService.tagsToNames(p.tags.take(3).toList()),
            isActive: _selectedProblem?.pid == p.pid,
            hasLocalFiles: _localFilesCache.contains(p.pid),
            onTap: () => _selectProblem(p),
          );
        },
      ),
    );
  }

  // ── 题单列表 ──
  Widget _buildTrainingList() {
    if (_trainLoading) return const Center(child: _LoadingIndicator());
    if (_trainError != null && _trainings.isEmpty) {
      return _ErrorView(error: _trainError!, onRetry: _loadTrainings);
    }
    if (_trainings.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.list_alt, size: 36, color: AppTheme.textMuted),
        const SizedBox(height: 12),
        const Text('暂无题单', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        const SizedBox(height: 8),
        const Text('点击上方「添加」手动添加题单', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showAddTrainingDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGrad,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('添加题单', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _trainings.length,
      itemBuilder: (c, i) {
        final t = _trainings[i];
        final active = _selectedTraining?.id == t.id;
        return _TrainingCard(
          name: t.name,
          problemCount: t.problemCount,
          markCount: t.markCount,
          providerName: t.providerName,
          isActive: active,
          onTap: () => _selectTraining(t.id),
        );
      },
    );
  }

  // ── 右侧详情 ──
  Widget _buildDetailPanel() {
    // 有训练上下文时：显示训练上下文栏 + 题目内容
    if (_selectedTraining != null && _selectedProblem != null) {
      return Column(children: [
        _buildTrainingDetailContextBar(),
        Expanded(child: _buildProblemDetailContent()),
      ]);
    }

    // 有训练但没选题目：提示选一道题
    if (_selectedTraining != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(Icons.menu_book, size: 40, color: AppTheme.primary.withAlpha(150)),
        ),
        const SizedBox(height: 16),
        const Text('从左侧列表选择一道题目', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
      ]));
    }

    // 普通题库模式
    if (_selectedProblem == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(
            _navIndex == 0 ? Icons.rocket_launch : Icons.menu_book,
            size: 40, color: AppTheme.primary.withAlpha(150),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _navIndex == 0 ? '欢迎使用洛谷刷题助手'
              : (_navIndex == 1 ? '从左侧选择一道题目' : '从左侧选择一个题单'),
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
        ),
      ]));
    }

    if (_hasNetProbs && _detailSnapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _LoadingIndicator(),
        SizedBox(height: 12),
        Text('加载题目详情…', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      ]));
    }

    if (_hasNetProbs && _detailSnapshot.data == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 36, color: AppTheme.red),
        const SizedBox(height: 12),
        const Text('加载详情失败', style: TextStyle(color: AppTheme.red, fontSize: 14)),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: () => _fetchDetail(_selectedProblem!.pid), icon: const Icon(Icons.refresh, size: 16), label: const Text('重试')),
      ]));
    }

    return Column(children: [
      _buildProblemStatsBar(),
      Expanded(child: _buildProblemDetailContent()),
    ]);
  }

  // ── 训练详情上下文栏（右侧顶部） ──
  Widget _buildTrainingDetailContextBar() {
    final t = _selectedTraining!;
    final solved = _solvedInTraining.length;
    final total = t.problemPids.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(children: [
        // 返回题单列表
        GestureDetector(
          onTap: () => setState(() { _selectedProblem = null; _activeTrainingProblemPid = null; }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_back, size: 14, color: AppTheme.textMuted),
              SizedBox(width: 4),
              Text('题单', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        // 训练名
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Row(children: [
            // 进度条
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: total > 0 ? solved / total : 0,
                backgroundColor: AppTheme.surfaceLight,
                valueColor: AlwaysStoppedAnimation(AppTheme.green),
                minHeight: 5,
              ),
            )),
            const SizedBox(width: 8),
            Text('$solved/$total', style: const TextStyle(color: AppTheme.green, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ])),
        const SizedBox(width: 8),
        // 标记已做
        if (_selectedProblem != null && !_solvedInTraining.contains(_selectedProblem!.pid))
          GestureDetector(
            onTap: () => _markTrainingSolved(_selectedProblem!.pid),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.green.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.green.withAlpha(50)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_outline, size: 14, color: AppTheme.green.withAlpha(200)),
                const SizedBox(width: 4),
                Text('已做', style: TextStyle(color: AppTheme.green.withAlpha(200), fontSize: 12)),
              ]),
            ),
          ),
        if (_selectedProblem != null && _solvedInTraining.contains(_selectedProblem!.pid))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.green.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.green.withAlpha(80)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle, size: 14, color: AppTheme.green),
              const SizedBox(width: 4),
              Text('已完成', style: TextStyle(color: AppTheme.green, fontSize: 12)),
            ]),
          ),
        const SizedBox(width: 8),
        // 下一题
        GestureDetector(
          onTap: _nextUnsolvedProblem,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGrad,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('下一题', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward, size: 14, color: Colors.white),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── 题目详情内容 ──
  Widget _buildProblemDetailContent() {
    final detail = _detailSnapshot.data;
    if (detail != null) {
      return ProblemDetailPage(
        key: ValueKey(detail.pid),
        pid: detail.pid, name: detail.name, difficulty: detail.difficulty, tags: LuoguService.tagsToNames(detail.tags),
        description: detail.description, inputFormat: detail.inputFormat, outputFormat: detail.outputFormat,
        samples: detail.samples, hint: detail.hint, background: detail.background,
        timeLimit: detail.timeLimit, memoryLimit: detail.memoryLimit,
        totalSubmit: detail.totalSubmit, totalAccepted: detail.totalAccepted,
        hasLocalFiles: _localFilesCache.contains(detail.pid),
        onOpenInVscode: () {
          _handleOpenVscode(detail.pid, detail.name);
          if (_selectedTraining != null) _markTrainingSolved(detail.pid);
        },
        onAiAssist: () => _handleAiAssist(detail.pid, detail.name, detail.description),
        onCodeCheck: _handleCodeCheck,
      );
    }
    final local = _localDetail ?? sampleProblems.firstWhere((s) => s.id == _selectedProblem!.pid, orElse: () => sampleProblems.first);
    return ProblemDetailPage(
      key: ValueKey(local.id),
      pid: local.id, name: local.title, difficulty: local.difficulty, tags: local.tags,
      description: local.description, inputFormat: local.inputFormat, outputFormat: local.outputFormat,
      samples: local.samples, hint: local.hint,
      timeLimit: local.timeLimit, memoryLimit: local.memoryLimit,
      totalSubmit: 0, totalAccepted: 0,
      hasLocalFiles: _localFilesCache.contains(local.id),
      onOpenInVscode: () {
        _handleOpenVscode(local.id, local.title);
        if (_selectedTraining != null) _markTrainingSolved(local.id);
      },
      onAiAssist: () => _handleAiAssist(local.id, local.title, local.description),
      onCodeCheck: _handleCodeCheck,
    );
  }

  // ── 做题统计栏 ──
  Widget _buildProblemStatsBar() {
    final maxVal = _weeklySolved.reduce((a, b) => a > b ? a : b);
    final days = ['一', '二', '三', '四', '五', '六', '日'];
    final todayIdx = DateTime.now().weekday - 1;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGrad,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bar_chart, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text('统计', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final val = _weeklySolved[i];
            final h = maxVal > 0 ? (val / maxVal * 24).clamp(2.0, 24.0) : 2.0;
            final isToday = i == todayIdx;
            return Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 300 + i * 50),
                  height: h,
                  decoration: BoxDecoration(
                    gradient: isToday ? AppTheme.primaryGrad : null,
                    color: isToday ? null : AppTheme.primary.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 3),
                Text('${days[i]}', style: TextStyle(color: isToday ? AppTheme.primary : AppTheme.textMuted, fontSize: 8)),
              ]),
            ));
          }),
        )),
        const SizedBox(width: 16),
        _StatPill(label: '今日', value: '$_todaySolved', color: AppTheme.primary),
        const SizedBox(width: 8),
        _StatPill(label: '累计', value: '$_totalSolved', color: AppTheme.green),
      ]),
    );
  }

  // ── 题单详情 ──
  Widget _buildTrainingDetail() {
    final t = _selectedTraining!;
    return Container(
      color: AppTheme.bg,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(children: [
            Container(
              width: 4, height: 36,
              decoration: BoxDecoration(
                gradient: AppTheme.accentGrad,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${t.problemCount} 题 · ${t.markCount} 人收藏', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ])),
            IconButton(icon: const Icon(Icons.arrow_back, size: 20, color: AppTheme.textMuted), onPressed: () => setState(() => _selectedTraining = null)),
          ]),
        ),
        Expanded(child: t.problemPids.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.lock_outline, size: 36, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              const Text('题目列表需要登录后才能查看', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              const SizedBox(height: 6),
              const Text('公开题单可前往洛谷官网查看', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(children: [
                  const Text('手动添加题目', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('题单 ID: ${t.id}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ]),
              ),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: t.problemPids.length,
              itemBuilder: (_, i) {
                final pid = t.problemPids[i];
                final name = i < t.problemNames.length ? t.problemNames[i] : pid;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _TrainingProblemTile(index: i + 1, pid: pid, name: name, onTap: () {
                    final ps = ProblemSummary(pid: pid, name: name, difficulty: '未知', difficultyNum: 0);
                    _switchNav(1);
                    _selectProblem(ps);
                  }),
                );
              },
            )),
      ]),
    );
  }
}

// ═══════════════════════════════════════
// 侧边栏
// ═══════════════════════════════════════
class _SideNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  const _SideNav({required this.currentIndex, required this.onTap});

  @override
  State<_SideNav> createState() => _SideNavState();
}

class _SideNavState extends State<_SideNav> {
  int? _hoveredIdx;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(children: [
        const SizedBox(height: 14),
        // Logo
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGrad,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: AppTheme.primary.withAlpha(60), blurRadius: 12, spreadRadius: -2)],
          ),
          child: const Icon(Icons.code, size: 18, color: Colors.white),
        ),
        const SizedBox(height: 20),
        // 导航项
        _NavItem(icon: Icons.apps, label: '应用', idx: 0, currentIdx: widget.currentIndex, hoveredIdx: _hoveredIdx, onHover: (i) => setState(() => _hoveredIdx = i), onTap: widget.onTap),
        _NavItem(icon: Icons.menu_book, label: '题库', idx: 1, currentIdx: widget.currentIndex, hoveredIdx: _hoveredIdx, onHover: (i) => setState(() => _hoveredIdx = i), onTap: widget.onTap),
        _NavItem(icon: Icons.list_alt, label: '题单', idx: 2, currentIdx: widget.currentIndex, hoveredIdx: _hoveredIdx, onHover: (i) => setState(() => _hoveredIdx = i), onTap: widget.onTap),
        const Spacer(),
        // 设置
        _NavItem(icon: Icons.settings, label: '设置', idx: -1, currentIdx: widget.currentIndex, hoveredIdx: _hoveredIdx, onHover: (i) => setState(() => _hoveredIdx = i), onTap: (i) {
          if (i == -1) showDialog(context: context, builder: (_) => const _SettingsDialog());
        }),
        const SizedBox(height: 14),
      ]),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final int idx;
  final int currentIdx;
  final int? hoveredIdx;
  final Function(int?) onHover;
  final Function(int) onTap;
  const _NavItem({required this.icon, required this.label, required this.idx, required this.currentIdx, this.hoveredIdx, required this.onHover, required this.onTap});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 120), vsync: this);
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isActive => widget.currentIdx == widget.idx;
  bool get _isHovered => widget.hoveredIdx == widget.idx;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.label,
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) { widget.onHover(widget.idx); _controller.forward(); },
        onExit: (_) { widget.onHover(null); _controller.reverse(); },
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (_, child) => Transform.scale(scale: _scaleAnim.value, child: child),
          child: GestureDetector(
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) => _controller.reverse(),
            onTapCancel: () => _controller.reverse(),
            onTap: () => widget.onTap(widget.idx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 60, height: 48,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(
                  color: _isActive ? AppTheme.primary : Colors.transparent,
                  width: 3,
                )),
                gradient: _isActive ? LinearGradient(colors: [AppTheme.primary.withAlpha(20), Colors.transparent]) : null,
                color: _isHovered && !_isActive ? AppTheme.surfaceLight : Colors.transparent,
              ),
              child: Icon(
                widget.icon,
                size: 20,
                color: _isActive ? AppTheme.primary : (_isHovered ? Colors.white : AppTheme.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// 应用页组件
// ═══════════════════════════════════════
class _FortuneCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final fortunes = ['大吉 ✨', '中吉 🌟', '小吉 🌱', '吉 💫', '末吉 📚'];
    final quotes = [
      '今日运势爆棚，一道题怎么够？冲！',
      '状态不错，多刷几道进步更快！',
      '稳扎稳打，每天进步一点点',
      '平常心，是最好的心态',
      '温故知新，回顾错题也很好',
    ];
    final idx = DateTime.now().day % fortunes.length;
    final colors = [AppTheme.orange, AppTheme.primary, AppTheme.green, AppTheme.accent, AppTheme.textSecondary];
    final color = colors[idx];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withAlpha(20), AppTheme.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(fortunes[idx], style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(20)),
            child: Text('今日运势', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(quotes[idx], style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
      ]),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int total, today;
  final List<int> weekly;
  const _StatsRow({required this.total, required this.today, required this.weekly});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StatCard(icon: Icons.check_circle, label: '累计AC', value: '$total', grad: AppTheme.greenGrad, color: AppTheme.green),
      const SizedBox(width: 8),
      _StatCard(icon: Icons.today, label: '今日完成', value: '$today', grad: AppTheme.primaryGrad, color: AppTheme.primary),
      const SizedBox(width: 8),
      _StatCard(icon: Icons.trending_up, label: '本周日均', value: '${(weekly.reduce((a,b)=>a+b)/7).toStringAsFixed(1)}', grad: AppTheme.accentGrad, color: AppTheme.accent),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final LinearGradient grad;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.grad, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        ShaderMask(shaderCallback: (bounds) => grad.createShader(bounds), child: Icon(icon, size: 20, color: Colors.white)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ]),
    ));
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<int> weekly;
  final int total;
  const _WeeklyChart({required this.weekly, required this.total});

  @override
  Widget build(BuildContext context) {
    final maxVal = weekly.reduce((a, b) => a > b ? a : b);
    final days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final todayIdx = DateTime.now().weekday - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ShaderMask(shaderCallback: (bounds) => AppTheme.primaryGrad.createShader(bounds), child: const Icon(Icons.show_chart, size: 16, color: Colors.white)),
          const SizedBox(width: 6),
          const Text('本周做题趋势', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('累计 $total', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 72,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(7, (i) {
            final val = weekly[i];
            final h = maxVal > 0 ? (val / maxVal * 56).clamp(4.0, 56.0) : 4.0;
            final isToday = i == todayIdx;
            return Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('$val', style: TextStyle(color: isToday ? AppTheme.primary : AppTheme.textMuted, fontSize: 10)),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: Duration(milliseconds: 300 + i * 60),
                  height: h,
                  decoration: BoxDecoration(
                    gradient: isToday ? AppTheme.primaryGrad : null,
                    color: isToday ? null : AppTheme.primary.withAlpha(100),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: isToday ? [BoxShadow(color: AppTheme.primary.withAlpha(60), blurRadius: 8)] : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(days[i], style: TextStyle(color: isToday ? AppTheme.primary : AppTheme.textMuted, fontSize: 9)),
              ]),
            ));
          })),
        ),
      ]),
    );
  }
}

class _UpdateLog extends StatelessWidget {
  final List<String> logs;
  const _UpdateLog({required this.logs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.update, size: 14, color: AppTheme.accent),
          SizedBox(width: 6),
          Text('更新日志', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        ...logs.map((log) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(log, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.5)))),
      ]),
    );
  }
}

// ═══════════════════════════════════════
// 题单卡片
// ═══════════════════════════════════════
class _TrainingCard extends StatefulWidget {
  final String name;
  final int problemCount;
  final int markCount;
  final String providerName;
  final bool isActive;
  final VoidCallback onTap;
  const _TrainingCard({required this.name, required this.problemCount, required this.markCount, required this.providerName, required this.isActive, required this.onTap});

  @override
  State<_TrainingCard> createState() => _TrainingCardState();
}

class _TrainingCardState extends State<_TrainingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: widget.isActive ? AppTheme.accent.withAlpha(20)
                  : (_hovered ? AppTheme.surfaceLight : Colors.transparent),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isActive ? AppTheme.accent.withAlpha(80)
                    : (_hovered ? AppTheme.borderLight : Colors.transparent),
              ),
              boxShadow: widget.isActive ? [BoxShadow(color: AppTheme.accent.withAlpha(30), blurRadius: 12, spreadRadius: -2)] : null,
            ),
            child: Row(children: [
              Container(
                width: 4, height: 40,
                decoration: BoxDecoration(
                  gradient: widget.isActive ? AppTheme.accentGrad
                      : (_hovered ? AppTheme.primaryGrad : null),
                  color: widget.isActive || _hovered ? null : AppTheme.textMuted.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  Text(widget.providerName, style: TextStyle(color: AppTheme.primary.withAlpha(180), fontSize: 10)),
                  const SizedBox(width: 6),
                  Text('${widget.problemCount} 题 · ${widget.markCount} 收藏', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                ]),
              ])),
              if (widget.isActive) ShaderMask(shaderCallback: (b) => AppTheme.accentGrad.createShader(b), child: const Icon(Icons.chevron_right, size: 18, color: Colors.white)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// 题单内题目项
// ═══════════════════════════════════════
class _TrainingProblemTile extends StatefulWidget {
  final int index;
  final String pid;
  final String name;
  final bool solved;
  final bool isActive;
  final VoidCallback onTap;
  const _TrainingProblemTile({
    required this.index,
    required this.pid,
    required this.name,
    this.solved = false,
    this.isActive = false,
    required this.onTap,
  });

  @override
  State<_TrainingProblemTile> createState() => _TrainingProblemTileState();
}

class _TrainingProblemTileState extends State<_TrainingProblemTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isActive ? AppTheme.accent.withAlpha(15)
                : (_hovered ? AppTheme.surfaceLight : AppTheme.surface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isActive ? AppTheme.accent.withAlpha(80)
                  : (_hovered ? AppTheme.borderLight : AppTheme.border),
            ),
            boxShadow: widget.isActive ? [BoxShadow(color: AppTheme.accent.withAlpha(20), blurRadius: 8, spreadRadius: -2)] : null,
          ),
          child: Row(children: [
            // 序号/状态
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: widget.solved ? null : AppTheme.primaryGrad,
                color: widget.solved ? AppTheme.green.withAlpha(30) : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: widget.solved
                  ? Icon(Icons.check, size: 16, color: AppTheme.green)
                  : Text('${widget.index}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(widget.pid, style: TextStyle(color: widget.solved ? AppTheme.green : AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                if (widget.solved) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: AppTheme.green.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                    child: Text('已做', style: TextStyle(color: AppTheme.green, fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(widget.name, style: TextStyle(color: widget.solved ? AppTheme.textMuted : AppTheme.textPrimary, fontSize: 13, decoration: widget.solved ? TextDecoration.lineThrough : null), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Icon(Icons.chevron_right, size: 18, color: _hovered ? AppTheme.primary : AppTheme.textMuted),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// 通用组件
// ═══════════════════════════════════════
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24, height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: AppTheme.primary,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.cloud_off, size: 36, color: AppTheme.red),
      const SizedBox(height: 8),
      Text(error, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12), textAlign: TextAlign.center),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 16), label: const Text('重试')),
    ]));
  }
}

class _NavLabel extends StatelessWidget {
  final String label;
  const _NavLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3));
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color? iconColor;
  final Function(String)? onChanged;
  final VoidCallback? onSubmit;
  final VoidCallback? onClear;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.iconColor,
    this.onChanged,
    this.onSubmit,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          prefixIcon: Icon(icon, size: 14, color: iconColor ?? AppTheme.textMuted),
          suffixIcon: onClear != null
              ? GestureDetector(onTap: onClear, child: const Icon(Icons.close, size: 14, color: AppTheme.textMuted))
              : (onSubmit != null && controller.text.isNotEmpty)
                  ? GestureDetector(onTap: onSubmit, child: Icon(Icons.arrow_forward, size: 14, color: iconColor ?? AppTheme.primary))
                  : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          filled: true,
          fillColor: AppTheme.surfaceLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
        ),
      ),
    );
  }
}

class _DiffChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _DiffChip({required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? color.withAlpha(150) : AppTheme.border),
        ),
        child: Text(label, style: TextStyle(color: selected ? color : AppTheme.textMuted, fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: color, fontSize: 10)),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ═══════════════════════════════════════
// 设置弹窗
// ═══════════════════════════════════════
class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400, padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(gradient: AppTheme.primaryGrad, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.settings, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('设置', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, color: AppTheme.textMuted), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 20),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 16),
          _SettingsRow(icon: Icons.code, label: 'VSCode 路径', value: '自动检测'),
          _SettingsRow(icon: Icons.folder, label: '题目保存位置', value: '~/Documents/luogu-solutions'),
          _SettingsRow(icon: Icons.language, label: '洛谷服务器', value: 'https://www.luogu.com.cn'),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              showDialog(context: context, builder: (_) => const _CodeCheckSettingsDialog());
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Icon(Icons.bug_report_outlined, size: 18, color: AppTheme.orange),
                const SizedBox(width: 12),
                const Text('代码检测 API', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.orange.withAlpha(25), borderRadius: BorderRadius.circular(6)),
                  child: Text('配置', style: TextStyle(color: AppTheme.orange, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
              ]),
            ),
          ),
          _SettingsRow(icon: Icons.info_outline, label: '关于', value: 'v1.2.2'),
        ]),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SettingsRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: AppTheme.textMuted),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
      ]),
    );
  }
}

// ═══════════════════════════════════════
// 代码检测结果弹窗
// ═══════════════════════════════════════
class _CodeCheckResultDialog extends StatelessWidget {
  final String pid;
  final String name;
  final CodeCheckResult result;
  final CodeCheckerProvider currentProvider;
  final Function(CodeCheckerProvider) onProviderChanged;

  const _CodeCheckResultDialog({
    required this.pid,
    required this.name,
    required this.result,
    required this.currentProvider,
    required this.onProviderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = result.correct;
    final scoreColor = result.score >= 80
        ? AppTheme.green
        : (result.score >= 50 ? AppTheme.orange : AppTheme.red);

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 头部
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCorrect
                    ? [AppTheme.green.withAlpha(30), AppTheme.surface]
                    : [AppTheme.red.withAlpha(30), AppTheme.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: scoreColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scoreColor.withAlpha(60)),
                ),
                child: Center(child: Text(
                  '${result.score}',
                  style: TextStyle(color: scoreColor, fontSize: 20, fontWeight: FontWeight.w800),
                )),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$pid - $name', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCorrect ? AppTheme.green.withAlpha(25) : AppTheme.red.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(isCorrect ? '✅ 正确' : '❌ 有问题', style: TextStyle(color: isCorrect ? AppTheme.green : AppTheme.red, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Text('通过率 ${result.score}%', style: TextStyle(color: scoreColor, fontSize: 11)),
                ]),
              ])),
              IconButton(icon: const Icon(Icons.close, color: AppTheme.textMuted), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          // 内容
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 总体反馈
              if (result.feedback.isNotEmpty) ...[
                _ResultSection(
                  title: '💬 总评',
                  color: AppTheme.primary,
                  child: Text(result.feedback, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.6)),
                ),
                const SizedBox(height: 14),
              ],
              // 问题列表
              if (result.issues.isNotEmpty) ...[
                _ResultSection(
                  title: '🐛 问题 (${result.issues.length})',
                  color: AppTheme.red,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: result.issues.map((issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 6, right: 8), decoration: BoxDecoration(color: AppTheme.red, borderRadius: BorderRadius.circular(3))),
                      Expanded(child: Text(issue, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5))),
                    ]),
                  )).toList()),
                ),
                const SizedBox(height: 14),
              ],
              // 建议列表
              if (result.suggestions.isNotEmpty) ...[
                _ResultSection(
                  title: '💡 建议 (${result.suggestions.length})',
                  color: AppTheme.orange,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: result.suggestions.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 6, right: 8), decoration: BoxDecoration(color: AppTheme.orange, borderRadius: BorderRadius.circular(3))),
                      Expanded(child: Text(s, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5))),
                    ]),
                  )).toList()),
                ),
                const SizedBox(height: 14),
              ],
              // 反例
              if (result.counterExamples.isNotEmpty) ...[
                _ResultSection(
                  title: '🔍 反例 (${result.counterExamples.length})',
                  color: AppTheme.cyan,
                  child: Column(children: result.counterExamples.map((ce) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.cyan.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                          child: Text('输入', style: TextStyle(color: AppTheme.cyan, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(ce.input, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'))),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.green.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                          child: Text('期望', style: TextStyle(color: AppTheme.green, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(ce.expected, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'))),
                      ]),
                      if (ce.reason.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.lightbulb_outline, size: 12, color: AppTheme.orange),
                          const SizedBox(width: 6),
                          Expanded(child: Text(ce.reason, style: TextStyle(color: AppTheme.orange, fontSize: 11))),
                        ]),
                      ],
                    ]),
                  )).toList()),
                ),
              ],
              const SizedBox(height: 10),
              // Provider 选择
              _ProviderSelector(
                currentProvider: currentProvider,
                onChanged: onProviderChanged,
              ),
            ]),
          )),
        ]),
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  final String title;
  final Color color;
  final Widget child;
  const _ResultSection({required this.title, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}

class _ProviderSelector extends StatelessWidget {
  final CodeCheckerProvider currentProvider;
  final Function(CodeCheckerProvider) onChanged;

  const _ProviderSelector({required this.currentProvider, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('切换 AI 提供商', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: CodeCheckerProvider.values.map((p) {
        final isSelected = p == currentProvider;
        return GestureDetector(
          onTap: () => onChanged(p),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary.withAlpha(25) : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
            ),
            child: Text(p.label, style: TextStyle(
              color: isSelected ? AppTheme.primary : AppTheme.textMuted,
              fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            )),
          ),
        );
      }).toList()),
    ]);
  }
}

// ═══════════════════════════════════════
// 代码检测 API 设置弹窗
// ═══════════════════════════════════════
class _CodeCheckSettingsDialog extends StatefulWidget {
  const _CodeCheckSettingsDialog();

  @override
  State<_CodeCheckSettingsDialog> createState() => _CodeCheckSettingsDialogState();
}

class _CodeCheckSettingsDialogState extends State<_CodeCheckSettingsDialog> {
  // 每个 provider 的控制器
  final Map<CodeCheckerProvider, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (var p in CodeCheckerProvider.values) {
      _controllers[p] = TextEditingController(text: CodeCheckerService.configs[p]!.apiKey);
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    for (var p in CodeCheckerProvider.values) {
      final key = _controllers[p]!.text.trim();
      CodeCheckerService.updateConfig(p, key);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 460,
        constraints: const BoxConstraints(maxHeight: 560),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 头部
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.orange, AppTheme.orange.withAlpha(180)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bug_report_outlined, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('代码检测 API 设置', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('配置各 AI 提供商的 API Key', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ])),
              IconButton(icon: const Icon(Icons.close, color: AppTheme.textMuted), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          // 内容
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              ...CodeCheckerProvider.values.map((p) => _ProviderKeyRow(
                provider: p,
                controller: _controllers[p]!,
              )),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.orange.withAlpha(40)),
                ),
                child: const Row(children: [
                  Icon(Icons.warning_amber_outlined, size: 16, color: AppTheme.orange),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'API Key 仅存储在本地，不会被上传',
                    style: TextStyle(color: AppTheme.orange, fontSize: 11),
                  )),
                ]),
              ),
            ]),
          )),
          // 底部
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('取消'),
              )),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('保存'),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ProviderKeyRow extends StatelessWidget {
  final CodeCheckerProvider provider;
  final TextEditingController controller;

  const _ProviderKeyRow({required this.provider, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGrad,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(provider.label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text('(${provider.defaultModel})', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: '输入 ${provider.label} API Key',
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: AppTheme.surfaceLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
          ),
        ),
      ]),
    );
  }
}
