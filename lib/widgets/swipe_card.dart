import 'package:flutter/material.dart';
import '../models/song.dart';
import '../models/playlist_config.dart';
import '../providers/app_state.dart';

class SwipeCard extends StatefulWidget {
  final Song song;
  final PlaylistConfig config;
  final void Function(SwipeDirection) onSwiped;
  final VoidCallback onReplay;
  final void Function(SwipeDirection?) onDirectionChanged;

  const SwipeCard({
    super.key,
    required this.song,
    required this.config,
    required this.onSwiped,
    required this.onReplay,
    required this.onDirectionChanged,
  });

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard>
    with SingleTickerProviderStateMixin {
  Offset _offset = Offset.zero;
  SwipeDirection? _hintDir;
  late AnimationController _snapCtrl;
  late Animation<Offset> _snapAnim;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _snapAnim = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(_snapCtrl);
    _snapCtrl.addListener(() {
      setState(() => _offset = _snapAnim.value);
    });
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    super.dispose();
  }

  // Thresholds compared as squared magnitudes to avoid sqrt on every drag frame.
  static const double _hintThresholdSq = 40 * 40;
  static const double _commitThresholdSq = 100 * 100;
  static const double _flingVelocitySq = 600 * 600;

  SwipeDirection? _directionOf(Offset offset) {
    if (offset.distanceSquared < _hintThresholdSq) return null;
    if (offset.dy.abs() > offset.dx.abs()) {
      return offset.dy < 0 ? SwipeDirection.up : SwipeDirection.down;
    } else {
      return offset.dx < 0 ? SwipeDirection.left : SwipeDirection.right;
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _snapCtrl.stop();
    setState(() {
      _offset += d.delta;
      final dir = _directionOf(_offset);
      if (dir != _hintDir) {
        _hintDir = dir;
        widget.onDirectionChanged(dir);
      }
    });
  }

  void _onPanEnd(DragEndDetails d) {
    final vel = d.velocity.pixelsPerSecond;
    SwipeDirection? dir;

    if (vel.distanceSquared > _flingVelocitySq) {
      dir = vel.dy.abs() > vel.dx.abs()
          ? (vel.dy < 0 ? SwipeDirection.up : SwipeDirection.down)
          : (vel.dx < 0 ? SwipeDirection.left : SwipeDirection.right);
    } else if (_offset.distanceSquared > _commitThresholdSq) {
      dir = _directionOf(_offset);
    }

    if (dir != null) {
      widget.onDirectionChanged(null);
      widget.onSwiped(dir);
    } else {
      _snapBack();
    }
  }

  void _onPanCancel() => _snapBack();

  void _snapBack() {
    _snapAnim = Tween<Offset>(begin: _offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _snapCtrl, curve: Curves.elasticOut),
    );
    _snapCtrl.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _hintDir = null;
          widget.onDirectionChanged(null);
        });
      }
    });
  }

  Color _colorFor(SwipeDirection? dir) {
    switch (dir) {
      case SwipeDirection.up:
        return Colors.blue;
      case SwipeDirection.down:
        return Colors.orange;
      case SwipeDirection.left:
        return Colors.purple;
      case SwipeDirection.right:
        return Colors.green;
      case null:
        return Colors.transparent;
    }
  }

  IconData _iconFor(SwipeDirection dir) {
    switch (dir) {
      case SwipeDirection.up:
        return Icons.arrow_upward;
      case SwipeDirection.down:
        return Icons.arrow_downward;
      case SwipeDirection.left:
        return Icons.arrow_back;
      case SwipeDirection.right:
        return Icons.arrow_forward;
    }
  }

  String _nameFor(SwipeDirection dir) {
    switch (dir) {
      case SwipeDirection.up:
        return widget.config.up;
      case SwipeDirection.down:
        return widget.config.down;
      case SwipeDirection.left:
        return widget.config.left;
      case SwipeDirection.right:
        return widget.config.right;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rotation = _offset.dx / 900.0;
    final hintColor = _colorFor(_hintDir);

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      child: Transform(
        transform: Matrix4.identity()
          ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
          ..rotateZ(rotation),
        alignment: Alignment.center,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.78,
          child: Card(
            elevation: _offset.distanceSquared > 100 ? 14 : 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: _hintDir != null
                  ? BorderSide(color: hintColor, width: 2)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.music_note_rounded,
                          size: 56,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.song.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.song.artist.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.song.artist,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (widget.song.album.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.song.album,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 22),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.replay_rounded, size: 16),
                        label: const Text('もう一度聴く'),
                        onPressed: widget.onReplay,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '上下左右にスワイプして仕分け',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                ),

                // Direction hint overlay
                if (_hintDir != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        color: hintColor.withValues(alpha: 0.18),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_iconFor(_hintDir!),
                                  color: hintColor, size: 48),
                              const SizedBox(height: 6),
                              Text(
                                _nameFor(_hintDir!),
                                style: TextStyle(
                                  color: hintColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
