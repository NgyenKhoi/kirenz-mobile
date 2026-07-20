import 'package:flutter/material.dart';

class KirenzTheme {
  static const _fontFamily = 'Quicksand';
  static const _fontFamilyFallback = ['Roboto', 'Arial', 'sans-serif'];

  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF8B4E3E),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFFFB09C),
      onPrimaryContainer: Color(0xFF7A4032),
      secondary: Color(0xFF765B06),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFFFD97D),
      onSecondaryContainer: Color(0xFF3E2E00),
      tertiary: Color(0xFF385F95),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFA1C5FF),
      onTertiaryContainer: Color(0xFF00315E),
      error: Color(0xFFBA1A1A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFFDF9F3),
      onSurface: Color(0xFF1C1C18),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF7F3ED),
      surfaceContainer: Color(0xFFF1EDE7),
      surfaceContainerHigh: Color(0xFFEBE8E2),
      surfaceContainerHighest: Color(0xFFE6E2DC),
      onSurfaceVariant: Color(0xFF534340),
      outline: Color(0xFF85736F),
      outlineVariant: Color(0xFFD8C2BD),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF31302C),
      onInverseSurface: Color(0xFFF4F0EA),
      inversePrimary: Color(0xFFFFB4A2),
    );

    return _base(colorScheme);
  }

  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFFB4A2),
      onPrimary: Color(0xFF561E12),
      primaryContainer: Color(0xFF72372B),
      onPrimaryContainer: Color(0xFFFFDAD1),
      secondary: Color(0xFFE5C26B),
      onSecondary: Color(0xFF3F2E00),
      secondaryContainer: Color(0xFF5A4400),
      onSecondaryContainer: Color(0xFFFFDEA0),
      tertiary: Color(0xFFA1C5FF),
      onTertiary: Color(0xFF00315E),
      tertiaryContainer: Color(0xFF1B477C),
      onTertiaryContainer: Color(0xFFD6E3FF),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF161412),
      onSurface: Color(0xFFE6E2DC),
      surfaceContainerLowest: Color(0xFF0F0E0C),
      surfaceContainerLow: Color(0xFF1D1B18),
      surfaceContainer: Color(0xFF221F1B),
      surfaceContainerHigh: Color(0xFF2D2925),
      surfaceContainerHighest: Color(0xFF38342E),
      onSurfaceVariant: Color(0xFFD8C2BD),
      outline: Color(0xFFA08D8A),
      outlineVariant: Color(0xFF534340),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFE6E2DC),
      onInverseSurface: Color(0xFF31302C),
      inversePrimary: Color(0xFF8B4E3E),
    );

    return _base(colorScheme);
  }

  static ThemeData _base(ColorScheme colorScheme) {
    final textTheme = Typography.material2021().black.apply(
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFamilyFallback,
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFamilyFallback,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLowest,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        iconColor: colorScheme.onSurfaceVariant,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    );
  }
}
