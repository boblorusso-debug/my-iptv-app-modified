/// Remote repeat policy. No autonomous scrolling or queued repeat backlog:
/// only incoming key repeats advance, at most ten updates per second.
class GuideScrollAcceleration {
  int? _direction;
  Duration? _started, _lastMove;

  int? get direction => _direction;

  int step(int direction, Duration stamp,
      {required bool repeat, required int count}) {
    if (!repeat ||
        _direction != direction ||
        _started == null ||
        stamp < _lastMove!) {
      _direction = direction;
      _started = _lastMove = stamp;
      return direction;
    }
    if (stamp - _lastMove! < const Duration(milliseconds: 100)) return 0;
    _lastMove = stamp;
    // Keep held remote navigation at a steady one-channel-per-repeat pace.
    // Do not accelerate to multi-channel jumps after a long hold.
    return direction;
  }

  void reset() {
    _direction = null;
    _started = _lastMove = null;
  }
}
