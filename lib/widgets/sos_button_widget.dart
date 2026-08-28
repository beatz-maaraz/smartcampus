import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SOSButtonWidget extends StatefulWidget {
  final VoidCallback onTriggered;
  final double size;

  const SOSButtonWidget({
    super.key, 
    required this.onTriggered,
    this.size = 72.0,
  });

  @override
  State<SOSButtonWidget> createState() => _SOSButtonWidgetState();
}

class _SOSButtonWidgetState extends State<SOSButtonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    // 2.5 seconds hold to confirm
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onTriggered();
        _controller.reset();
        setState(() {
          _isPressed = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePressDown(_) {
    HapticFeedback.lightImpact();
    setState(() {
      _isPressed = true;
    });
    _controller.forward();
  }

  void _handlePressUp(_) {
    if (_controller.status != AnimationStatus.completed) {
      setState(() {
        _isPressed = false;
      });
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handlePressDown,
      onTapUp: _handlePressUp,
      onTapCancel: () => _handlePressUp(null),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 + (_controller.value * 0.1);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade700,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4 + (_controller.value * 0.4)),
                    blurRadius: 15 + (_controller.value * 20),
                    spreadRadius: 2 + (_controller.value * 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress indicator filling up
                  SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: CircularProgressIndicator(
                      value: _controller.value,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 4,
                    ),
                  ),
                  Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: widget.size * 0.25,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
