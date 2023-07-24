
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
    var _configBox = await Hive.openBox<String>('config');

    var store = HiveStore(
      eventBox: _eventBox,
      userBox: _userBox,
      configBox: _configBox,
    );
    serviceLocator.registerSingleton<HiveStore>(store);

    return store;
  }

  /// Only for testing purposes
  static Future<HiveStore> initStubbed() async {
    var _eventBox = StubbedBox<String>("events");
    var _userBox = StubbedBox<String>("user");
    var _configBox = StubbedBox<String>("config");

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

class StubbedBox<T> extends Box<T> {
  Map<dynamic, T> store = {};

  @override
  final String name;

  StubbedBox(this.name);

  @override
  Future<int> add(T value) async {
    int length = store.length;
    if (length == 0) {
      store['0'] = value;
    } else {
      store['$length'] = value;
    }

    return Future.value(length);
  }

  @override
  Future<Iterable<int>> addAll(Iterable<T> values) async {
    List<int> addedIndexes = [];
    for (T value in values) {
      int index = await add(value);
      addedIndexes.add(index);
    }

    return Future.value(addedIndexes);
  }

  @override
  Future<int> clear() async {
    int count = store.length;
    store.clear();
    return Future.value(count);
  }

  @override
  Future<void> close() {
    return Future.value();
  }

  @override
  Future<void> compact() {
    return Future.value();
  }

  @override
  bool containsKey(key) {
    return store.containsKey(key);
  }

  @override
  Future<void> delete(key) {
    store.remove(key);
    return Future.value();
  }

  @override
  Future<void> deleteAll(Iterable keys) {
    store.removeWhere((key, value) => keys.contains(key));
    return Future.value();
  }

  @override
  Future<void> deleteAt(int index) {
    return Future.value();
  }

  @override
  Future<void> deleteFromDisk() {
    return Future.value();
  }

  @override
  Future<void> flush() {
    return Future.value();
  }

  @override
  T? get(key, {T? defaultValue}) {
    T? value = store[key] ?? defaultValue;
    return value;
  }

  @override
  T? getAt(int index) {
    return null;
  }

  @override
  bool get isEmpty => store.isEmpty;

  @override
  bool get isNotEmpty => store.isNotEmpty;

  @override
  bool get isOpen => true;

  @override
  keyAt(int index) {
    // TODO: implement keyAt
    throw UnimplementedError();
  }

  @override
  Iterable get keys => store.keys;

  @override
  bool get lazy => throw UnimplementedError();

  @override
  int get length => store.length;

  @override
  // TODO: implement path
  String? get path => throw UnimplementedError();

  @override
  Future<void> put(key, T value) {
    store[key] = value;
    return Future.value();
  }

  @override
  Future<void> putAll(Map<dynamic, T> entries) {
    // TODO: implement putAll
    throw UnimplementedError();
  }

  @override
  Future<void> putAt(int index, T value) {
    // TODO: implement putAt
    throw UnimplementedError();
  }

  @override
  Map<dynamic, T> toMap() {
    // TODO: implement toMap
    throw UnimplementedError();
  }

  @override
  // TODO: implement values
  Iterable<T> get values => store.values;

  @override
  Iterable<T> valuesBetween({startKey, endKey}) {
    // TODO: implement valuesBetween
    throw UnimplementedError();
  }

  @override
  Stream<BoxEvent> watch({key}) {
    // TODO: implement watch
    throw UnimplementedError();
  }

}