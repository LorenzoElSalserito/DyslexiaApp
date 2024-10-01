import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

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
    double opacity = 0.5 + (widget.progress * 0.5);
    opacity = opacity.clamp(0.0, 1.0); // Assicuriamoci che l'opacità sia tra 0.0 e 1.0

    switch (widget.level) {
      case 1: return CupertinoColors.systemRed.withOpacity(opacity);
      case 2: return CupertinoColors.systemOrange.withOpacity(opacity);
      case 3: return CupertinoColors.systemYellow.withOpacity(opacity);
      case 4: return CupertinoColors.systemGreen.withOpacity(opacity);
      default: return Colors.blue.withOpacity(opacity);
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
                  color: Colors.grey.withOpacity(0.5),
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