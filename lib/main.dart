import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'presentation/main_controller.dart';
import 'presentation/main_view.dart';

void main() {
  runApp(MindRhythmsApp());
}

class MindRhythmsApp extends StatelessWidget {
  const MindRhythmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Mind Rhythms',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'NotoSans',
      ),
      home: MindRhythmsHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MindRhythmsHomePage extends StatelessWidget {
  const MindRhythmsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // MainController를 여기서 생성하고 주입
    Get.put(MainController());
    
    return MainView();
  }
}
