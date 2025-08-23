import 'package:flutter/material.dart';
import '../../models/survey_status_response.dart'; // SurveyStatusItem가 정의되어 있음

class CommonSurveyTable extends StatelessWidget {
  final List<SurveyStatusItem> items;
  final Color completedColor; // 체크 표시 색
  final Color notCompletedColor; // X 표시 색

  const CommonSurveyTable({
    super.key,
    required this.items,
    this.completedColor = Colors.green,
    this.notCompletedColor = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(1),
      },
      children: [
        // 테이블 헤더
        TableRow(
          decoration: const BoxDecoration(color: Colors.black12),
          children: [
            _buildCell('설문 시간', isHeader: true),
            _buildCell('설문 여부', isHeader: true),
          ],
        ),
        // 테이블 본문
        for (final item in items)
          TableRow(
            children: [
              _buildCell("${item.surveyTimeSlot}시"),
              _buildCheckCell(item.status == 1),
            ],
          ),
      ],
    );
  }

  Widget _buildCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildCheckCell(bool completed) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: completed
          ? Icon(Icons.check, color: completedColor)
          : Icon(Icons.close, color: notCompletedColor),
    );
  }
}
