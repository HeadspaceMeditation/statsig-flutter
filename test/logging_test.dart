@Timeout(Duration(seconds: 1))

import 'dart:async';
import 'dart:convert';

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
    Interceptor? loggingStub;
    Map? logs;
    Completer<bool>? completer;

    setUp(() async {
      final interceptor = nock('https://statsigapi.net')
          .post('/v1/initialize', (body) => true)
        ..reply(200, TestData.initializeResponse);

      client = await StatsigClient.make4Testing(
          'a-key',
          user: StatsigUser(userId: "a-user", privateAttributes: {"secret": "shh"}),
          options: StatsigOptions(environment: StatsigEnvironment.staging));

      expect(interceptor.isDone, true);

      completer = Completer();
      loggingStub = nock('https://statsigapi.net').post('/v1/rgstr', (body) {
        logs = jsonDecode(utf8.decode(body)) as Map;
        return true;
      })
        ..reply(200, '{}')
        ..onReply(() => completer?.complete(true));
      logs = null;
    });

    group("User Object", () {
      setUp(() async {
        client?.checkGate('a_gate');
        client?.shutdown();
        await completer?.future;

        expect(loggingStub?.isDone, true);
      });

      test('logs user id', () async {
        var event = (logs as Map)['events'][0] as Map;
        expect("a-user", event['user']['userID']);
      });

      test('does not log private attributes', () async {
        var event = (logs as Map)['events'][0] as Map;
        expect(null, event['user']['privateAttributes']);
      });

      test('pulls environment off options and adds it to user', () async {
        var event = (logs as Map)['events'][0] as Map;
        expect({"tier": "staging"}, event['user']['statsigEnvironment']);
      });
    });

    group("Feature Gates", () {
      test('does not log gates that do not exist', () async {
        client?.checkGate('not_a_gate');
        client?.shutdown();
        expect(logs, null);
      });

      test('logs gate exposures', () async {
        client?.checkGate('a_gate');
        client?.shutdown();
        await completer?.future;

        expect(loggingStub?.isDone, true);

        var event = (logs as Map)['events'][0] as Map;
        expect(event['eventName'], "statsig::gate_exposure");
        expect(event['metadata'],
            {"gate": "a_gate", "gateValue": "true", "ruleID": "a_rule_id"});
        expect((logs as Map)['statsigMetadata']['sdkType'], 'dart-client');
      });
    });

    group("Dynamic Configs", () {
      test('does not log configs that do not exist', () async {
        client?.checkGate('not_a_config');
        client?.shutdown();
        expect(logs, null);
      });

      test('logs config exposures', () async {
        client?.getConfig('a_config');
        client?.shutdown();
        await completer?.future;

        expect(loggingStub?.isDone, true);

        var event = (logs as Map)['events'][0] as Map;
        expect(event['eventName'], "statsig::config_exposure");
        expect(
            event['metadata'], {"config": "a_config", "ruleID": "a_rule_id"});
        expect((logs as Map)['statsigMetadata']['sdkType'], 'dart-client');
      });
    });
  });
}
