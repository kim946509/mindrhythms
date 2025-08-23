import 'package:flutter/material.dart';

/// 가장 상단에 크게 표시되는 제목 (예: "마음리듬")
class CommonTitle extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  const CommonTitle({
    super.key,
    required this.text,
    this.fontSize = 32,
    this.fontWeight = FontWeight.bold,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
      textAlign: TextAlign.center,
    );
  }
}
