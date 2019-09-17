import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const String _tag = 'TrianglePainter';

/// 划线的painter组件
class TrianglePainter extends CustomPainter {
  TrianglePainter({
    this.color : const Color(0xFF3A3A3C),
  });

  /// 颜色
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color;
    Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(TrianglePainter oldDelegate) {
    return false;
  }
}
