import 'package:flutter/material.dart';

class PageOneView extends StatefulWidget {
  final VoidCallback onStart;

  const PageOneView({super.key, required this.onStart});

  @override
  State<PageOneView> createState() => _PageOneViewState();
}

class _PageOneViewState extends State<PageOneView> {
  bool _isActionLocked = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: screenSize.height * 0.4,
            child: Center(
              child: Text(
                '雨中人2',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: screenSize.height * 0.55,
            child: Center(child: _buildStartButton()),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: () {
        if (_isActionLocked) return;
        setState(() => _isActionLocked = true);
        widget.onStart();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '开始',
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
