/// DP1 cast intent (e.g. now_display, schedule_play).
enum DP1Action {
  now,
  schedulePlay
  ;

  String get value {
    switch (this) {
      case DP1Action.now:
        return 'now_display';
      case DP1Action.schedulePlay:
        return 'schedule_play';
    }
  }

  static DP1Action fromString(String value) {
    switch (value) {
      case 'now_display':
        return DP1Action.now;
      case 'schedule_play':
        return DP1Action.schedulePlay;
      default:
        throw ArgumentError('Unknown action type: $value');
    }
  }
}

/// Intent for casting a DP1 playlist to FF1.
class DP1Intent {
  DP1Intent({required this.action});

  DP1Intent.displayNow() : action = DP1Action.now;

  factory DP1Intent.fromJson(Map<String, dynamic> json) {
    return DP1Intent(
      action: DP1Action.fromString(json['action'] as String),
    );
  }

  DP1Action action;

  Map<String, dynamic> toJson() => {
    'action': action.value,
  };
}
