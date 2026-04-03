import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/get_started_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kIsWeb) {
      debugPrint('Firebase Web config missing - skipping FCM for web dev');
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  runApp(const BloodNowApp());
}

class BloodNowApp extends StatelessWidget {
  const BloodNowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blood Now',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFFFEBEE),
      ),
      home: const GetStartedScreen(),
    );
  }
}