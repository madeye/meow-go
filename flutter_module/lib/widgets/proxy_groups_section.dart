import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../models/proxy_group.dart';
import '../models/proxy.dart';
import '../services/mihomo_api.dart';

typedef SelectProxyFn = Future<void> Function(String group, String name);
typedef TestGroupDelayFn = Future<Map<String, int>> Function(String group);
typedef GetProxiesFn = Future<ProxiesResult> Function();

class ProxyGroupsSection extends StatefulWidget {
  final bool isVpnConnected;
  final Map<String, String> initialSelections;
  final void Function(Map<String, String>) onSelectionsChanged;

  /// YAML to parse when the embedded engine isn't reachable (VPN off or
  /// first run before the engine has ever started). Gives the user a
  /// read-only view of the group/member structure from the selected
  /// profile. Ignored when the live /proxies call succeeds.
  final String? fallbackYamlContent;

  // Test injection (null = use MihomoApi.instance)
  final GetProxiesFn? getProxiesOverride;
  final SelectProxyFn? selectProxyOverride;
  final TestGroupDelayFn? testGroupDelayOverride;

  const ProxyGroupsSection({
    super.key,
    required this.isVpnConnected,
    required this.initialSelections,
    required this.onSelectionsChanged,
    this.fallbackYamlContent,
    this.getProxiesOverride,
    this.selectProxyOverride,
    this.testGroupDelayOverride,
  });

  @override
  State<ProxyGroupsSection> createState() => _ProxyGroupsSectionState();
}

class _ProxyGroupsSectionState extends State<ProxyGroupsSection> {
  ProxiesResult? _result;
  bool _loading = false;
  final Map<String, int> _delays = {};
  late Map<String, String> _selections;
  final Map<String, bool> _expanded = {};
  final Map<String, bool> _testing = {};

  @override
  void initState() {
    super.initState();
    _selections = Map.from(widget.initialSelections);
    _load();
  }

