import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  /// Azul corporativo — neutro, serve para qualquer empresa.
  /// Gera toda a paleta M3 (primaryContainer, onPrimary, error, etc.).
  static const seedColor = Color(0xFF1565C0);

  // ── Paleta light ──────────────────────────────────────────────────────────
  static ThemeData get light {
    final cs = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      surface: const Color(0xFFF5F5F7),
      onSurface: const Color(0xFF1C1B1F),
    );
    return _buildTheme(cs, brightness: Brightness.light);
  }

  // ── Paleta dark ───────────────────────────────────────────────────────────
  static ThemeData get dark {
    final cs = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      surface: const Color(0xFF111827),
      onSurface: const Color(0xFFE5E7EB),
    );
    return _buildTheme(cs, brightness: Brightness.dark);
  }

  // ── Builder central ───────────────────────────────────────────────────────
  static ThemeData _buildTheme(ColorScheme cs,
      {required Brightness brightness}) {
    final isLight = brightness == Brightness.light;

    final appBarBg =
        isLight ? Colors.white : const Color(0xFF1F2937);
    final appBarFg = isLight
        ? const Color(0xFF1C1B1F)
        : const Color(0xFFE5E7EB);

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: appBarFg,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
        ),
        iconTheme: IconThemeData(color: appBarFg),
        actionsIconTheme: IconThemeData(color: appBarFg),
      ),

      // ── Abas ──────────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: cs.primary,
        unselectedLabelColor: isLight
            ? const Color(0xFF6B7280)
            : const Color(0xFF9CA3AF),
        indicatorColor: cs.primary,
        dividerColor: Colors.transparent,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: cs.primary, width: 3),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: isLight ? Colors.white : const Color(0xFF1F2937),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isLight
                ? const Color(0xFFE5E7EB)
                : const Color(0xFF374151),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 3,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── Inputs ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isLight
                ? const Color(0xFFD1D5DB)
                : const Color(0xFF374151),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isLight
                ? const Color(0xFFD1D5DB)
                : const Color(0xFF374151),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        filled: true,
        fillColor: isLight
            ? const Color(0xFFF9FAFB)
            : const Color(0xFF111827),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(
          color: isLight
              ? const Color(0xFF6B7280)
              : const Color(0xFF9CA3AF),
        ),
      ),

      // ── Botões ────────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isLight ? Colors.white : const Color(0xFF1F2937),
          foregroundColor: cs.primary,
          elevation: 0,
          side: BorderSide(color: cs.primary),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: cs.primary),
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        labelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),

      // ── Diálogos ──────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor:
            isLight ? Colors.white : const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        elevation: 8,
      ),

      // ── Bottom sheet ──────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:
            isLight ? Colors.white : const Color(0xFF1F2937),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation: 8,
      ),

      // ── Snackbar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight
            ? const Color(0xFF1C1B1F)
            : const Color(0xFFE5E7EB),
        contentTextStyle: TextStyle(
          color: isLight ? Colors.white : const Color(0xFF1C1B1F),
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),

      // ── Divisores ─────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: isLight
            ? const Color(0xFFE5E7EB)
            : const Color(0xFF374151),
        thickness: 1,
      ),

      // ── ListTile ──────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        iconColor: cs.primary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
