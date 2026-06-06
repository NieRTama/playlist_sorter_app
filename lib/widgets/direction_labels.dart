import 'package:flutter/material.dart';
import '../models/playlist_config.dart';
import '../providers/app_state.dart';

class DirectionLabels extends StatelessWidget {
  final PlaylistConfig config;
  final SwipeDirection? highlighted;

  const DirectionLabels({
    super.key,
    required this.config,
    this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _label(context, config.up, Icons.arrow_upward, SwipeDirection.up,
            Alignment.topCenter, const EdgeInsets.only(top: 20)),
        _label(context, config.down, Icons.arrow_downward, SwipeDirection.down,
            Alignment.bottomCenter, const EdgeInsets.only(bottom: 20)),
        _label(context, config.left, Icons.arrow_back, SwipeDirection.left,
            Alignment.centerLeft, const EdgeInsets.only(left: 12)),
        _label(context, config.right, Icons.arrow_forward, SwipeDirection.right,
            Alignment.centerRight, const EdgeInsets.only(right: 12)),
      ],
    );
  }

  Widget _label(
    BuildContext context,
    String name,
    IconData icon,
    SwipeDirection dir,
    Alignment align,
    EdgeInsets padding,
  ) {
    final isHighlighted = highlighted == dir;
    final color = _colorFor(dir);
    final activeColor = isHighlighted ? color : Colors.white24;

    return Align(
      alignment: align,
      child: Padding(
        padding: padding,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isHighlighted ? color.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHighlighted ? color : Colors.white12,
              width: isHighlighted ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: activeColor, size: 18),
              const SizedBox(height: 2),
              Text(
                name,
                style: TextStyle(
                  color: activeColor,
                  fontSize: 13,
                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorFor(SwipeDirection dir) {
    switch (dir) {
      case SwipeDirection.up:
        return Colors.blue;
      case SwipeDirection.down:
        return Colors.orange;
      case SwipeDirection.left:
        return Colors.purple;
      case SwipeDirection.right:
        return Colors.green;
    }
  }
}
