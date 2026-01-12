import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Air Quality Monitoring',
      theme: ThemeData(fontFamily: 'PlusJakartaSans', useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}
