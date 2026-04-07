import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/profile.dart';
import '../models/vpn_state.dart';
import '../models/traffic_stats.dart';

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

  /// Select a proxy node in every Selector group whose default (first
  /// listed proxy) is not `DIRECT`. Groups that default to DIRECT are
  /// treated as bypass/direct groups and left untouched.
  /// [yamlContent] is the profile YAML used to find group membership.
  Future<void> selectProxyNode(String nodeName, String yamlContent) async {
    final groups = _parseSelectorGroups(yamlContent);
    final client = HttpClient();
    try {
      for (final group in groups) {
        final groupName = group['name'] as String? ?? '';
        final proxies = group['proxies'] as List<String>? ?? const [];
        if (proxies.isEmpty) continue;
        if (proxies.first == 'DIRECT') continue;
        if (!proxies.contains(nodeName)) continue;

        final putReq = await client.put(
            '127.0.0.1', 9090, '/proxies/${Uri.encodeComponent(groupName)}');
        putReq.headers.contentType = ContentType.json;
        putReq.write(json.encode({'name': nodeName}));
        final putRes = await putReq.close();
        await putRes.drain();
      }
    } finally {
      client.close();
    }
  }

  /// Parse proxy-groups of type "select" from YAML, returning group name + proxy list.
  static List<Map<String, dynamic>> _parseSelectorGroups(String yaml) {
    final result = <Map<String, dynamic>>[];
    final lines = yaml.split('\n');
    var inGroups = false;
    var inGroup = false;
    var inProxies = false;
    String? currentName;
    String? currentType;
    List<String> currentProxies = [];

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed == 'proxy-groups:') {
        inGroups = true;
        continue;
      }

      if (!inGroups) continue;

      // New top-level section ends proxy-groups
      if (!line.startsWith(' ') && trimmed.isNotEmpty && trimmed != 'proxy-groups:') {
        // Save last group
        if (currentName != null && currentType == 'select') {
          result.add({'name': currentName, 'proxies': currentProxies});
        }
        inGroups = false;
        continue;
      }

      // New group entry
      if (line.startsWith('  - name:') || line.startsWith('  - {name:')) {
        // Save previous group
        if (currentName != null && currentType == 'select') {
          result.add({'name': currentName, 'proxies': currentProxies});
        }
        final match = RegExp(r'name:\s*(.+?)(?:,|\s*$)').firstMatch(line);
        currentName = match?.group(1)?.trim();
        currentType = null;
        currentProxies = [];
        inGroup = true;
        inProxies = false;
        continue;
      }

      if (!inGroup) continue;

      if (trimmed.startsWith('type:')) {
        currentType = trimmed.substring(5).trim();
      } else if (trimmed == 'proxies:') {
        inProxies = true;
      } else if (inProxies && trimmed.startsWith('- ')) {
        currentProxies.add(trimmed.substring(2).trim());
      } else if (inProxies && !trimmed.startsWith('-') && trimmed.isNotEmpty) {
        inProxies = false;
      }
    }

    // Save last group
    if (currentName != null && currentType == 'select') {
      result.add({'name': currentName, 'proxies': currentProxies});
    }

    return result;
  }
}
