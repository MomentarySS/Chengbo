import 'package:flutter/material.dart';

/// 一行放不下就横向慢滚；放得下则静止。ICY 曲名用。
class OverflowMarquee extends StatefulWidget {
  const OverflowMarquee({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.height = 18,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final double height;

  @override
  State<OverflowMarquee> createState() => _OverflowMarqueeState();
}

class _OverflowMarqueeState extends State<OverflowMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _overflow = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant OverflowMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _overflow = 0;
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _configure(double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final overflow = (painter.width - maxWidth).clamp(0.0, 4000.0);
    if (overflow <= 2) {
      if (_overflow != 0) {
        _overflow = 0;
        _controller.stop();
      }
      return;
    }
    if ((overflow - _overflow).abs() < 1 && _controller.isAnimating) return;
    _overflow = overflow;
    final seconds = 6 + overflow / 40;
    _controller
      ..duration = Duration(milliseconds: (seconds * 1000).round())
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _configure(constraints.maxWidth);
          if (_overflow <= 2) {
            return Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: widget.textAlign,
              style: widget.style,
            );
          }
          return ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                final travel = t < 0.15
                    ? 0.0
                    : t > 0.85
                        ? _overflow
                        : _overflow * ((t - 0.15) / 0.7);
                return Transform.translate(
                  offset: Offset(-travel, 0),
                  child: child,
                );
              },
              child: Text(
                widget.text,
                maxLines: 1,
                softWrap: false,
                style: widget.style,
              ),
            ),
          );
        },
      ),
    );
  }
}
