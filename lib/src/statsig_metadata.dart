import 'package:statsig/src/common/service_locator.dart';
import 'package:statsig/src/disk_storage/hive_store.dart';
import 'package:uuid/uuid.dart';

class StatsigMetadata {
  static String getSDKVersion() {
    return "0.4.0";
  }

  static String getSDKType() {
    return "dart-client";
  }

  static String _sessionId = Uuid().v4();
  static String getSessionID() {
    return _sessionId;
  }

  static void regenSessionID() {
    _sessionId = Uuid().v4();
  }

  static String _stableId = "";
  static String getStableID() {
    if (_stableId.isEmpty) {
      throw Exception("Stable ID has not yet been loaded");
    }
    return _stableId;
  }

  static Future loadStableID([String? overrideStableID]) async {
    var diskStore = serviceLocator.get<HiveStore>();

    if (overrideStableID != null && overrideStableID.isNotEmpty) {
      _stableId = overrideStableID;
      await diskStore.saveStableID(overrideStableID);
      return;
    }

    _stableId = diskStore.getStableID() ?? "";
    if (_stableId.isEmpty) {
      var id = Uuid().v4();
      await diskStore.saveStableID(id);
      _stableId = id;
    }
  }

  static Map toJson() {
    return {
      "sdkVersion": getSDKVersion(),
      "sdkType": getSDKType(),
      "sessionID": getSessionID(),
      "stableID": getStableID()
    };
  }
}
