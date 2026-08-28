import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SOSButtonWidget extends StatefulWidget {
  final VoidCallback onTriggered;
  final double size;

  const SOSButtonWidget({
    super.key, 
    required this.onTriggered,
    this.size = 140.0,
  });

  @override
  State<SOSButtonWidget> createState() => _SOSButtonWidgetState();
}

class _SOSButtonWidgetState extends State<SOSButtonWidget>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _pulseController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    // 2.0 seconds hold to confirm
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onTriggered();
        _pressController.reset();
        setState(() {
          _isPressed = false;
        });
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handlePressDown(_) {
    HapticFeedback.lightImpact();
    setState(() {
      _isPressed = true;
    });
    _pressController.forward();
  }

  void _handlePressUp(_) {
    if (_pressController.status != AnimationStatus.completed) {
      setState(() {
        _isPressed = false;
      });
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pressController, _pulseController]),
      builder: (context, child) {
        final scale = 1.0 - (_pressController.value * 0.05);
        final progress = _pressController.value;
        final pulse1 = _pulseController.value;
        final pulse2 = (pulse1 + 0.5) % 1.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Ripples (only when not pressed)
            if (!_isPressed) ...[
              _buildRipple(pulse1),
              _buildRipple(pulse2),
            ],

            // Main Button
            GestureDetector(
              onTapDown: _handlePressDown,
              onTapUp: _handlePressUp,
              onTapCancel: () => _handlePressUp(null),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.red.shade400,
                        Colors.red.shade800,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: -2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Hold Progress Ring
                      SizedBox(
                        width: widget.size,
                        height: widget.size,
                        child: CircularProgressIndicator(
                          value: progress,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          backgroundColor: Colors.transparent,
                          strokeWidth: 6,
                        ),
                      ),
                      // Inner Icon and Text
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sos_rounded,
                            size: widget.size * 0.4,
                            color: Colors.white,
                          ),
                          Text(
                            _isPressed ? 'HOLD' : 'TAP & HOLD',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.bold,
                              fontSize: widget.size * 0.1,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRipple(double pulseValue) {
    return Transform.scale(
      scale: 1.0 + (pulseValue * 0.8), // Ripples out to 1.8x size
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.red.withValues(alpha: (1.0 - pulseValue) * 0.5),
            width: 2,
          ),
          color: Colors.red.withValues(alpha: (1.0 - pulseValue) * 0.15),
        ),
      ),
    );
  }
}
