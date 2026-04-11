import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/profile.dart';
import '../models/proxy_group.dart';
import '../models/vpn_state.dart';
import '../models/traffic_stats.dart';
import '../services/mihomo_api.dart';

class VpnChannel {
  static const _method = MethodChannel('io.github.madeye.meow/vpn');
  static const _stateEvent = EventChannel('io.github.madeye.meow/vpn_state');
  static const _trafficEvent = EventChannel('io.github.madeye.meow/traffic');

  static VpnChannel? _instance;
  static VpnChannel get instance => _instance ??= VpnChannel._();
  VpnChannel._();

  Stream<VpnState>? _stateStream;
  Stream<TrafficStats>? _trafficStream;

  Stream<VpnState> get stateStream {
    _stateStream ??= _stateEvent.receiveBroadcastStream().map((event) {
      final index = event as int? ?? 0;
      return VpnState.values[index.clamp(0, VpnState.values.length - 1)];
    });
    return _stateStream!;
  }

  Stream<TrafficStats> get trafficStream {
    _trafficStream ??= _trafficEvent.receiveBroadcastStream().map((event) {
      return TrafficStats.fromMap(event as Map);
    });
    return _trafficStream!;
  }

  Future<void> connect() => _method.invokeMethod('connect');
  Future<void> disconnect() => _method.invokeMethod('disconnect');

  Future<VpnState> getState() async {
    final index = await _method.invokeMethod<int>('getState') ?? 0;
    return VpnState.values[index.clamp(0, VpnState.values.length - 1)];
  }

  Future<List<ClashProfile>> getProfiles() async {
    final list = await _method.invokeMethod<List>('getProfiles') ?? [];
    return list.map((e) => ClashProfile.fromMap(e as Map)).toList();
  }

  Future<ClashProfile?> getSelectedProfile() async {
    final map = await _method.invokeMethod<Map>('getSelectedProfile');
    return map != null ? ClashProfile.fromMap(map) : null;
  }

  Future<void> addSubscription(String name, String url) =>
      _method.invokeMethod('addSubscription', {'name': name, 'url': url});

  Future<void> updateSubscription(int id, String name, String url) =>
      _method.invokeMethod('updateSubscription', {'id': id, 'name': name, 'url': url});

  Future<void> deleteSubscription(int id) =>
      _method.invokeMethod('deleteSubscription', {'id': id});

  Future<void> selectProfile(int id) =>
      _method.invokeMethod('selectProfile', {'id': id});

  Future<void> refreshSubscription(int id) =>
      _method.invokeMethod('refreshSubscription', {'id': id});

  Future<void> refreshAll() => _method.invokeMethod('refreshAll');

  Future<void> saveSelectedProxy(int profileId, String proxyName) =>
      _method.invokeMethod('saveSelectedProxy', {'id': profileId, 'proxyName': proxyName});

  /// Persist per-group selections as a JSON map in Room.
  Future<void> saveSelectedProxies(int profileId, Map<String, String> selections) =>
      _method.invokeMethod('saveSelectedProxies', {
        'id': profileId,
        'proxiesJson': json.encode(selections),
      });

  Future<void> updateProfileYaml(int id, String yamlContent) =>
      _method.invokeMethod('updateProfileYaml', {'id': id, 'yamlContent': yamlContent});

  Future<String> revertProfileYaml(int id) async {
    final result = await _method.invokeMethod<String>('revertProfileYaml', {'id': id});
    return result ?? '';
  }

  Future<List<Map<String, dynamic>>> getTrafficHistory() async {
    final list = await _method.invokeMethod<List>('getTrafficHistory') ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final list = await _method.invokeMethod<List>('getInstalledApps') ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Uint8List?> getAppIcon(String packageName) async {
    return await _method.invokeMethod<Uint8List>('getAppIcon', {'packageName': packageName});
  }

  Future<Map<String, dynamic>> getPerAppConfig() async {
    final map = await _method.invokeMethod<Map>('getPerAppConfig') ?? {};
    return Map<String, dynamic>.from(map);
  }

  Future<void> setPerAppConfig(String mode, List<String> packages) =>
      _method.invokeMethod('setPerAppConfig', {
        'mode': mode,
        'packages': json.encode(packages),
      });

  Future<String> getVersion() async =>
      await _method.invokeMethod<String>('getVersion') ?? '';

  /// Replay persisted per-group selections after VPN connects.
  ///
  /// Fetches the live proxy list from the embedded engine, then calls
  /// [MihomoApi.selectProxy] for each Selector group that has a saved
  /// selection. Groups whose first candidate resolves to DIRECT or REJECT
  /// transitively (kill-switch/bypass groups) are skipped.
  ///
  /// [selectProxy] is injectable for unit testing.
  static Future<void> replaySelectionsOnConnect({
    required ProxiesResult result,
    required Map<String, String> selections,
    Future<void> Function(String group, String name)? selectProxy,
  }) async {
    selectProxy ??= MihomoApi.instance.selectProxy;
    final groupsByName = <String, List<String>>{
      for (final g in result.groups.values) g.name: g.all,
    };
    for (final group in result.groups.values) {
      if (group.type != 'Selector') continue;
      final saved = selections[group.name];
      if (saved == null) continue;
      if (!group.all.contains(saved)) continue;
      if (group.all.isEmpty) continue;
      if (_resolvesToBypass(group.all.first, groupsByName, {})) continue;
      try {
        await selectProxy(group.name, saved);
      } catch (_) {
        // Best-effort; errors are visible in logcat via the engine
      }
    }
  }

  /// Returns true if [name] is DIRECT, REJECT, or a proxy-group whose first
  /// member transitively resolves to DIRECT/REJECT. Guards against cycles.
  static bool _resolvesToBypass(
    String name,
    Map<String, List<String>> groupsByName,
    Set<String> visited,
  ) {
    if (name == 'DIRECT' || name == 'REJECT') return true;
    final nested = groupsByName[name];
    if (nested == null || nested.isEmpty) return false;
    if (!visited.add(name)) return false;
    return _resolvesToBypass(nested.first, groupsByName, visited);
  }
}
