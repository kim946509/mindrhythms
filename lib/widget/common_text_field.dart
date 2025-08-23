// common_text_field.dart
import 'package:flutter/material.dart';

class CommonTextField extends StatelessWidget {
  final String? label;
  final String? hintText;
  final Function(String)? onChanged;

  const CommonTextField({
    super.key,
    this.label,
    this.hintText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (label != null) {
      children.add(
        Text(label!, style: Theme.of(context).textTheme.titleMedium),
      );
      children.add(const SizedBox(height: 8));
    }

    children.add(
      TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          border: const OutlineInputBorder(),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
