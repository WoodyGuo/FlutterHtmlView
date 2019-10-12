import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const String _tag = 'TrianglePainter';

/// 划线的painter组件
class TrianglePainter extends CustomPainter {
  TrianglePainter({
    this.color : const Color(0xFF3A3A3C),
    this.isDown : true,
  });

  /// 颜色
  final Color color;
  /// 箭头是否朝下
  final bool isDown;

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color;
    Path path = Path();
    if (isDown) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
      path.close();
    } else {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
    }
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(TrianglePainter oldDelegate) {
    return false;
  }
}
