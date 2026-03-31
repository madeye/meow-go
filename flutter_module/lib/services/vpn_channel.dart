import 'dart:async';
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
}
