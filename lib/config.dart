import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Configuración de la app Unidental.
class Config {
  /// Mismo servidor que tickets-ti.
  static const String baseUrl = 'https://ti.themousetech.com.mx';

  /// Código de la tienda (se activa en el servidor con este mismo código).
  static const String tienda = 'unidental';

  static const String nombre = 'Unidental';
}

/// Paleta: tinta casi negra + lima eléctrica + lavanda.
class Paleta {
  static const Color tinta = Color(0xFF121826);
  static const Color tarjeta = Color(0xFF1B2335);
  static const Color tarjeta2 = Color(0xFF26304A);
  static const Color borde = Color(0xFF2E3A52);
  static const Color lima = Color(0xFFC6F432);
  static const Color limaOscura = Color(0xFF1F2A05);
  static const Color lavanda = Color(0xFF7B8CFF);
  static const Color texto = Color(0xFFEEF1F6);
  static const Color gris = Color(0xFFA9B2C3);
  static const Color rojo = Color(0xFFFF6B6B);
  static const Color verde = Color(0xFF4ADE80);
}

ThemeData temaUnidental() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  final texto = GoogleFonts.spaceGroteskTextTheme(base.textTheme).apply(bodyColor: Paleta.texto, displayColor: Paleta.texto);
  return base.copyWith(
    scaffoldBackgroundColor: Paleta.tinta,
    colorScheme: const ColorScheme.dark(
      primary: Paleta.lima,
      onPrimary: Paleta.limaOscura,
      secondary: Paleta.lavanda,
      onSecondary: Color(0xFF0E1340),
      surface: Paleta.tarjeta,
      onSurface: Paleta.texto,
      error: Paleta.rojo,
    ),
    textTheme: texto,
    appBarTheme: AppBarTheme(
      backgroundColor: Paleta.tinta,
      foregroundColor: Paleta.texto,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: Paleta.texto),
    ),
    cardTheme: CardThemeData(
      color: Paleta.tarjeta,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Paleta.borde)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Paleta.lima,
        foregroundColor: Paleta.limaOscura,
        minimumSize: const Size(48, 52),
        textStyle: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Paleta.texto,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: Paleta.borde),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Paleta.tarjeta,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Paleta.borde)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Paleta.borde)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Paleta.lima, width: 2)),
      labelStyle: const TextStyle(color: Paleta.gris),
      hintStyle: const TextStyle(color: Paleta.gris),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Paleta.tarjeta,
      selectedColor: Paleta.lima,
      labelStyle: const TextStyle(color: Paleta.texto),
      secondaryLabelStyle: const TextStyle(color: Paleta.limaOscura),
      side: const BorderSide(color: Paleta.borde),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Paleta.tarjeta,
      indicatorColor: Paleta.lima,
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(color: s.contains(WidgetState.selected) ? Paleta.limaOscura : Paleta.gris)),
      labelTextStyle: WidgetStateProperty.all(GoogleFonts.spaceGrotesk(fontSize: 12, color: Paleta.texto)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
