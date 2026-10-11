import 'package:flutter/material.dart';
import 'theme/arcade_config.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ArcadeApp(config: arcadeConfig));
}

class ArcadeApp extends StatelessWidget {
  final ArcadeConfig config;
  const ArcadeApp({super.key, required this.config});
  @override Widget build(BuildContext context) {
    return MaterialApp(
      title: config.displayName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: config.primaryColor, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: SplashScreen(config: config),
    );
  }
}
