import 'package:flutter/material.dart';

/// 중간 크기로 표시되는 부제목/설명 (예: "홍길동님의 설문 목록")
class CommonSubTitle extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;

  const CommonSubTitle({
    super.key,
    required this.text,
    this.fontSize = 14,
    this.color = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        color: color,
      ),
      textAlign: TextAlign.center,
    );
  }
}
