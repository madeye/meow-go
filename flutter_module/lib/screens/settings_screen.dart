import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/strings.dart';
import '../models/runtime_config.dart';
import '../services/mihomo_api.dart';
import 'per_app_proxy_screen.dart';
import 'logs_screen.dart';

typedef GetConfigsFn = Future<RuntimeConfig> Function();
typedef PatchConfigsFn = Future<void> Function(Map<String, dynamic> patch);

class SettingsScreen extends StatefulWidget {
  // Test injection (null = use MihomoApi.instance)
  final GetConfigsFn? getConfigsOverride;
  final PatchConfigsFn? patchConfigsOverride;

  const SettingsScreen({
    super.key,
    this.getConfigsOverride,
    this.patchConfigsOverride,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _method = MethodChannel('io.github.madeye.meow/vpn');

  bool _allowLan = false;
  bool _ipv6 = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final getConfigs =
          widget.getConfigsOverride ?? MihomoApi.instance.getConfigs;
      final config = await getConfigs();
      if (mounted) {
        setState(() {
          _allowLan = config.allowLan;
          _ipv6 = config.ipv6;
        });
      }
    } catch (_) {}
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    try {
      final patchFn =
          widget.patchConfigsOverride ?? MihomoApi.instance.patchConfigs;
      await patchFn(patch);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        children: [
          _SectionHeader(s.general),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(s.version),
            subtitle: FutureBuilder<String?>(
              future: _method.invokeMethod<String>('getVersion'),
              builder: (_, snap) => Text(snap.data ?? 'Loading...'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.apps),
            title: Text(s.perAppProxy),
            subtitle: Text(s.perAppProxyDesc),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PerAppProxyScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text(s.logs),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogsScreen()),
            ),
          ),
          _SectionHeader(s.runtimeConfig),
          SwitchListTile(
            key: const Key('switch_allow_lan'),
            secondary: const Icon(Icons.lan_outlined),
            title: Text(s.allowLan),
            subtitle: Text(s.allowLanDesc),
            value: _allowLan,
            onChanged: (v) {
              setState(() => _allowLan = v);
              _patch({'allow-lan': v});
            },
          ),
          SwitchListTile(
            key: const Key('switch_ipv6'),
            secondary: const Icon(Icons.travel_explore),
            title: Text(s.ipv6),
            subtitle: Text(s.ipv6Desc),
            value: _ipv6,
            onChanged: (v) {
              setState(() => _ipv6 = v);
              _patch({'ipv6': v});
            },
          ),
          _SectionHeader(s.network),
          ListTile(
            leading: const Icon(Icons.dns),
            title: Text(s.dnsServer),
            subtitle: Text(s.dnsBuiltIn),
          ),
          ListTile(
            leading: const Icon(Icons.hub),
            title: Text(s.mixedPort),
            subtitle: Text(s.mixedPortDesc),
          ),
          ListTile(
            leading: const Icon(Icons.api),
            title: Text(s.apiController),
            subtitle: Text(s.apiAddr),
          ),
          _SectionHeader(s.about),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(s.sourceCode),
            subtitle: Text(s.sourceCodeUrl),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
