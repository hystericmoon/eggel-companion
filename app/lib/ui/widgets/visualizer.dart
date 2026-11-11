import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ten small bars that move while music plays and settle low when paused.
/// This is decoration: it does not read the real audio.
class Visualizer extends StatefulWidget {
  const Visualizer({super.key, required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(Visualizer old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 22,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 10; i++) ...[
                  Container(
                    width: 4,
                    height: widget.active
                        ? 6 +
                              16 *
                                  (0.5 +
                                      0.5 *
                                          math.sin(
                                            _c.value * 2 * math.pi * 2 +
                                                i * 0.9,
                                          ))
                        : 5,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (i < 9) const SizedBox(width: 3),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
