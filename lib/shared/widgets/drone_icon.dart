import 'package:flutter/material.dart';

/// クアッドコプターのシルエットアイコン
/// CustomPainterでドローンの形状を描画する
class DroneIcon extends StatelessWidget {
  final double size;
  final Color color;

  const DroneIcon({
    super.key,
    this.size = 24,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _DronePainter(color: color),
      ),
    );
  }
}

class _DronePainter extends CustomPainter {
  final Color color;

  _DronePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final unit = size.width / 24;

    // ─── 本体（中央の楕円） ───
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: unit * 7,
        height: unit * 5,
      ),
      paint,
    );

    // ─── 4本のアーム ───
    final armPositions = [
      [cx - unit * 3, cy - unit * 2, cx - unit * 7.5, cy - unit * 6],   // 左上
      [cx + unit * 3, cy - unit * 2, cx + unit * 7.5, cy - unit * 6],   // 右上
      [cx - unit * 3, cy + unit * 2, cx - unit * 7.5, cy + unit * 6],   // 左下
      [cx + unit * 3, cy + unit * 2, cx + unit * 7.5, cy + unit * 6],   // 右下
    ];

    for (final arm in armPositions) {
      canvas.drawLine(
        Offset(arm[0], arm[1]),
        Offset(arm[2], arm[3]),
        strokePaint,
      );
    }

    // ─── 4つのプロペラ（円） ───
    final propPaint = Paint()
      ..color = color.withAlpha(180)
      ..style = PaintingStyle.fill;

    final propRadius = unit * 3.5;
    final propCenters = [
      Offset(cx - unit * 7.5, cy - unit * 6),  // 左上
      Offset(cx + unit * 7.5, cy - unit * 6),  // 右上
      Offset(cx - unit * 7.5, cy + unit * 6),  // 左下
      Offset(cx + unit * 7.5, cy + unit * 6),  // 右下
    ];

    for (final center in propCenters) {
      canvas.drawCircle(center, propRadius, propPaint);
    }

    // ─── プロペラの中心点（モーター） ───
    final motorPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final center in propCenters) {
      canvas.drawCircle(center, unit * 1, motorPaint);
    }

    // ─── カメラ（前方の小さな四角） ───
    final cameraPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + unit * 1),
          width: unit * 2.5,
          height: unit * 1.5,
        ),
        Radius.circular(unit * 0.5),
      ),
      cameraPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DronePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
