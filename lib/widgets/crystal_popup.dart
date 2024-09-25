import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CrystalPopup extends StatefulWidget {
  final int crystals;
  final int level;
  final double progress;

  CrystalPopup({required this.crystals, required this.level, required this.progress});

  @override
  _CrystalPopupState createState() => _CrystalPopupState();
}

class _CrystalPopupState extends State<CrystalPopup> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = IntTween(begin: 0, end: widget.crystals).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color getCrystalColor() {
    switch (widget.level) {
      case 1: return CupertinoColors.destructiveRed.withOpacity(0.5 + (widget.progress * 0.5));
      case 2: return CupertinoColors.activeOrange.withOpacity(0.5 + (widget.progress * 0.5));
      case 3: return CupertinoColors.systemYellow.withOpacity(0.5 + (widget.progress * 0.5));
      case 4: return CupertinoColors.activeGreen.withOpacity(0.5 + (widget.progress * 0.5));
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.darkBackgroundGray.withOpacity(0.05),
                  blurRadius: 7,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(Icons.diamond, size: 100, color: getCrystalColor()),
          ),
          SizedBox(height: 20),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Text(
                '${_animation.value} Cristalli',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              );
            },
          ),
        ],
      ),
    );
  }
}