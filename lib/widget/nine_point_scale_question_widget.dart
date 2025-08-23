import 'package:flutter/material.dart';

class NinePointScaleQuestionWidget extends StatefulWidget {
  final String title;
  final int? selected;
  final void Function(int score) onChanged;

  const NinePointScaleQuestionWidget({
    super.key,
    required this.title,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<NinePointScaleQuestionWidget> createState() =>
      _NinePointScaleQuestionWidgetState();
}

class _NinePointScaleQuestionWidgetState
    extends State<NinePointScaleQuestionWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildEmotionScale(),
      ],
    );
  }

  Widget _buildEmotionScale() {
    final selected = widget.selected ?? 0;

    final List<String> labels = [
      '전혀 아니다',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '매우 그렇다'
    ];

    final List<double> outerRadii = [20, 18, 16, 14, 12, 14, 16, 18, 20];
    final List<double> innerRadii = outerRadii.map((r) => r - 6).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(9, (scoreIndex) {
        final isSelected = selected == scoreIndex + 1;
        final isNegative = scoreIndex < 4;
        final isCenter = scoreIndex == 4;

        final borderColor = isCenter
            ? Colors.grey
            : isNegative
                ? const Color(0x88ff0000)
                : const Color(0x660059FF);
        final fillColor = isSelected ? borderColor : Colors.transparent;

        return GestureDetector(
          onTap: () {
            widget.onChanged(scoreIndex + 1);
          },
          child: Column(
            children: [
              Container(
                width: outerRadii[scoreIndex] * 2,
                height: outerRadii[scoreIndex] * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Center(
                  child: Container(
                    width: innerRadii[scoreIndex] * 2.3,
                    height: innerRadii[scoreIndex] * 2.3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fillColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                labels[scoreIndex],
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        );
      }),
    );
  }
}
