class PlaylistConfig {
  final String up;
  final String down;
  final String left;
  final String right;
  final DateTime createdAt;

  PlaylistConfig({
    required this.up,
    required this.down,
    required this.left,
    required this.right,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  PlaylistConfig copyWith({
    String? up,
    String? down,
    String? left,
    String? right,
  }) =>
      PlaylistConfig(
        up: up ?? this.up,
        down: down ?? this.down,
        left: left ?? this.left,
        right: right ?? this.right,
      );

  Map<String, dynamic> toJson() => {
        'up': up,
        'down': down,
        'left': left,
        'right': right,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PlaylistConfig.fromJson(Map<String, dynamic> json) => PlaylistConfig(
        up: json['up'] as String? ?? '↑',
        down: json['down'] as String? ?? '↓',
        left: json['left'] as String? ?? '←',
        right: json['right'] as String? ?? '→',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  static PlaylistConfig get defaultConfig => PlaylistConfig(
        up: '春',
        down: '秋',
        left: '冬',
        right: '夏',
      );

  @override
  bool operator ==(Object other) =>
      other is PlaylistConfig &&
      other.up == up &&
      other.down == down &&
      other.left == left &&
      other.right == right;

  @override
  int get hashCode => Object.hash(up, down, left, right);
}
