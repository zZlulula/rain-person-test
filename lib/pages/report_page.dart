import 'package:flutter/material.dart';
import '../main.dart';
import '../config/experience_flow.dart';

class ReportPageView extends StatelessWidget {
  final VoidCallback onRestart;

  const ReportPageView({super.key, required this.onRestart});

  UserSelectionData get _data => BackendService.instance.userData;

  String get _summaryText => ExperienceFlow.buildSummary(_data);

  List<_ReportCardData> get _cards => [
        _ReportCardData(
          title: '第1阶段',
          typeText: ExperienceFlow.stageOneReportType(_data.stageOneExpression),
        ),
        _ReportCardData(
          title: '第2阶段',
          typeText: ExperienceFlow.stageTwoReportType(_data.stageTwoWords),
        ),
        _ReportCardData(
          title: '第3阶段',
          typeText: ExperienceFlow.stageThreeBranchFromUserData().reportType,
        ),
        _ReportCardData(
          title: '第4阶段',
          typeText: ExperienceFlow.stageFourReportType(
            _data.stageFourGazeDirection,
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Text(
                    '你的本次雨境画像',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(top: 20, left: 24, right: 24),
                  child: SizedBox(
                    width: screenSize.width * 0.9,
                    child: Text(
                      _summaryText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        height: 1.8,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 32,
                    left: 20,
                    right: 20,
                    bottom: 120,
                  ),
                  child: Column(
                    children:
                        _cards.map((card) => _buildReportCard(card, screenSize)).toList(),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 30,
            child: Center(child: _buildRestartButton()),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(_ReportCardData card, Size screenSize) {
    return Container(
      width: screenSize.width - 40,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.title,
            style: const TextStyle(
              fontSize: 22,
              color: Color.fromARGB(153, 255, 255, 255),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            card.typeText,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '每个选择都是你内心的一次回应。',
            style: TextStyle(
              fontSize: 22,
              color: Color.fromARGB(204, 255, 255, 255),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestartButton() {
    return GestureDetector(
      onTap: onRestart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '重新体验',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _ReportCardData {
  final String title;
  final String typeText;

  _ReportCardData({required this.title, required this.typeText});
}
