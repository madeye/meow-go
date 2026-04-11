import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../models/proxy_provider.dart';
import '../services/mihomo_api.dart';

class ProvidersScreen extends StatefulWidget {
  final Future<Map<String, ProxyProvider>> Function()?
  getProxyProvidersOverride;
  final Future<Map<String, RuleProvider>> Function()? getRuleProvidersOverride;
  final Future<void> Function(String name)? updateProxyProviderOverride;
  final Future<void> Function(String name)? updateRuleProviderOverride;

  const ProvidersScreen({
    super.key,
    this.getProxyProvidersOverride,
    this.getRuleProvidersOverride,
    this.updateProxyProviderOverride,
    this.updateRuleProviderOverride,
  });

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  Map<String, ProxyProvider> _proxyProviders = {};
  Map<String, RuleProvider> _ruleProviders = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final getProxy =
          widget.getProxyProvidersOverride ??
          MihomoApi.instance.getProxyProviders;
      final getRule =
          widget.getRuleProvidersOverride ??
          MihomoApi.instance.getRuleProviders;
      final proxyResult = await getProxy();
      final ruleResult = await getRule();
      if (mounted) {
        setState(() {
          _proxyProviders = proxyResult;
          _ruleProviders = ruleResult;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _updateProxy(String name) async {
    final fn =
        widget.updateProxyProviderOverride ??
        MihomoApi.instance.updateProxyProvider;
    await fn(name);
    await _load();
  }

  Future<void> _updateRule(String name) async {
    final fn =
        widget.updateRuleProviderOverride ??
        MihomoApi.instance.updateRuleProvider;
    await fn(name);
    await _load();
  }

  static String _formatDate(String iso) {
    if (iso.length >= 10) return iso.substring(0, 10);
    return iso.isEmpty ? '—' : iso;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hasAny = _proxyProviders.isNotEmpty || _ruleProviders.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(s.providers)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : !hasAny
          ? Center(
              child: Text(
                s.noProviders,
                style: const TextStyle(color: Colors.white38),
              ),
            )
          : ListView(
              children: [
                if (_proxyProviders.isNotEmpty) ...[
                  _SectionHeader(s.proxyProviders),
                  for (final entry in _proxyProviders.entries)
                    _ProxyProviderTile(
                      provider: entry.value,
                      onUpdate: () => _updateProxy(entry.key),
                      formatDate: _formatDate,
                    ),
                ],
                if (_ruleProviders.isNotEmpty) ...[
                  _SectionHeader(s.ruleProviders),
                  for (final entry in _ruleProviders.entries)
                    _RuleProviderTile(
                      provider: entry.value,
                      onUpdate: () => _updateRule(entry.key),
                      formatDate: _formatDate,
                    ),
                ],
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

class _ProxyProviderTile extends StatefulWidget {
  final ProxyProvider provider;
  final Future<void> Function() onUpdate;
  final String Function(String) formatDate;

  const _ProxyProviderTile({
    required this.provider,
    required this.onUpdate,
    required this.formatDate,
  });

  @override
  State<_ProxyProviderTile> createState() => _ProxyProviderTileState();
}

class _ProxyProviderTileState extends State<_ProxyProviderTile> {
  bool _updating = false;

  Future<void> _onUpdate() async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await widget.onUpdate();
    } catch (_) {}
    if (mounted) setState(() => _updating = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = widget.provider;
    return ListTile(
      title: Text(
        p.name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${p.vehicleType} · ${s.providerProxyCount(p.proxies.length)} · ${widget.formatDate(p.updatedAt)}',
        style: const TextStyle(fontSize: 11, color: Colors.white54),
      ),
      trailing: TextButton(
        onPressed: _updating ? null : _onUpdate,
        child: Text(_updating ? s.updating : s.update),
      ),
    );
  }
}

class _RuleProviderTile extends StatefulWidget {
  final RuleProvider provider;
  final Future<void> Function() onUpdate;
  final String Function(String) formatDate;

  const _RuleProviderTile({
    required this.provider,
    required this.onUpdate,
    required this.formatDate,
  });

  @override
  State<_RuleProviderTile> createState() => _RuleProviderTileState();
}

class _RuleProviderTileState extends State<_RuleProviderTile> {
  bool _updating = false;

  Future<void> _onUpdate() async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await widget.onUpdate();
    } catch (_) {}
    if (mounted) setState(() => _updating = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = widget.provider;
    return ListTile(
      title: Text(
        p.name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${p.vehicleType} · ${p.behavior} · ${s.providerRuleCount(p.ruleCount)} · ${widget.formatDate(p.updatedAt)}',
        style: const TextStyle(fontSize: 11, color: Colors.white54),
      ),
      trailing: TextButton(
        onPressed: _updating ? null : _onUpdate,
        child: Text(_updating ? s.updating : s.update),
      ),
    );
  }
}
