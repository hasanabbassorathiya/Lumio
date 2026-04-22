import 'dart:async';
import 'package:flutter/material.dart';

class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double scrollSpeed;
  final Duration scrollDelay;
  final TextAlign textAlign;

  const AutoScrollText({
    super.key,
    required this.text,
    this.style,
    this.scrollSpeed = 30.0,
    this.scrollDelay = const Duration(milliseconds: 1000),
    this.textAlign = TextAlign.left,
    double? width, // Maintain parameter compatibility, but actual size determined by layout
  });

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isOverflowing = false;
  bool _isHovering = false;
  double _scrollDistance = 0;
  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 2) // Initial value, will be overwritten by calculated value
        );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void didUpdateWidget(AutoScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      // Reset state
      _controller.stop();
      _controller.reset();
      _checkOverflow();
    }
  }

  void _checkOverflow() {
    // Delayed execution to ensure layout completion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final RenderBox? renderBox =
          _textKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        final containerWidth = renderBox.size.width;
        final textWidth = textPainter.width;

        if (textWidth > containerWidth) {
          final distance = textWidth - containerWidth + 20; // Extra buffer
          final durationSeconds = distance / widget.scrollSpeed;

          setState(() {
            _isOverflowing = true;
            _scrollDistance = distance;
            _controller.duration =
                Duration(milliseconds: (durationSeconds * 1000).toInt());
          });

          // If currently hovering and overflow detected, re-trigger scrolling
          if (_isHovering) {
            _startScrolling();
          }
        } else {
          if (_isOverflowing) {
            setState(() {
              _isOverflowing = false;
            });
            _controller.reset();
          }
        }
      }
    });
  }

  void _onHover(bool hovering) {
    setState(() {
      _isHovering = hovering;
    });

    if (hovering) {
      // Re-check overflow on each hover to adapt to layout width changes
      _checkOverflow();
    } else {
      // Hover ended, stop scrolling
      _controller.stop();
      _controller.animateTo(0, duration: const Duration(milliseconds: 300));
    }
  }

  void _startScrolling() {
    // Delayed scrolling
    Future.delayed(widget.scrollDelay, () {
      if (mounted && _isHovering && _isOverflowing) {
        if (!_controller.isAnimating) {
          _controller.repeat(reverse: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use MouseRegion to detect hover
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: !_isOverflowing
          ? Text(
              widget.text,
              key: _textKey,
              style: widget.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: widget.textAlign,
            )
          : ClipRect(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(-_animation.value * _scrollDistance, 0),
                    child: Text(
                      widget.text,
                      key: _textKey, // Maintain Key for measurement
                      style: widget.style,
                      maxLines: 1,
                      overflow: TextOverflow.visible, // Allow overflow for scrolling display
                      softWrap: false,
                    ),
                  );
                },
              ),
            ),
    );
  }
}
