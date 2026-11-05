import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cyberpunk_palette.dart';
import '../services/app_preferences.dart';
import 'constants.dart';

/// Shared surfaces, typography and remote focus for the guide, Sports and settings.
CyberpunkPalette? _lastPalette;
ThemeData? _lastTheme;
ThemeData? _lastInstantTheme;

// Only Android handheld layouts receive the richer phone palette.
// TV layouts retain their exact existing colours.
bool _phoneThemeEnabled = false;
void setPhoneThemeEnabled(bool enabled) {
  if (_phoneThemeEnabled == enabled) return;
  _phoneThemeEnabled = enabled;
  _lastPalette = null;
  _lastTheme = null;
  _lastInstantTheme = null;
}

Color _phoneTone(Color color, {double saturation = 1.18, double lightness = 1.0}) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withSaturation((hsl.saturation * saturation).clamp(0.0, 1.0))
      .withLightness((hsl.lightness * lightness).clamp(0.0, 1.0))
      .toColor().withValues(alpha: color.a);
}

ColorScheme _phoneScheme(ColorScheme original, String id) {
  // Preserve the dedicated white theme and true-black OLED background.
  if (id == 'light') return original.copyWith(
    outline: const Color(0xFF627487),
    onSurfaceVariant: const Color(0xFF354B5C),
  );
  final isOled = id == 'oled';
  return original.copyWith(
    primary: _phoneTone(original.primary, saturation: 1.10, lightness: 1.04),
    secondary: _phoneTone(original.secondary, saturation: 1.09, lightness: 1.04),
    tertiary: _phoneTone(original.tertiary, saturation: 1.08, lightness: 1.04),
    primaryContainer: _phoneTone(original.primaryContainer, saturation: 1.09, lightness: 1.07),
    surface: isOled ? original.surface : _phoneTone(original.surface, saturation: 1.12, lightness: 0.92),
    surfaceContainerLow: _phoneTone(original.surfaceContainerLow, saturation: 1.07, lightness: 1.04),
    surfaceContainer: _phoneTone(original.surfaceContainer, saturation: 1.08, lightness: 1.05),
    surfaceContainerHigh: _phoneTone(original.surfaceContainerHigh, saturation: 1.09, lightness: 1.07),
    surfaceContainerHighest: _phoneTone(original.surfaceContainerHighest, saturation: 1.09, lightness: 1.08),
    onSurfaceVariant: _phoneTone(original.onSurfaceVariant, saturation: 1.04, lightness: 1.10),
    outline: _phoneTone(original.outline, saturation: 1.05, lightness: 1.12),
    outlineVariant: _phoneTone(original.outlineVariant, saturation: 1.05, lightness: 1.12),
  );
}

ThemeData buildAppTheme(CyberpunkPalette palette,
    {bool instantPageTransitions = false}) {
  // Palette values are immutable. Keep one theme, avoiding both construction
  // and deep theme comparisons on every guide/remote focus transition.
  if (!identical(palette, _lastPalette) || _lastTheme == null) {
    _lastPalette = palette;
    _lastTheme = _createAppTheme(palette);
    _lastInstantTheme = null;
  }
  if (!instantPageTransitions) return _lastTheme!;
  return _lastInstantTheme ??= _lastTheme!.copyWith(
      pageTransitionsTheme: PageTransitionsTheme(builders: {
    for (final platform in TargetPlatform.values)
      platform: const _InstantPageTransitionsBuilder(),
  }));
}

/// Material routes include detail pages and nested settings, not just tabs.
/// Zero both durations so TV input and route disposal do not wait on a hidden
/// animation controller after the page is already visible.
class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Duration.zero;
  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions<T>(
          PageRoute<T> route,
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child) =>
      child;
}

