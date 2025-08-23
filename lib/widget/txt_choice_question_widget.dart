import 'package:flutter/material.dart';

class TxtChoiceQuestionWidget extends StatefulWidget {
  final String title;
  final String? selected;
  final void Function(String value) onChanged;

  const TxtChoiceQuestionWidget({
    super.key,
    required this.title,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<TxtChoiceQuestionWidget> createState() => _TxtChoiceQuestionWidgetState();
}

class _TxtChoiceQuestionWidgetState extends State<TxtChoiceQuestionWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.selected ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '답변을 입력해주세요',
          ),
          onChanged: (value) {
            widget.onChanged(value);
          },
        ),
      ],
    );
  }
}
