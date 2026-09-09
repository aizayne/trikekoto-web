import 'package:flutter/material.dart';

/// A Philippine TODA tricycle: a motorcycle with a passenger sidecar.
///
/// Replaces `Icons.electric_rickshaw`, which is an Indian auto-rickshaw — a
/// different vehicle with a different silhouette, and not what anyone in a
/// barangay is waiting for.
///
/// Drawn rather than shipped as an asset: it takes the theme colour, stays
/// sharp at any size, and adds no dependency for a single glyph.
///
/// Two details do the work of making it read as a tricycle rather than a
/// wagon, which is what earlier attempts looked like:
///
/// * **The canopy sits on posts with an open side.** A solid box on wheels is
///   a cart; a roof on visible posts is a sidecar.
/// * **The motorcycle's wheels are close together, and larger.** Three evenly
///   spaced wheels of one size read as a trailer no matter what sits on top.
class TrikeIcon extends StatelessWidget {
  const TrikeIcon({super.key, this.size = 24, this.color});

  final double size;

  /// Defaults to the surrounding [IconTheme], so it behaves like an `Icon`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color ?? Colors.black;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _TrikePainter(resolved)),
    );
  }
}

class _TrikePainter extends CustomPainter {
  const _TrikePainter(this.color);

  final Color color;

  /// The artwork is authored on a 24x24 grid, the same as a Material icon, so
  /// it sits correctly beside one at the same nominal size.
  static const _grid = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _grid;
    canvas.save();
    canvas.scale(s);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Canopy — sloped down towards the front, the way a sidecar roof is built
    // to shed rain and wind.
    canvas.drawPath(
      Path()
        ..moveTo(2.3, 9.6)
        ..lineTo(3.6, 7.3)
        ..lineTo(10.9, 7.3)
        ..lineTo(10.9, 9.6)
        ..close(),
      fill,
    );

    // The two roof posts, with nothing between them. This gap is the sidecar.
    canvas.drawLine(const Offset(3.1, 9.6), const Offset(3.1, 12.8), stroke);
    canvas.drawLine(const Offset(10.4, 9.6), const Offset(10.4, 12.8), stroke);

    // Passenger body below the opening.
    canvas.drawRect(const Rect.fromLTRB(2.4, 12.8, 11.0, 16.0), stroke);

    // Motorcycle: seat and tank, rising to the handlebar.
    canvas.drawPath(
      Path()
        ..moveTo(11.6, 14.3)
        ..lineTo(14.5, 14.3)
        ..lineTo(16.2, 11.6)
        ..lineTo(18.1, 11.6),
      stroke,
    );

    // Front fork and handlebar.
    canvas.drawPath(
      Path()
        ..moveTo(16.2, 11.6)
        ..lineTo(15.3, 9.9)
        ..lineTo(17.7, 9.9),
      stroke,
    );

    // Rear suspension down to the back wheel.
    canvas.drawLine(const Offset(18.1, 11.6), const Offset(19.5, 14.8), stroke);

    // Sidecar wheel is smaller and set slightly lower — it carries less, and
    // the size difference is what stops the three reading as a train.
    canvas.drawCircle(const Offset(6.4, 17.9), 2.0, stroke);
    canvas.drawCircle(const Offset(14.3, 17.5), 2.4, stroke);
    canvas.drawCircle(const Offset(19.7, 17.5), 2.4, stroke);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrikePainter old) => old.color != color;
}
