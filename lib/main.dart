import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mindrhythms/core/app_context.dart';
import 'package:mindrhythms/page/splash_page.dart';

void main() {
  // AppContext 초기화
  Get.put(AppContext());
  
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
