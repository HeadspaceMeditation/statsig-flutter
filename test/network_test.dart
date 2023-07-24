import 'dart:convert';

import 'package:nock/nock.dart';
import 'package:statsig/src/common/service_locator.dart';
import 'package:statsig/src/disk_storage/hive_store.dart';
import 'package:statsig/src/network_service.dart';
import 'package:statsig/src/statsig_metadata.dart';
import 'package:statsig/statsig.dart';
import 'package:test/test.dart';

void main() {
  NetworkService? networkService;

  setUpAll(() {
    nock.init();
  });

  setUp(() async {
    nock.cleanAll();
    await HiveStore.initStubbed();

    await StatsigMetadata.loadStableID();
    networkService = NetworkService(StatsigOptions(), "client-key");
  });


  tearDown(() {
    serviceLocator.reset();
  });

  group('Network Service', () {
    test('fetching values from the network', () async {
      final interceptor = nock('https://statsigapi.net')
          .post('/v1/initialize', (body) => true)
        ..reply(200,
            '{"feature_gates": {}, "dynamic_configs": {}, "layer_configs": {}, "has_updates": true, "time": 1621637839}');

      final response = await networkService?.initialize(StatsigUser());

      expect(interceptor.isDone, true);
      expect(response, {
        'feature_gates': {},
        'dynamic_configs': {},
        'layer_configs': {},
        'has_updates': true,
        'time': 1621637839
      });
    });

    test('includes private attributes from the user', () async {
      Map requestBody = {};
      nock('https://statsigapi.net').post('/v1/initialize', (body) {
        requestBody = jsonDecode(utf8.decode(body)) as Map;
        return true;
      }).reply(200,
          '{"feature_gates": {}, "dynamic_configs": {}, "layer_configs": {}, "has_updates": true, "time": 1621637839}');

      await networkService?.initialize(
          StatsigUser(userId: "a_user", privateAttributes: {"a": "b"}));

      expect(requestBody["user"]["privateAttributes"], {"a": "b"});
    });
  });
}
