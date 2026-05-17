import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── 难度徽章 ──
class DifficultyBadge extends StatelessWidget {
  final String difficulty;
  final double fontSize;

  const DifficultyBadge({
    super.key,
    required this.difficulty,
    this.fontSize = 11,
  });

  Color get _color => AppTheme.difficultyColors[difficulty] ?? AppTheme.textMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withAlpha(60)),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          color: _color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── 标签 Chip ──
class TagChip extends StatelessWidget {
  final String label;
  final Color? color;

  const TagChip({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withAlpha(15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withAlpha(40)),
      ),
      child: Text(
        '#$label',
        style: TextStyle(
          color: c,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ── 问题卡片（全新设计）──
class ProblemCard extends StatefulWidget {
  final String id;
  final String title;
  final String difficulty;
  final List<String> tags;
  final bool isActive;
  final bool hasLocalFiles;
  final VoidCallback onTap;

  const ProblemCard({
    super.key,
    required this.id,
    required this.title,
    required this.difficulty,
    this.tags = const [],
    this.isActive = false,
    this.hasLocalFiles = false,
    required this.onTap,
  });

  @override
  State<ProblemCard> createState() => _ProblemCardState();
}

class _ProblemCardState extends State<ProblemCard> with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: const Duration(milliseconds: 150), vsync: this);
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color get _diffColor => AppTheme.difficultyColors[widget.difficulty] ?? AppTheme.textMuted;

  @override
  Widget build(BuildContext context) {
    final isHighlight = widget.isActive || _hovered;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: MouseRegion(
        onEnter: (_) { setState(() => _hovered = true); _animController.forward(); },
        onExit: (_) { setState(() => _hovered = false); _animController.reverse(); },
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (_, child) => Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          ),
          child: GestureDetector(
            onTapDown: (_) => _animController.forward(),
            onTapUp: (_) => _animController.reverse(),
            onTapCancel: () => _animController.reverse(),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? _diffColor.withAlpha(18)
                    : (_hovered ? AppTheme.surfaceLight : Colors.transparent),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.isActive
                      ? _diffColor.withAlpha(80)
                      : (_hovered ? AppTheme.borderLight : Colors.transparent),
                  width: widget.isActive ? 1.5 : 1,
                ),
                boxShadow: widget.isActive
                    ? [BoxShadow(color: _diffColor.withAlpha(30), blurRadius: 12, spreadRadius: -2)]
                    : null,
              ),
              child: Row(
                children: [
                  // 难度色块
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _diffColor.withAlpha(isHighlight ? 30 : 20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _diffColor.withAlpha(isHighlight ? 80 : 50)),
                    ),
                    child: Center(
                      child: Text(
                        widget.id.length > 4 ? widget.id.substring(0, 4) : widget.id,
                        style: TextStyle(
                          color: _diffColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.title,
                                style: TextStyle(
                                  color: isHighlight ? Colors.white : AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.hasLocalFiles) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: AppTheme.green.withAlpha(25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(Icons.check_circle, size: 12, color: AppTheme.green),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _diffColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.difficulty,
                                style: TextStyle(
                                  color: _diffColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (widget.tags.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              ...widget.tags.take(2).map((t) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: TagChip(label: t),
                              )),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 通用毛玻璃卡片 ──
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor ?? AppTheme.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── 渐变装饰卡 ──
class GradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;
  final List<Color> gradientColors;
  final double gradientOpacity;

  const GradientCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
    required this.gradientColors,
    this.gradientOpacity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors.map((c) => c.withAlpha((gradientOpacity * 255).toInt())).toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: gradientColors.first.withAlpha(40)),
      ),
      child: child,
    );
  }
}
