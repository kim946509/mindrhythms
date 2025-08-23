import 'package:flutter/material.dart';

class MultipleChoiceQuestionWidget extends StatelessWidget {
  final String title;
  final List<String> options;

  /// 현재 선택된 항목들 (값 리스트)
  final List<String> selected;

  /// 개별 체크 변경 시 실행되는 콜백
  final void Function(String value, bool isChecked) onChanged;

  const MultipleChoiceQuestionWidget({
    super.key,
    required this.title,
    required this.options,
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
        ...options.map((text) {
          final isChecked = selected.contains(text);
          return CheckboxListTile(
            title: Text(text),
            value: isChecked,
            onChanged: (bool? checked) {
              onChanged(text, checked ?? false);
            },
          );
        }),
      ],
    );
  }
}
