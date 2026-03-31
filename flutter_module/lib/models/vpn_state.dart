enum VpnState {
  idle,
  connecting,
  connected,
  stopping,
  stopped;

  bool get canToggle => this == stopped || this == idle || this == connected;

  String get label {
    switch (this) {
      case VpnState.idle:
        return 'Not Connected';
      case VpnState.connecting:
        return 'Connecting...';
      case VpnState.connected:
        return 'Connected';
      case VpnState.stopping:
        return 'Disconnecting...';
      case VpnState.stopped:
        return 'Disconnected';
    }
  }
}
