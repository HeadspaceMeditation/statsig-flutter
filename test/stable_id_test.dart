import 'package:nock/nock.dart';
import 'package:statsig/src/common/service_locator.dart';
import 'package:statsig/src/statsig_client.dart';
import 'package:statsig/src/statsig_metadata.dart';
import 'package:statsig/statsig.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'test_data.dart';

void main() {
  final Matcher isUuid = matches(
    RegExp(
      r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-4[0-9A-Fa-f]{3}-[89ABab][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}$',
      caseSensitive: false,
      multiLine: false,
    ),
  );

  group('Stable ID', () {
    setUpAll(() {
      nock.init();
    });

    setUp(() {
      Statsig.reset();
      nock.cleanAll();

      nock('https://statsigapi.net')
          .post('/v1/initialize', (body) => true)
          .reply(200, TestData.initializeResponse);
    });

    tearDown(() {
      serviceLocator.reset();
    });

    group("auto generated stable id", () {
      test('a new uuid is generated', () async {
        /// Given the original value is not set (null)
        String? original;
        await StatsigClient.make4Testing('a-key', options: StatsigOptions(
          overrideStableID: original
        ));

        /// When loadStableID is invoked
        await StatsigMetadata.loadStableID();
        /// New ID
        String current = StatsigMetadata.getStableID();

        expect(current, isNot(original));
        expect(current, isUuid);
      });

      test('overriding uuid', () async {
        /// Given the original value is not set (null)
        String? original = "old_uuid";
        await StatsigClient.make4Testing('a-key', options: StatsigOptions(
            overrideStableID: original
        ));

        String overrideStableId = Uuid().v4();
        /// When loadStableID is invoked with a new stableId
        await StatsigMetadata.loadStableID(overrideStableId);

        /// Updated
        String current = StatsigMetadata.getStableID();

        expect(current, isNot(original));
        expect(current, isUuid);
      });
    });

  });
}
