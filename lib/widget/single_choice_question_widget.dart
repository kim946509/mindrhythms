import 'package:flutter/material.dart';

class SingleChoiceQuestionWidget extends StatelessWidget {
  final String title;
  final List<String> selections;

  /// 현재 선택된 항목의 값
  final String? selected;

  /// 선택 시 외부로 전달하는 콜백
  final ValueChanged<String> onChanged;

  const SingleChoiceQuestionWidget({
    super.key,
    required this.title,
    required this.selections,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...selections.map((text) {
          return RadioListTile<String>(
            title: Text(text),
            value: text,
            groupValue: selected,
            onChanged: (val) {
              if (val != null) {
                onChanged(val);
              }
            },
          );
        }),
      ],
    );
  }
}