ThemeData _createAppTheme(CyberpunkPalette palette) {
  final scheme = buildPaletteColorScheme(palette, Brightness.dark);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    focusColor: scheme.primaryContainer,
    dividerColor: scheme.outlineVariant,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w500, color: scheme.onSurface),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: scheme.outlineVariant)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: scheme.outline)),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _tvButtonStyle(scheme)),
    filledButtonTheme: FilledButtonThemeData(style: _tvButtonStyle(scheme)),
    textButtonTheme: TextButtonThemeData(style: _tvButtonStyle(scheme)),
    iconButtonTheme: IconButtonThemeData(style: _tvButtonStyle(scheme)),
  );
}

/// Shared palette construction for the root MaterialApp and local TV themes, keeping
/// navigation and content colours consistent.
ColorScheme buildPaletteColorScheme(
    CyberpunkPalette palette, Brightness brightness) {
  if (_phoneThemeEnabled) {
    return _phoneScheme(_buildOriginalPaletteColorScheme(palette, brightness), palette.id);
  }
  return _buildOriginalPaletteColorScheme(palette, brightness);
}

ColorScheme _buildOriginalPaletteColorScheme(
    CyberpunkPalette palette, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  if (palette.id == 'light') {
    return const ColorScheme.light(
      primary: Color(0xFF17649B),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD6EAFB),
      onPrimaryContainer: Color(0xFF103C5D),
      secondary: Color(0xFF17649B),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE2EDF5),
      onSecondaryContainer: Color(0xFF24445C),
      tertiary: Color(0xFF17649B),
      surface: Color(0xFFF5F7FA),
      onSurface: Color(0xFF182531),
      surfaceContainerHighest: Color(0xFFE5EBF1),
      onSurfaceVariant: Color(0xFF4A5B6A),
      outline: Color(0xFF7B8D9D),
      outlineVariant: Color(0xFFCED8E2),
      error: Color(0xFFAF2834),
      surfaceTint: Colors.transparent,
    );
  }
  // Adapt the exact original ynoTV palette colours to Flutter's Material
  // surfaces. CSS backdrop blur/shadows require separate widget treatment.
  const ynotvSurfaces = <String, (Color, Color, Color, Color)>{
    'glass-electric': (Color(0xFF0A1528), Color(0xFF143264), Color(0xFF285F9C), Color(0xFF96C8FF)),
    'solid-slate': (Color(0xFF0F172A), Color(0xFF2C374B), Color(0xFF3C4B64), Color(0xFFE2E8F0)),
    'glass-ocean': (Color(0xFF0A1628), Color(0xFF143250), Color(0xFF285A8C), Color(0xFFC8E6FF)),
    'dark-indigo': (Color(0xFF080808), Color(0xFF0F0F0F), Color(0xFF2D2D2D), Color(0xFFBFC6FF)),
    'midnight-glass': (Color(0xFF0A101A), Color(0xFF172231), Color(0xFF27384D), Color(0xFFB6C2D2)),
    'slate-glass': (Color(0xFF151B23), Color(0xFF27313C), Color(0xFF394655), Color(0xFFC4CDD6)),
    'dark-warm-grey': (Color(0xFF191715), Color(0xFF2B2825), Color(0xFF403A35), Color(0xFFD0C7BD)),
    'glass-coral-neon': (Color(0xFF2A1510), Color(0xFF462319), Color(0xFFAA5532), Color(0xFFFFE6DC)),
    'solid-coral': (Color(0xFF2A1512), Color(0xFF502823), Color(0xFFB45A4B), Color(0xFFFFDCD7)),
    'solid-sapphire': (Color(0xFF0A1428), Color(0xFF0F2346), Color(0xFF2855AA), Color(0xFFD2E6FF)),
    'solid-arctic': (Color(0xFF0A1628), Color(0xFF143250), Color(0xFF2D73AA), Color(0xFFDCF0FF)),
    'solid-rainbow': (Color(0xFF2D1A3D), Color(0xFF3C1E50), Color(0xFF8C46B4), Color(0xFFF5EBFF)),
    'solid-midnightrose': (Color(0xFF1A0A1F), Color(0xFF321937), Color(0xFF733278), Color(0xFFFFE6F0)),
  };
  final ynotv = ynotvSurfaces[palette.id];
  if (ynotv != null) {
    final (background, panel, active, mutedText) = ynotv;
    return ColorScheme.dark(
      primary: palette.primary,
      onPrimary: const Color(0xFF06121D),
      primaryContainer: active,
      onPrimaryContainer: Colors.white,
      secondary: palette.secondary,
      onSecondary: Colors.white,
      secondaryContainer: panel,
      onSecondaryContainer: Colors.white,
      tertiary: palette.primary,
      surface: background,
      onSurface: Colors.white,
      surfaceContainerLowest: background,
      surfaceContainerLow: panel,
      surfaceContainer: panel,
      surfaceContainerHigh: active,
      surfaceContainerHighest: active,
      onSurfaceVariant: mutedText,
      outline: palette.primary.withValues(alpha: 0.35),
      outlineVariant: palette.primary.withValues(alpha: 0.2),
      surfaceTint: Colors.transparent,
    );
  }
  if (palette.id == 'oled') {
    return _buildOriginalPaletteColorScheme(
            AppConstants.cyberpunkPalettes.first, Brightness.dark)
        .copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0B1016),
      surfaceContainer: const Color(0xFF111820),
      surfaceContainerHigh: const Color(0xFF17212C),
      surfaceContainerHighest: const Color(0xFF1B2632),
      outlineVariant: const Color(0xFF273545),
    );
  }
  if (palette.id == 'classic_tv') {
    return const ColorScheme.dark(
      primary: Color(0xFF90CAF9),
      onPrimary: Color(0xFF101820),
      primaryContainer: Color(0xFF245D87),
      onPrimaryContainer: Colors.white,
      secondary: Color(0xFF90CAF9),
      onSecondary: Color(0xFF101820),
      secondaryContainer: Color(0xFF223B50),
      onSecondaryContainer: Colors.white,
      tertiary: Color(0xFF90CAF9),
      surface: Color(0xFF171D25),
      onSurface: Color(0xFFE8EDF2),
      surfaceContainerHighest: Color(0xFF252E39),
      onSurfaceVariant: Color(0xFFA9B4C0),
      outline: Color(0xFF465260),
      outlineVariant: Color(0xFF303B47),
      surfaceTint: Colors.transparent,
    );
  }
  if (palette.trueBlack) {
    // Use explicit palette colours and a transparent surface tint so seeded HCT tones cannot
    // alter saturated accents or elevated surfaces.
    const onFocus = Color(0xFF1A1203);
    final base = isDark ? const ColorScheme.dark() : const ColorScheme.light();
    return base.copyWith(
      primary: palette.primary,
      onPrimary: onFocus,
      // `primaryContainer` is this app's dedicated gradient-sheen accent
      // (kept separate from `primary`, which drives the focus
      // border/text) — matches `primary` here, same as every palette
      // below, since gold has no highlight substitute to diverge from.
      primaryContainer:
          Color.lerp(const Color(0xFF171D25), palette.primary, 0.28),
      onPrimaryContainer: Colors.white,
      secondary: palette.secondary,
      onSecondary: Colors.white,
      secondaryContainer: palette.secondary.withValues(alpha: 0.18),
      onSecondaryContainer: palette.secondary,
      // `tertiary` is this app's dedicated icon/symbol-glyph accent (kept
      // separate from `primary`, which drives the focus border/gradient/
      // text) — matches `primary` here, same as every palette below,
      // since gold has no highlight substitute to diverge from.
      tertiary: palette.primary,
      surface: isDark ? Colors.black : Colors.white,
      surfaceTint: Colors.transparent,
    );
  }
  if (!palette.isMinimal) {
    final seeded =
        ColorScheme.fromSeed(seedColor: palette.primary, brightness: brightness)
            .copyWith(secondary: palette.secondary);
    final hasHighlight = palette.highlight != null;
    if (palette.vivid) {
      return seeded.copyWith(
        primary: palette.primary,
        onPrimary: Colors.black,
        tertiary: palette.primary,
        primaryContainer:
            Color.lerp(const Color(0xFF171D25), palette.primary, 0.28),
      );
    }
    // Use the explicit palette primary for focus accents; seeded HCT tones can mute saturated
    // colours in dark mode.
    return seeded.copyWith(
      primary: hasHighlight ? palette.primary : seeded.primary,
      onPrimary: hasHighlight ? Colors.white : seeded.onPrimary,
      // Highlight palettes use their secondary accent for icons; other palettes use primary.
      tertiary: hasHighlight ? palette.secondary : seeded.primary,
      // Use the primary accent for both the focus border and gradient.
      primaryContainer:
          Color.lerp(const Color(0xFF171D25), palette.primary, 0.28),
      onPrimaryContainer: Colors.white,
    );
  }
  // Build neutral palettes from the baseline scheme rather than a white seed, which can
  // introduce unintended HCT hues into unspecified surfaces.
  final neutral = isDark ? Colors.white : Colors.black;
  final neutralDim = isDark ? Colors.white70 : Colors.black54;
  final onNeutral = isDark ? Colors.black : Colors.white;
  final base = isDark ? const ColorScheme.dark() : const ColorScheme.light();
  return base.copyWith(
    primary: neutral,
    onPrimary: onNeutral,
    // Same dedicated gradient-sheen accent as every other palette — see
    // the non-minimal branch's own comment. Matches `primary` here too
    // (no highlight substitute for Minimalist to diverge from).
    primaryContainer:
        isDark ? const Color(0xFF3B4550) : const Color(0xFFDEE5EC),
    onPrimaryContainer: neutral,
    secondary: neutralDim,
    onSecondary: onNeutral,
    secondaryContainer: neutral.withValues(alpha: 0.12),
    onSecondaryContainer: neutral,
    // Same dedicated icon/symbol-glyph accent as every other palette —
    // see the non-minimal branch's own comment. Matches `primary` here
    // too (no highlight substitute for Minimalist to diverge from).
    tertiary: neutral,
    surface: isDark ? Colors.black : Colors.white,
    surfaceTint: Colors.transparent,
  );
}

