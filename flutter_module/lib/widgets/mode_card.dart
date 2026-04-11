import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../models/runtime_config.dart';
import '../services/mihomo_api.dart';

typedef GetConfigsFn = Future<RuntimeConfig> Function();
typedef PatchConfigsFn = Future<void> Function(Map<String, dynamic> patch);

class ModeCard extends StatefulWidget {
  final bool isVpnConnected;
  final GetConfigsFn? getConfigsOverride;
  final PatchConfigsFn? patchConfigsOverride;

  const ModeCard({
    super.key,
    required this.isVpnConnected,
    this.getConfigsOverride,
    this.patchConfigsOverride,
  });

  @override
  State<ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<ModeCard> {
  String _mode = 'rule';
  bool _patching = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void didUpdateWidget(ModeCard old) {
    super.didUpdateWidget(old);
    if (!old.isVpnConnected && widget.isVpnConnected) {
      _loadConfig();
    }
  }

  Future<void> _loadConfig() async {
    try {
      final getConfigs =
          widget.getConfigsOverride ?? MihomoApi.instance.getConfigs;
      final config = await getConfigs();
      if (mounted) setState(() => _mode = config.mode);
    } catch (_) {}
  }

  Future<void> _setMode(String mode) async {
    if (_patching) return;
    final prev = _mode;
    setState(() {
      _mode = mode;
      _patching = true;
    });
    try {
      final patch =
          widget.patchConfigsOverride ?? MihomoApi.instance.patchConfigs;
      await patch({'mode': mode});
    } catch (_) {
      if (mounted) setState(() => _mode = prev);
    } finally {
      if (mounted) setState(() => _patching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Text(
                s.mode,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'rule', label: Text(s.modeRule)),
                    ButtonSegment(value: 'global', label: Text(s.modeGlobal)),
                    ButtonSegment(value: 'direct', label: Text(s.modeDirect)),
                  ],
                  selected: {_mode},
                  onSelectionChanged: widget.isVpnConnected && !_patching
                      ? (set) => _setMode(set.first)
                      : null,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              if (_patching)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
