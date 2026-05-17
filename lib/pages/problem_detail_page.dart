import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_theme.dart';
import '../models/problem.dart';
import '../widgets/problem_widgets.dart';
import '../services/code_checker_service.dart';

/// 问题详情页 - 右侧主内容区
class ProblemDetailPage extends StatefulWidget {
  final String pid;
  final String name;
  final String difficulty;
  final List<String> tags;
  final String description;
  final String inputFormat;
  final String outputFormat;
  final List<SampleCase> samples;
  final String hint;
  final String background;
  final int timeLimit;
  final int memoryLimit;
  final int totalSubmit;
  final int totalAccepted;
  final bool hasLocalFiles;
  final VoidCallback? onOpenInVscode;
  final VoidCallback? onAiAssist;
  final VoidCallback? onCodeCheck;
  final VoidCallback? onBack;
  final VoidCallback? onLangChanged;

  const ProblemDetailPage({
    super.key,
    required this.pid,
    required this.name,
    required this.difficulty,
    this.tags = const [],
    required this.description,
    this.inputFormat = '',
    this.outputFormat = '',
    this.samples = const [],
    this.hint = '',
    this.background = '',
    this.timeLimit = 1000,
    this.memoryLimit = 256,
    this.totalSubmit = 0,
    this.totalAccepted = 0,
    this.hasLocalFiles = false,
    this.onOpenInVscode,
    this.onAiAssist,
    this.onCodeCheck,
    this.onBack,
    this.onLangChanged,
  });

  @override
  State<ProblemDetailPage> createState() => _ProblemDetailPageState();
}

class _ProblemDetailPageState extends State<ProblemDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: _buildAppBar(),
      body: _buildDescription(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      leading: widget.onBack != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary, size: 20),
              onPressed: widget.onBack,
              tooltip: '返回题单',
            )
          : null,
      leadingWidth: widget.onBack != null ? 40 : null,
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  '${widget.pid}  ${widget.name}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              DifficultyBadge(difficulty: widget.difficulty, fontSize: 10),
              const SizedBox(width: 8),
              ...widget.tags.take(4).map((t) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: TagChip(label: t),
                  )),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.hasLocalFiles)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Tooltip(
                  message: '已有本地文件',
                  child: Icon(Icons.check_circle, size: 18, color: AppTheme.green),
                ),
              ),
            _ActionButton(
              icon: Icons.auto_awesome, label: 'AI 辅助',
              color: AppTheme.accent, onTap: widget.onAiAssist ?? () {},
            ),
            const SizedBox(width: 8),
            _LangSelector(pid: widget.pid, onLangChanged: widget.onLangChanged ?? () {}),
            const SizedBox(width: 8),
            if (widget.onCodeCheck != null) ...[
              _ActionButton(
                icon: Icons.bug_report_outlined, label: '检测代码',
                color: AppTheme.orange, onTap: widget.onCodeCheck!,
              ),
              const SizedBox(width: 8),
            ],
            _ActionButton(
              icon: Icons.code,
              label: widget.hasLocalFiles ? '在 VSCode 打开' : '在 VSCode 创建',
              color: AppTheme.primary, onTap: widget.onOpenInVscode ?? () {},
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 提交统计
              _buildStatsRow(),
              const SizedBox(height: 16),

              // 题目背景
              if (widget.background.isNotEmpty) ...[
                _SectionCard(
                  title: '题目背景', icon: Icons.history_edu_outlined, color: AppTheme.textMuted,
                  child: _Md(widget.background),
                ),
                const SizedBox(height: 12),
              ],

              // 题目描述
              _SectionCard(
                title: '题目描述', icon: Icons.description_outlined,
                child: _Md(widget.description),
              ),
              const SizedBox(height: 12),

              // 输入格式
              if (widget.inputFormat.isNotEmpty)
                _SectionCard(
                  title: '输入格式', icon: Icons.input, color: AppTheme.cyan,
                  child: _Md(widget.inputFormat),
                ),
              const SizedBox(height: 12),

              // 输出格式
              if (widget.outputFormat.isNotEmpty)
                _SectionCard(
                  title: '输出格式', icon: Icons.output, color: AppTheme.cyan,
                  child: _Md(widget.outputFormat),
                ),
              const SizedBox(height: 12),

              // 样例
              ...widget.samples.asMap().entries.map((entry) {
                return Padding(
                  padding: EdgeInsets.only(bottom: entry.key < widget.samples.length - 1 ? 12 : 0),
                  child: _SampleCard(index: entry.key, sample: entry.value),
                );
              }),

              // 提示
              if (widget.hint.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SectionCard(
                  title: '提示', icon: Icons.lightbulb_outline, color: AppTheme.orange,
                  child: _Md(widget.hint),
                ),
              ],

              const SizedBox(height: 12),

              // 限制信息
              _buildLimits(),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow() {
    final acRate = widget.totalSubmit > 0
        ? (widget.totalAccepted / widget.totalSubmit * 100).toStringAsFixed(1)
        : '0.0';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        _StatItem(label: '提交', value: _fmt(widget.totalSubmit)),
        const SizedBox(width: 20),
        _StatItem(label: '通过', value: _fmt(widget.totalAccepted)),
        const SizedBox(width: 20),
        _StatItem(label: '通过率', value: '$acRate%'),
      ]),
    );
  }

  Widget _buildLimits() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        Icon(Icons.timer_outlined, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 6),
        Text('${widget.timeLimit}ms / ${widget.memoryLimit}MB',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontFamily: 'monospace')),
      ]),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

