import 'package:flutter/material.dart';

// ── 深空暗色主题 ──
class AppTheme {
  // ── 调色板 ──
  static const Color bg          = Color(0xFF0D0F17);
  static const Color surface     = Color(0xFF161A27);
  static const Color surfaceLight= Color(0xFF1E2333);
  static const Color surfaceHigh = Color(0xFF252B3D);
  static const Color border      = Color(0xFF2A2F45);
  static const Color borderLight = Color(0xFF353D5A);
  static const Color textPrimary = Color(0xFFE8EAF6);
  static const Color textSecondary=Color(0xFF9FA8C0);
  static const Color textMuted   = Color(0xFF5C6480);
  static const Color primary     = Color(0xFF6B8EFF);
  static const Color primaryGlow = Color(0xFF6B8EFF);
  static const Color accent      = Color(0xFFA78BFA);
  static const Color accentGlow  = Color(0xFFA78BFA);
  static const Color green       = Color(0xFF4ADE80);
  static const Color greenGlow  = Color(0xFF4ADE80);
  static const Color orange      = Color(0xFFFBBF24);
  static const Color red         = Color(0xFFF87171);
  static const Color cyan        = Color(0xFF22D3EE);
  static const Color pink        = Color(0xFFFB7185);

  // ── 渐变色 ──
  static const LinearGradient primaryGrad = LinearGradient(
    colors: [Color(0xFF6B8EFF), Color(0xFFA78BFA)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient accentGrad = LinearGradient(
    colors: [Color(0xFFA78BFA), Color(0xFFF472B6)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient greenGrad = LinearGradient(
    colors: [Color(0xFF4ADE80), Color(0xFF22D3EE)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  // ── 难度颜色 ──
  static const Map<String, Color> difficultyColors = {
    '入门':     Color(0xFF4ADE80),
    '普及-':    Color(0xFF22D3EE),
    '普及':     Color(0xFF60A5FA),
    '普及/提高-': Color(0xFFA78BFA),
    '提高+':    Color(0xFFFBBF24),
    '省选-':    Color(0xFFF472B6),
    '省选':     Color(0xFFF87171),
    '省选/NOI': Color(0xFFEF4444),
    'NOI':      Color(0xFFDC2626),
    'NOI+':     Color(0xFFB91C1C),
  };

  // 语言颜色
  static const Map<String, Color> langColors = {
    'C++': Color(0xFF6B8EFF),
    'Python': Color(0xFF4ADE80),
    'Java': Color(0xFFFBBF24),
    'C': Color(0xFF9FA8C0),
  };

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: red,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),

      // ── 文字 ──
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleMedium: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        titleSmall: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        bodyLarge:  TextStyle(color: textPrimary, fontSize: 15, height: 1.7),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 14, height: 1.6),
        bodySmall:  TextStyle(color: textSecondary, fontSize: 12),
        labelLarge: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3),
      ),

      // ── 卡片 ──
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      // ── 输入框 ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
        labelStyle: const TextStyle(color: textSecondary),
      ),

      // ── 按钮 ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: border, thickness: 1, space: 1,
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textSecondary,
          hoverColor: surfaceLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceLight,
        labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(borderLight),
        trackVisibility: WidgetStateProperty.all(false),
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3,
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}