  @override
  void didUpdateWidget(ProxyGroupsSection old) {
    super.didUpdateWidget(old);
    // Refresh live data when VPN flips on.
    if (old.isVpnConnected != widget.isVpnConnected && widget.isVpnConnected) {
      _load();
      return;
    }
    // Retry if the fallback YAML became available after our initial load.
    // HomeScreen loads the selected profile asynchronously, so on first
    // build fallbackYamlContent is null; when it populates, we want to
    // parse it for the offline display.
    final oldYaml = old.fallbackYamlContent ?? '';
    final newYaml = widget.fallbackYamlContent ?? '';
    if (_result == null && oldYaml != newYaml && newYaml.isNotEmpty) {
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final getProxies = widget.getProxiesOverride ?? MihomoApi.instance.getProxies;
      final result = await getProxies();
      if (!mounted) return;
      final delays = <String, int>{};
      for (final proxy in result.proxies.values) {
        delays[proxy.name] = proxy.latestDelay;
      }
      setState(() {
        _result = result;
        _delays.addAll(delays);
        for (final g in result.groups.values) {
          _selections.putIfAbsent(g.name, () => g.now);
        }
      });
    } catch (_) {
      // Engine unreachable (typically VPN off). Fall back to parsing the
      // selected profile YAML so users still see their group structure.
      final fallback = widget.fallbackYamlContent;
      if (fallback != null && fallback.isNotEmpty) {
        final parsed = ProxiesResult.fromYaml(fallback);
        if (mounted && parsed.groups.isNotEmpty) {
          setState(() {
            _result = parsed;
            for (final g in parsed.groups.values) {
              _selections.putIfAbsent(g.name, () => g.now);
            }
          });
        }
      }
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectProxy(String group, String name) async {
    final prev = _selections[group];
    setState(() => _selections[group] = name);
    widget.onSelectionsChanged(Map.from(_selections));

    // When VPN is off the engine isn't running — no live call to make.
    // The selection is persisted via onSelectionsChanged and will be
    // replayed to the engine on the next VPN connect.
    if (!widget.isVpnConnected) return;

    try {
      final selectProxy = widget.selectProxyOverride ?? MihomoApi.instance.selectProxy;
      await selectProxy(group, name);
    } catch (_) {
      if (mounted) {
        setState(() => _selections[group] = prev ?? name);
        widget.onSelectionsChanged(Map.from(_selections));
      }
    }
  }

  Future<void> _testGroupDelay(String group) async {
    setState(() => _testing[group] = true);
    try {
      final testDelay = widget.testGroupDelayOverride ?? MihomoApi.instance.testGroupDelay;
      final results = await testDelay(group);
      if (!mounted) return;
      setState(() => _delays.addAll(results));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _testing[group] = false);
    }
  }

  Color _latencyColor(int ms) {
    if (ms == 0) return Colors.white38;
    if (ms < 150) return Colors.greenAccent;
    if (ms < 400) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Color _typeBadgeColor(String type) {
    switch (type) {
      case 'Selector': return Colors.blueAccent;
      case 'URLTest': return Colors.tealAccent;
      case 'Fallback': return Colors.amberAccent;
      case 'LoadBalance': return Colors.purpleAccent;
      case 'Relay': return Colors.pinkAccent;
      default: return Colors.white24;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    if (_loading && _result == null) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final groups = _result?.groups.values.toList() ?? [];

    if (groups.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            s.noGroups,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                s.proxyGroups,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            );
          }
          final group = groups[index - 1];
          return _GroupCard(
            group: group,
            proxies: _result?.proxies ?? {},
            selected: _selections[group.name] ?? group.now,
            delays: _delays,
            expanded: _expanded[group.name] ?? false,
            testing: _testing[group.name] ?? false,
            onExpand: (v) => setState(() => _expanded[group.name] = v),
            onSelect: (name) => _selectProxy(group.name, name),
            onTest: widget.isVpnConnected ? () => _testGroupDelay(group.name) : null,
            latencyColor: _latencyColor,
            typeBadgeColor: _typeBadgeColor,
          );
        },
        childCount: groups.length + 1,
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final ProxyGroup group;
  final Map<String, Proxy> proxies;
  final String selected;
  final Map<String, int> delays;
  final bool expanded;
  final bool testing;
  final void Function(bool) onExpand;
  final void Function(String)? onSelect;
  final VoidCallback? onTest;
  final Color Function(int) latencyColor;
  final Color Function(String) typeBadgeColor;

  const _GroupCard({
    required this.group,
    required this.proxies,
    required this.selected,
    required this.delays,
    required this.expanded,
    required this.testing,
    required this.onExpand,
    required this.onSelect,
    required this.onTest,
    required this.latencyColor,
    required this.typeBadgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final badgeColor = typeBadgeColor(group.type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Card(
        child: Column(
          children: [
            InkWell(
              onTap: () => onExpand(!expanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                group.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withAlpha(40),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: badgeColor.withAlpha(100)),
                                ),
                                child: Text(
                                  group.type,
                                  style: TextStyle(fontSize: 10, color: badgeColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selected,
                            style: const TextStyle(fontSize: 12, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: Colors.white38,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (testing)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 6),
                            Text(s.testing, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                          ],
                        ),
                      ),
                    IconButton(
                      tooltip: s.urlTestAll,
                      icon: const Icon(Icons.speed, size: 18),
                      onPressed: testing ? null : onTest,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              ...group.all.map((nodeName) {
                final isSelected = nodeName == selected;
                final delay = delays[nodeName] ?? 0;
                final isSelector = group.type == 'Selector';
                return ListTile(
                  dense: true,
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? Colors.greenAccent : Colors.white24,
                    size: 18,
                  ),
                  title: Text(nodeName, style: const TextStyle(fontSize: 13)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: latencyColor(delay).withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      delay > 0 ? s.latencyMs(delay) : s.untested,
                      style: TextStyle(
                        fontSize: 11,
                        color: latencyColor(delay),
                      ),
                    ),
                  ),
                  onTap: isSelector ? () => onSelect?.call(nodeName) : null,
                );
              }),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}