/// Markdown 渲染组件
class _Md extends StatelessWidget {
  final String data;
  const _Md(this.data);

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.7),
        h1: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        h2: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        h3: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        code: const TextStyle(color: AppTheme.green, fontSize: 13, fontFamily: 'monospace', backgroundColor: AppTheme.surfaceLight),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquoteDecoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(6),
          border: const Border(left: BorderSide(color: AppTheme.primary, width: 3)),
        ),
        blockquotePadding: const EdgeInsets.all(8),
        strong: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
        em: const TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
        listBullet: const TextStyle(color: AppTheme.primary),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        a: const TextStyle(color: AppTheme.primary, decoration: TextDecoration.underline),
      ),
    );
  }
}

// ── 组件 ──

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
    Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
  ]);
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? color;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, this.color, required this.child});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

class _SampleCard extends StatelessWidget {
  final int index;
  final SampleCase sample;
  const _SampleCard({required this.index, required this.sample});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
          child: Row(children: [
            Icon(Icons.article_outlined, size: 15, color: AppTheme.cyan),
            const SizedBox(width: 6),
            Text('样例 #${index + 1}', style: const TextStyle(color: AppTheme.cyan, fontSize: 13, fontWeight: FontWeight.w600)),
            if (sample.explanation.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(child: Text(sample.explanation, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ]),
        ),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _IoPanel(label: '输入', code: sample.input, color: AppTheme.cyan, bgColor: AppTheme.cyan.withAlpha(15))),
            Container(width: 1, color: AppTheme.border),
            Expanded(child: _IoPanel(label: '输出', code: sample.output, color: AppTheme.green, bgColor: AppTheme.green.withAlpha(15))),
          ]),
        ),
      ]),
    );
  }
}

class _IoPanel extends StatelessWidget {
  final String label;
  final String code;
  final Color color;
  final Color bgColor;
  const _IoPanel({required this.label, required this.code, required this.color, required this.bgColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), color: bgColor,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(label == '输入' ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_left, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withAlpha(60))),
          child: Text(code, style: TextStyle(color: color, fontSize: 13, fontFamily: 'monospace', height: 1.5)),
        ),
      ]),
    );
  }
}

class _LangSelector extends StatelessWidget {
  final String pid;
  final VoidCallback onLangChanged;
  const _LangSelector({required this.pid, required this.onLangChanged});

  @override
  Widget build(BuildContext context) {
    final lang = CodeCheckerService.getLang(pid);
    final isPy = lang == 'py';
    return PopupMenuButton<String>(
      tooltip: '切换语言',
      offset: const Offset(0, 36),
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primary.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.code, size: 14, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(isPy ? 'Python' : 'C++', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 14, color: AppTheme.primary),
        ]),
      ),
      onSelected: (value) {
        CodeCheckerService.setProblemLanguage(pid, value);
        onLangChanged();
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'cpp',
          height: 36,
          child: Row(children: [
            Icon(Icons.code, size: 14, color: !isPy ? AppTheme.green : AppTheme.textMuted),
            const SizedBox(width: 8),
            Text('C++', style: TextStyle(color: !isPy ? AppTheme.green : AppTheme.textSecondary, fontSize: 13)),
            if (!isPy) ...[const Spacer(), Icon(Icons.check, size: 14, color: AppTheme.green)],
          ]),
        ),
        PopupMenuItem(
          value: 'py',
          height: 36,
          child: Row(children: [
            Icon(Icons.code, size: 14, color: isPy ? AppTheme.green : AppTheme.textMuted),
            const SizedBox(width: 8),
            Text('Python', style: TextStyle(color: isPy ? AppTheme.green : AppTheme.textSecondary, fontSize: 13)),
            if (isPy) ...[const Spacer(), Icon(Icons.check, size: 14, color: AppTheme.green)],
          ]),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(25), borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
