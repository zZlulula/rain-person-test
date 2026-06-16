import 'package:flutter/material.dart';
import '../main.dart';
import '../config/experience_flow.dart';
import '../app_theme.dart';
import '../widgets/rain_particles.dart';

/// 报告页 — 禅意灰绿毛玻璃卡片
class ReportPageView extends StatelessWidget {
  final VoidCallback onRestart;
  const ReportPageView({super.key, required this.onRestart});

  UserSelectionData get _data => BackendService.instance.userData;
  String get _summaryText => ExperienceFlow.buildSummary(_data);

  List<_ReportCardData> get _cards => [
    _ReportCardData(title: '第1阶段', typeText: ExperienceFlow.stageOneReportType(_data.stageOneExpression)),
    _ReportCardData(title: '第2阶段', typeText: ExperienceFlow.stageTwoReportType(_data.stageTwoWords)),
    _ReportCardData(title: '第3阶段', typeText: ExperienceFlow.stageThreeBranchFromUserData().reportType),
    _ReportCardData(title: '第4阶段', typeText: ExperienceFlow.stageFourReportType(_data.stageFourGazeDirection)),
  ];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: LightSpots()),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Text(
                    '你的本次雨境画像',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20, left: 24, right: 24),
                  child: SizedBox(
                    width: screenSize.width * 0.9,
                    child: Text(
                      _summaryText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        height: 1.8,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 32, left: 20, right: 20, bottom: 120),
                  child: Column(
                    children: _cards.map((card) => _buildReportCard(card, screenSize)).toList(),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 30,
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
        color: AppTheme.surface.withValues(alpha: 0.6),
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.title, style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text(card.typeText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Text(
            '每个选择都是你内心的一次回应。',
            style: TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.6),
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
          border: Border.all(color: AppTheme.borderStrong, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '重新体验',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
            color: AppTheme.textPrimary,
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
