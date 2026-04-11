import 'dart:async';
import 'package:flutter/material.dart';
import '../app.dart' show profileChanged;
import '../l10n/strings.dart';
import '../services/vpn_channel.dart';
import '../services/mihomo_api.dart';
import '../models/vpn_state.dart';
import '../models/traffic_stats.dart';
import '../models/profile.dart';
import '../widgets/proxy_groups_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _vpn = VpnChannel.instance;
  VpnState _state = VpnState.stopped;
  TrafficStats _traffic = const TrafficStats();
  ClashProfile? _profile;
  Map<String, String> _selections = {};
  StreamSubscription? _stateSub;
  StreamSubscription? _trafficSub;

  @override
  void initState() {
    super.initState();
    _loadState();
    profileChanged.addListener(_loadState);
    _stateSub = _vpn.stateStream.listen((s) async {
      final wasConnected = _state == VpnState.connected;
      if (mounted) setState(() => _state = s);
      if (!wasConnected && s == VpnState.connected) {
        await _replaySelections();
      }
    });
    _trafficSub = _vpn.trafficStream.listen((t) {
      if (mounted) setState(() => _traffic = t);
    });
  }

  Future<void> _loadState() async {
    try {
      final state = await _vpn.getState();
      final profile = await _vpn.getSelectedProfile();
      if (mounted) {
        setState(() {
          _state = state;
          final changed = _profile?.id != profile?.id;
          _profile = profile;
          if (changed) {
            _selections = Map.from(profile?.selectedProxies ?? {});
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _replaySelections() async {
    if (_selections.isEmpty) return;
    try {
      final result = await MihomoApi.instance.getProxies();
      await VpnChannel.replaySelectionsOnConnect(
        result: result,
        selections: _selections,
      );
    } catch (_) {}
  }

  void _onSelectionsChanged(Map<String, String> selections) {
    setState(() => _selections = selections);
    if (_profile != null) {
      _vpn.saveSelectedProxies(_profile!.id, selections);
    }
  }

  @override
  void dispose() {
    profileChanged.removeListener(_loadState);
    _stateSub?.cancel();
    _trafficSub?.cancel();
    super.dispose();
  }

  bool _toggling = false;

  Future<void> _toggle(bool value) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      if (value) {
        await _vpn.connect();
      } else {
        await _vpn.disconnect();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _toggling = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isOn = _state == VpnState.connected;
    final isTransitioning =
        _state == VpnState.connecting || _state == VpnState.stopping;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(s.appName),
            actions: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isTransitioning
                    ? const Padding(
                        key: ValueKey('spinner'),
                        padding: EdgeInsets.only(right: 16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Switch(
                        key: const ValueKey('switch'),
                        value: isOn,
                        onChanged: _state.canToggle && !_toggling ? _toggle : null,
                        activeTrackColor: Colors.greenAccent,
                      ),
              ),
            ],
          ),

          SliverToBoxAdapter(child: _buildStatusCard(isOn)),

          if (isOn)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _TrafficTile(
                        icon: Icons.arrow_upward,
                        label: s.upload,
                        rate: _traffic.txRateStr,
                        total: _traffic.txTotalStr,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TrafficTile(
                        icon: Icons.arrow_downward,
                        label: s.download,
                        rate: _traffic.rxRateStr,
                        total: _traffic.rxTotalStr,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          ProxyGroupsSection(
            isVpnConnected: isOn,
            initialSelections: _selections,
            onSelectionsChanged: _onSelectionsChanged,
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isOn) {
    final s = S.of(context);
    String stateLabel(VpnState state) {
      switch (state) {
        case VpnState.idle: return s.notConnected;
        case VpnState.connecting: return s.connecting;
        case VpnState.connected: return s.connected;
        case VpnState.stopping: return s.disconnecting;
        case VpnState.stopped: return s.disconnected;
      }
    }
    final color = isOn ? Colors.greenAccent : Colors.grey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withAlpha(30),
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(
                  isOn ? Icons.vpn_key : Icons.vpn_key_off,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stateLabel(_state),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (_profile != null)
                      Text(
                        _profile!.name,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white54),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrafficTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String rate;
  final String total;

  const _TrafficTile({
    required this.icon,
    required this.label,
    required this.rate,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.white54),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rate,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text('$total $label',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
