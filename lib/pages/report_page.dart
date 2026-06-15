import 'package:flutter/material.dart';
import '../main.dart';
import '../config/experience_flow.dart';

class ReportPageView extends StatefulWidget {
  final VoidCallback onRestart;

  const ReportPageView({super.key, required this.onRestart});

  @override
  State<ReportPageView> createState() => _ReportPageViewState();
}

class _ReportPageViewState extends State<ReportPageView> {
  UserSelectionData get _data => BackendService.instance.userData;

  String get _summaryText => ExperienceFlow.buildSummary(_data);

  List<_ReportCardData> get _cards => [
        _ReportCardData(
          title: '第1阶段',
          typeText: ExperienceFlow.stageOneReportType(_data.stageOneExpression),
          stageKey: '第1阶段',
        ),
        _ReportCardData(
          title: '第2阶段',
          typeText: ExperienceFlow.stageTwoReportType(_data.stageTwoWords),
          stageKey: '第2阶段',
        ),
        _ReportCardData(
          title: '第3阶段',
          typeText:
              ExperienceFlow.stageThreeBranchFromUserData().reportType,
          stageKey: '第3阶段',
        ),
        _ReportCardData(
          title: '第4阶段',
          typeText: ExperienceFlow.stageFourReportType(
            _data.stageFourGazeDirection,
          ),
          stageKey: '第4阶段',
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
                    children: _cards
                        .map((card) => _ReportCardWidget(
                              data: card,
                              userData: _data,
                            ))
                        .toList(),
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

  Widget _buildRestartButton() {
    return GestureDetector(
      onTap: widget.onRestart,
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
  final String stageKey;

  _ReportCardData({
    required this.title,
    required this.typeText,
    required this.stageKey,
  });
}

class _ReportCardWidget extends StatefulWidget {
  final _ReportCardData data;
  final UserSelectionData userData;

  const _ReportCardWidget({
    required this.data,
    required this.userData,
  });

  @override
  State<_ReportCardWidget> createState() => _ReportCardWidgetState();
}

class _ReportCardWidgetState extends State<_ReportCardWidget> {
  late String _currentSummary;

  @override
  void initState() {
    super.initState();
    _currentSummary =
        ExperienceFlow.stageCardSummary(widget.data.stageKey, widget.userData);
  }

  void _refreshSummary() {
    setState(() {
      _currentSummary = ExperienceFlow.stageCardSummary(
        widget.data.stageKey,
        widget.userData,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: _refreshSummary,
      child: Container(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.data.title,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Color.fromARGB(153, 255, 255, 255),
                  ),
                ),
                GestureDetector(
                  onTap: _refreshSummary,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(51, 255, 255, 255),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, size: 14, color: Colors.white70),
                        SizedBox(width: 4),
                        Text(
                          '换一句',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.data.typeText,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _currentSummary,
              style: const TextStyle(
                fontSize: 22,
                color: Color.fromARGB(204, 255, 255, 255),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
