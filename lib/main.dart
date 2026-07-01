import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';

/// Einstiegspunkt der App.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Konzept S. 11: BOLT ist nur fürs Hochformat (Portrait) gedacht.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const BoltApp());
}

/// Wurzel-Widget der gesamten App.
class BoltApp extends StatelessWidget {
  const BoltApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOLT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
