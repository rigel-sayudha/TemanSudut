import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SlideToFinish extends StatefulWidget {
  final VoidCallback onSlideSuccess;
  final String text;
  final bool isEnabled;

  const SlideToFinish({
    super.key,
    required this.onSlideSuccess,
    this.text = 'Slide to Finish Order',
    this.isEnabled = true,
  });

  @override
  State<SlideToFinish> createState() => _SlideToFinishState();
}

class _SlideToFinishState extends State<SlideToFinish>
    with SingleTickerProviderStateMixin {
  double _dragValue = 0.0;
  bool _isSuccess = false;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _triggerSuccessSoundAndHaptic() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
    Future.delayed(const Duration(milliseconds: 150), () {
      HapticFeedback.mediumImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double containerHeight = 64.0;
        final double handleSize = 56.0;
        final double maxDrag =
            maxWidth - containerHeight; // Adjust for internal padding 4*2

        return Opacity(
          opacity: widget.isEnabled ? 1.0 : 0.4,
          child: Container(
            height: containerHeight,
            width: maxWidth,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isSuccess
                    ? [Colors.green[400]!, Colors.green[600]!]
                    : [const Color(0xFF1E1E1E), const Color(0xFF2D2D2D)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(containerHeight / 2),
              boxShadow: [
                BoxShadow(
                  color: (_isSuccess ? Colors.green : Colors.black).withOpacity(
                    0.3,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isSuccess ? 0.0 : (1.0 - _dragValue),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _pulseAnimation.value,
                              child: const Icon(
                                Icons.double_arrow_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isSuccess)
                  const Center(
                    child: Text(
                      'BERHASIL!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),

                if (!_isSuccess && _dragValue > 0)
                  Positioned(
                    left: 0,
                    child: Container(
                      height: containerHeight,
                      width: containerHeight + (_dragValue * maxDrag),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(
                          containerHeight / 2,
                        ),
                      ),
                    ),
                  ),

                // Slidable Handle
                Positioned(
                  left: 4 + (_dragValue * maxDrag),
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (!widget.isEnabled || _isSuccess) return;
                      setState(() {
                        _dragValue += details.delta.dx / maxDrag;
                        _dragValue = _dragValue.clamp(0.0, 1.0);
                      });
                      if (_dragValue > 0.0 && _dragValue < 1.0) {
                        if ((_dragValue * 100).toInt() % 15 == 0) {
                          HapticFeedback.selectionClick();
                        }
                      }
                    },
                    onHorizontalDragEnd: (details) {
                      if (!widget.isEnabled || _isSuccess) return;
                      if (_dragValue > 0.8) {
                        setState(() {
                          _dragValue = 1.0;
                          _isSuccess = true;
                        });

                        _triggerSuccessSoundAndHaptic();
                        widget.onSlideSuccess();

                        Future.delayed(const Duration(milliseconds: 1500), () {
                          if (mounted) {
                            setState(() {
                              _dragValue = 0.0;
                              _isSuccess = false;
                            });
                          }
                        });
                      } else {
                        setState(() {
                          _dragValue = 0.0;
                        });
                        HapticFeedback.lightImpact(); // Snapped back
                      }
                    },
                    child: Container(
                      width: handleSize,
                      height: handleSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(2, 0),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isSuccess
                            ? Icons.check_circle_rounded
                            : Icons.chevron_right_rounded,
                        color: _isSuccess
                            ? Colors.green[600]
                            : const Color(0xFF2D2D2D),
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