/// Blurred focus treatment for the Minimalist palette. Limit it to the single focused item to
/// bound compositing cost on low-power GPUs.
class MinimalGlassFocus extends StatelessWidget {
  const MinimalGlassFocus(
      {super.key,
      required this.active,
      required this.borderRadius,
      required this.child});

  final bool active;
  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Keep the child at the same tree position when focus decoration changes. Replacing its
    // ancestors would recreate its FocusNode during focus transitions.
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: active
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(borderRadius),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 1.5),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          child,
        ],
      ),
    );
  }
}

/// Apply the saved palette for wide/TV layouts, otherwise inherit the ambient theme.
/// preserveSubtree keeps the wrapper stable when a native video surface crosses a layout
/// threshold, such as entering PiP.
Widget withTvThemeIfNeeded(BuildContext context, WidgetBuilder builder,
    {bool preserveSubtree = false}) {
  final prefs = context.watch<AppPreferences>();
  final isTv = prefs.layoutMode == 'tv' ||
      (prefs.layoutMode == 'auto' &&
          MediaQuery.of(context).size.width >=
              AppConstants.tvLayoutWidthThreshold);
  if (!isTv && !preserveSubtree) return Builder(builder: builder);

  return Theme(
    // The fullscreen native video surface must survive a TV/tablet window
    // shrinking into PiP. Keep the same wrapper even across layout thresholds.
    data: isTv ? buildAppTheme(prefs.palette) : Theme.of(context),
    child: Builder(builder: builder),
  );
}

/// A solid focus fill with white text, distinct from a selected outline.
ButtonStyle _tvButtonStyle(ColorScheme scheme) {
  final focusFill = scheme.primaryContainer;
  final focusForeground = scheme.onPrimaryContainer;
  final focusBorder = scheme.primary;
  return ButtonStyle(
    shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(3))),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.focused)) return focusFill;
      return null;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.focused)) return focusForeground;
      return null;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: focusBorder, width: 2);
      }
      return null;
    }),
  );
}
