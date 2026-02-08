import 'package:flutter/material.dart';
import 'core/api.dart';
import 'ui/login_page.dart';

void main() {
  runApp(const ScisApp());
}

class ScisApp extends StatelessWidget {
  const ScisApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiClient(
      baseUrl: 'https://jc-locationingest-846193025977.us-central1.run.app',
    );

    // Paleta Dynamics 365
    const primaryD365 = Color(0xFF002050); // Azul marino corporativo
    const accentD365 = Color(0xFF00B7C3);    // Turquesa/Cyan de acento
    const surfaceLight = Color(0xFFF3F3F3);  // Fondo gris muy claro
    const textMain = Color(0xFF212121);        // Texto principal oscuro
    const borderColor = Color(0xFFDFE2E8);   // Borde estándar

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SCIS Inventory System D365 Style',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentD365,
          primary: primaryD365,
          onPrimary: Colors.white,
          secondary: accentD365,
          surface: Colors.white,
          background: surfaceLight,
        ),

        scaffoldBackgroundColor: surfaceLight,

        // AppBar estilo Panel de Control (limpio, blanco)
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: textMain,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textMain,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),

        // Inputs cerrados y limpios, como en las interfaces de D365
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4), // Bordes más afilados
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: accentD365, width: 2),
          ),
        ),

        // Botones con el azul corporativo
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryD365,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            elevation: 0,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),

        // Cards para listas de inventario
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4), // Bordes afilados
            side: const BorderSide(color: borderColor),
          ),
        ),

        // TabBar con el color de acento turquesa
        tabBarTheme: const TabBarThemeData(
          labelColor: accentD365,
          unselectedLabelColor: Color(0xFF64748B),
          indicatorColor: accentD365,
          indicatorSize: TabBarIndicatorSize.label,
        ),

        // Color para enlaces y texto de acento
        // Se define implícitamente mediante colorScheme.secondary
      ),
      home: LoginPage(api: api),
    );
  }
}
