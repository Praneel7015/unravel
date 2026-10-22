import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../database/unravel_database.dart';
import '../../theme/unravel_theme_extension.dart';

/// Renders the Dual Smooth Spline **Perspective Curve** comparing
/// "What Fear Predicted" (`#C97054` dashed terracotta line) vs.
/// "How Life Unfolded" (`#84A98C` / `#3B5944` solid sage curve).
class PerspectiveCurveChart extends StatelessWidget {
  const PerspectiveCurveChart({
    required this.entries,
    super.key,
  });

  final List<PerspectiveCurveEntry> entries;

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    return Container(
      height: 148,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: BoxDecoration(
        color: ext.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ext.border, width: 1),
      ),
      child: CustomPaint(
        painter: _PerspectiveCurvePainter(
          entries: entries,
          fearLineColor: ext.fearPredictedLine,
          realityLineColor: ext.lifeUnfoldedLine,
          gridColor: ext.border,
        ),
      ),
    );
  }
}

class _PerspectiveCurvePainter extends CustomPainter {
  const _PerspectiveCurvePainter({
    required this.entries,
    required this.fearLineColor,
    required this.realityLineColor,
    required this.gridColor,
  });

  final List<PerspectiveCurveEntry> entries;
  final Color fearLineColor;
  final Color realityLineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    // 1. Subtle horizontal dashed reference lines
    final Paint gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.7)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    _drawDashedHorizontalLine(canvas, size.width, size.height * 0.25, gridPaint);
    _drawDashedHorizontalLine(canvas, size.width, size.height * 0.65, gridPaint);

    final List<double> fearScores = entries.isNotEmpty
        ? entries
            .map((PerspectiveCurveEntry e) => e.predictedFear.toDouble())
            .toList()
        : <double>[6, 9, 8, 6, 8];
    final List<double> realityScores = entries.isNotEmpty
        ? entries
            .map((PerspectiveCurveEntry e) => e.actualOutcome.toDouble())
            .toList()
        : <double>[2, 2, 3, 2, 2];

    final List<Offset> fearPoints = _normalizeScores(fearScores, size);
    final List<Offset> realityPoints = _normalizeScores(realityScores, size);

    final Path fearPath = _buildSmoothSpline(fearPoints);
    final Path realityPath = _buildSmoothSpline(realityPoints);

    // 2. Soft area gradient fill beneath "How Life Unfolded"
    final Path fillPath = Path.from(realityPath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final Paint areaPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, size.height * 0.25),
        Offset(0, size.height),
        <Color>[
          realityLineColor.withValues(alpha: 0.26),
          realityLineColor.withValues(alpha: 0.0),
        ],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, areaPaint);

    // 3. Dashed Terracotta line for "What Fear Predicted"
    final Paint fearStroke = Paint()
      ..color = fearLineColor
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    _drawDashedPath(canvas, fearPath, fearStroke, dashWidth: 5, dashSpace: 4);

    // 4. Solid Sage/Moss line for "How Life Unfolded"
    final Paint realityStroke = Paint()
      ..color = realityLineColor
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(realityPath, realityStroke);

    // 5. Focal markers on peak fear & latest reality anchor
    if (fearPoints.isNotEmpty) {
      Offset peakFear = fearPoints.first;
      for (final Offset pt in fearPoints) {
        if (pt.dy < peakFear.dy) {
          peakFear = pt;
        }
      }
      canvas.drawCircle(peakFear, 4.0, Paint()..color = fearLineColor);
    }

    if (realityPoints.isNotEmpty) {
      final Offset latestReality = realityPoints.last;
      canvas.drawCircle(latestReality, 4.0, Paint()..color = realityLineColor);
    }
  }

  List<Offset> _normalizeScores(List<double> scores, Size size) {
    if (scores.length == 1) {
      final double y = _scoreToY(scores.first, size.height);
      return <Offset>[Offset(0, y), Offset(size.width, y)];
    }
    final List<Offset> points = <Offset>[];
    final double stepX = size.width / (scores.length - 1);
    for (int i = 0; i < scores.length; i++) {
      points.add(Offset(i * stepX, _scoreToY(scores[i], size.height)));
    }
    return points;
  }

  double _scoreToY(double score, double height) {
    final double clamped = score.clamp(1.0, 10.0);
    // Score 10 near top (12% height), Score 1 near bottom (88% height)
    final double normalized = (clamped - 1.0) / 9.0;
    return height * (0.88 - normalized * 0.74);
  }

  Path _buildSmoothSpline(List<Offset> points) {
    final Path path = Path();
    if (points.isEmpty) {
      return path;
    }
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final Offset current = points[i];
      final Offset next = points[i + 1];
      final double controlX = (current.dx + next.dx) / 2;
      path.cubicTo(
        controlX,
        current.dy,
        controlX,
        next.dy,
        next.dx,
        next.dy,
      );
    }
    return path;
  }

  void _drawDashedHorizontalLine(
    Canvas canvas,
    double width,
    double y,
    Paint paint,
  ) {
    double x = 0;
    while (x < width) {
      canvas.drawLine(Offset(x, y), Offset((x + 4).clamp(0, width), y), paint);
      x += 8;
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    Path source,
    Paint paint, {
    required double dashWidth,
    required double dashSpace,
  }) {
    for (final ui.PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double next = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PerspectiveCurvePainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.fearLineColor != fearLineColor ||
        oldDelegate.realityLineColor != realityLineColor;
  }
}

/// Intertwined organic dual-ribbon waveform for the Voice Reflection card
/// inside the "Unravel a Knot" modal sheet.
///
/// Reacts organically at 30fps to live normalized microphone [amplitude] (`0.0..1.0`)
/// and [rollingSamples] streamed from `VoiceCaptureService`.
class OrganicVoiceWaveform extends StatelessWidget {
  const OrganicVoiceWaveform({
    required this.progress,
    this.amplitude = 0.42,
    this.rollingSamples = const <double>[],
    super.key,
  });

  final double progress;
  final double amplitude;
  final List<double> rollingSamples;

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        color: ext.canvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ext.border, width: 1),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: CustomPaint(
                painter: _OrganicWaveformPainter(
                  primaryColor: ext.primaryAccent,
                  secondaryColor: ext.secondaryAccent,
                  amplitude: amplitude.clamp(0.0, 1.0),
                  rollingSamples: rollingSamples,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment((progress.clamp(0.0, 1.0) * 2) - 1, 0),
            child: Container(
              width: 2,
              height: double.infinity,
              color: ext.secondaryAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganicWaveformPainter extends CustomPainter {
  const _OrganicWaveformPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.amplitude,
    required this.rollingSamples,
  });

  final Color primaryColor;
  final Color secondaryColor;
  final double amplitude;
  final List<double> rollingSamples;

  double _sampleAt(int index, double fallback) {
    if (rollingSamples.isEmpty) {
      return fallback;
    }
    final int safeIndex = index % rollingSamples.length;
    return rollingSamples[safeIndex].clamp(0.08, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double midY = h / 2;

    final double energy = (0.22 + amplitude * 0.78).clamp(0.18, 1.0);
    final double s0 = _sampleAt(0, energy);
    final double s1 = _sampleAt(6, energy * 0.9);
    final double s2 = _sampleAt(12, energy);
    final double s3 = _sampleAt(18, energy * 0.85);

    final double swingA = (h * 0.42) * s0;
    final double swingB = (h * 0.45) * s1;
    final double swingC = (h * 0.38) * s2;
    final double swingD = (h * 0.36) * s3;

    final Path primaryRibbon = Path()
      ..moveTo(0, midY)
      ..cubicTo(
        w * 0.12,
        midY - swingA,
        w * 0.24,
        midY + swingA,
        w * 0.36,
        midY * 0.94,
      )
      ..cubicTo(
        w * 0.48,
        midY - swingB,
        w * 0.62,
        midY + swingB,
        w * 0.74,
        midY,
      )
      ..cubicTo(
        w * 0.86,
        midY - swingC,
        w * 0.94,
        midY + swingC,
        w,
        midY * 0.95,
      );

    final Path secondaryRibbon = Path()
      ..moveTo(0, midY * 1.06)
      ..cubicTo(
        w * 0.15,
        midY + swingD,
        w * 0.28,
        midY - swingD,
        w * 0.42,
        midY * 1.06,
      )
      ..cubicTo(
        w * 0.56,
        midY + swingB * 0.85,
        w * 0.68,
        midY - swingB * 0.85,
        w * 0.82,
        midY * 0.90,
      )
      ..cubicTo(
        w * 0.90,
        midY + swingA * 0.65,
        w * 0.96,
        midY - swingA * 0.65,
        w,
        midY * 1.04,
      );

    canvas.drawPath(
      primaryRibbon,
      Paint()
        ..color = primaryColor
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    canvas.drawPath(
      secondaryRibbon,
      Paint()
        ..color = secondaryColor.withValues(alpha: 0.82)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _OrganicWaveformPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.rollingSamples != rollingSamples;
  }
}
