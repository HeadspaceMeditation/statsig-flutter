
// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:simple_logger/simple_logger.dart';
import 'package:statsig/src/common/service_locator.dart';
import 'package:statsig/src/statsig_event.dart';
import 'package:statsig/src/statsig_user.dart';

class HiveStore {
  late Box<String> eventBox;
  late Box<String> userBox;
  late Box<String> configBox;
  final SimpleLogger log = SimpleLogger();
  static const String DEFAULT_USER_ID_KEY = "_statsig_null_user_id_key";
  static const String STABLED_ID_KEY = "_statsig_stable_id_key";

  HiveStore({
    required this.eventBox,
    required this.userBox,
    required this.configBox
  });


  static Future<HiveStore> init() async {
    var storeDir = await _getTempDir();
    Hive.init(storeDir.path);

    var _eventBox = await Hive.openBox<String>('events');
    var _userBox = await Hive.openBox<String>('user');
    var _configBox = await Hive.openBox<String>('ids');

    var store = HiveStore(
      eventBox: _eventBox,
      userBox: _userBox,
      configBox: _configBox,
    );
    serviceLocator.registerSingleton<HiveStore>(store);

    return store;
  }

  static Future<Directory> _getTempDir() async {
    var dir = Directory("${Directory.systemTemp.path}/__statsig__");
    if (!await dir.exists()) {
      await dir.create();
    }

    return dir;
  }

  Future<void> logEvent(StatsigEvent event) async {
    try {
      String content = jsonEncode(event.toJson());
      await eventBox.add(content);
    } catch (e) {
      log.severe('[Statsig] Error while caching event ❗: ${e.toString()}');
    }
  }

  Future<void> saveUser(StatsigUser user) async {
    String key = DEFAULT_USER_ID_KEY;
    if (user.userId.isNotEmpty) {
      key = user.userId;
    }

    try {
      String content = jsonEncode(user.toJson());
      await userBox.put(key, content);
    } catch (e) {
      log.severe('[Statsig] Error while caching user ❗: ${e.toString()}');
    }
  }

  StatsigUser? loadUser({String? userId}) {
    String key = userId ?? DEFAULT_USER_ID_KEY;
    String? data = userBox.get(key);
    if (data == null) return null;

    return StatsigUser.fromJson(jsonDecode(data));
  }

  Future<void> saveStableID(String stableID) async {
    try {
      await configBox.put(STABLED_ID_KEY, stableID);
    } catch (e) {
      log.severe('[Statsig] Error while caching stableID ❗: ${e.toString()}');
    }
  }

  String? getStableID() {
    return configBox.get(STABLED_ID_KEY);
  }

  Future<void> saveConfig({String? userId, required String config}) async {
    String key = userId ?? DEFAULT_USER_ID_KEY;
    try {
      await configBox.put(key, config);
    } catch (e) {
      log.severe('[Statsig] Error while caching configs ❗: ${e.toString()}');
    }
  }

  String? getConfig({String? userId}) {
    String key = userId ?? DEFAULT_USER_ID_KEY;
    return configBox.get(key);
  }

  List<String> loadEvents() {
    return eventBox.values.toList();
  }

  Future<int> clearSyncedEvents() async {
    return eventBox.clear();
  }

}