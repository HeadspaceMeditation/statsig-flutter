import 'dart:convert';

import 'package:statsig/src/common/service_locator.dart';
import 'package:statsig/src/disk_storage/hive_store.dart';
import 'statsig_user.dart';

class InternalStore {
  Map featureGates = {};
  Map dynamicConfigs = {};
  Map layerConfigs = {};

  late final HiveStore diskStore;

  InternalStore() {
    diskStore = serviceLocator.get<HiveStore>();
  }

  Future<void> load(StatsigUser user) async {
    var store = _read(user);
    await save(user, store);
  }

  Future<void> save(StatsigUser user, Map? response) async {
    featureGates = response?["feature_gates"] ?? {};
    dynamicConfigs = response?["dynamic_configs"] ?? {};
    layerConfigs = response?["layer_configs"] ?? {};

    await _write(
        user,
        json.encode({
          "feature_gates": featureGates,
          "dynamic_configs": dynamicConfigs,
          "layer_configs": layerConfigs,
        }));
  }

  Future<void> clear() async {
    featureGates = {};
    dynamicConfigs = {};
    layerConfigs = {};
  }

  Future<void> _write(StatsigUser user, String content) async {
    await diskStore.saveConfig(userId: user.userId, config: content);
  }

  Map? _read(StatsigUser user) {
    try {
      String? content = diskStore.getConfig(userId: user.userId);
      var data = json.decode(content ?? '');
      return data is Map ? data : null;
    } catch (_) {}
    return null;
  }
}
