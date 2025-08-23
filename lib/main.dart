import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mindrhythms/page/splash_page.dart';
import 'package:mindrhythms/feature/notification_register.dart';

void main() async {
  // Flutter 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();
  
  // 알림 서비스 초기화
  await NotificationService.initialize();
  
  // GetX 컨트롤러 초기화
  Get.put(SplashController());
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '마음리듬',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B73FF)),
        useMaterial3: true,
      ),
      home: const SplashPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
