import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CommonLinkText extends StatelessWidget {
  final String text;
  final String url;
  final Color color;
  final bool underline;

  const CommonLinkText({
    super.key,
    required this.text,
    required this.url,
    this.color = Colors.blue,
    this.underline = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication, // ✅ 외부 브라우저 강제
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('링크를 열 수 없습니다: $url')),
          );
        }
      },
      child: Text(
        text,
        style: TextStyle(
          color: color,
          decoration:
              underline ? TextDecoration.underline : TextDecoration.none,
        ),
      ),
    );
  }
}
