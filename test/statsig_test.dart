import 'package:nock/nock.dart';
import 'package:statsig/src/common/service_locator.dart';
import 'package:statsig/src/statsig_client.dart';
import 'package:statsig/statsig.dart';
import 'package:test/test.dart';

import 'test_data.dart';

void main() {
  StatsigClient? client;

  setUpAll(() {
    nock.init();
  });

  setUp(() {
    Statsig.reset();
    nock.cleanAll();
  });

  tearDown(() {
    client = null;
    serviceLocator.reset();
  });

  group('Statsig when Initialized', () {
    setUp(() async {
      final interceptor = nock('https://statsigapi.net')
          .post('/v1/initialize', (body) => true)
        ..reply(200, TestData.initializeResponse);

      client = await StatsigClient.make4Testing('a-key');

      expect(interceptor.isDone, true);
    });

    group('Feature Gates', () {
      test('returns gate value from network', () {
        expect(client?.checkGate('a_gate'), true);
      });
      test('returns false by default', () {
        expect(client?.checkGate('no_gate'), false);
      });
      test('returns default value for gate', () {
        expect(client?.checkGate('no_gate', true), true);
      });
    });

    group('Configs', () {
      test('returns config from network', () {
        var config = client!.getConfig("a_config");

        expect(config.name, "a_config");
        expect(config.get("a_string_value"), "foo");
        expect(config.get("a_bool_value"), true);
        expect(config.get("a_number_value"), 420);
      });

      test('returns and empty config by default', () {
        var config = client!.getConfig("no_config");
        expect(config.name, "no_config");
        expect(config.get("a_string_value"), null);
      });

      test('returns default values', () {
        var config = client!.getConfig("no_config");
        expect(config.name, "no_config");
        expect(config.get("a_string_value", "bar"), "bar");
        expect(config.get("a_bool_value", true), true);
        expect(config.get("a_number_value", 7), 7);
      });
    });

    group('Statsig when Uninitialized', () {
      test('returns default gate value', () {
        expect(client!.checkGate('unknown_gate', true), true);
        expect(client!.checkGate('unknown_gate', false), false);
      });
    });
  });


}
