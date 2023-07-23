import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:simple_logger/simple_logger.dart';
import 'package:statsig/src/common/service_locator.dart';
import 'package:statsig/src/disk_storage/hive_store.dart';

import 'network_service.dart';
import 'statsig_event.dart';

const maxQueueLength = 1000;
const loggingIntervalInSecs = 10;
const pendingEventsFileName = "failed_events.json";

class StatsigLogger {
  final SimpleLogger log = SimpleLogger();

  final NetworkService _network;
  List<StatsigEvent> _queue = [];
  int _flushBatchSize = 50;
  late Timer _flushTimer;
  late final HiveStore _diskStore;

  Timer get flushTimer => _flushTimer;

  StatsigLogger(this._network) {
    _diskStore = serviceLocator.get<HiveStore>();
    _flushFailedLogs();
    _initFlushTimer();
  }

  void _initFlushTimer() {
    _flushTimer = Timer.periodic(Duration(seconds: loggingIntervalInSecs), (_) {
      _flush();
    });
  }

  Future<void> enqueue(StatsigEvent event) async {
    _queue.add(event);
    await cacheEvent(event);

    log.info('[Statsig] New event queued 🎉 Name: ${event.eventName}, Queue count: ${_queue.length}');

    if (_queue.length >= _flushBatchSize) {
      _flush();
    }
  }

  Future<void> cacheEvent(StatsigEvent event) async {
    try {
      await _diskStore.logEvent(event);
    } catch (e) {
      log.severe('[Statsig] Error while caching event 😞: ${e.toString()}');
    }
  }

  Future<void> shutdown() async {
    _flushTimer.cancel();
    log.info('[Statsig] Flush timer paused 💡');
    await _flush();
  }

  void resume() {
    _initFlushTimer();

    log.info('[Statsig] Flush timer resumed 💡');
  }

  Future<void> _flush() async {
    if (_queue.isEmpty) {
      return;
    }

    /// Copy logged events
    List<StatsigEvent> events = List.from(_queue);

    /// Clear current queue
    _queue.clear();
    bool success = await _network.sendEvents(events);
    if (success) {
      log.info('[Statsig] Events uploaded successfully 🚀. Queue count: ${_queue.length}');
      await _diskStore.clearSyncedEvents();

      /// Store any event that came after we have attempted
      /// to send events to the server
      if (_queue.isNotEmpty) {
        for (var event in _queue) {
          await cacheEvent(event);
        }
      }
      return;
    }

    _queue = [...events, ..._queue];
    _flushBatchSize = min((_flushBatchSize * 1.2).toInt(), maxQueueLength);

    log.info('[Statsig] Failed to upload events 😞. Batch count: ${events.length}, '
        'Queue count: ${_queue.length}, New Flush batch size: $_flushBatchSize');
  }

  Future<void> _flushFailedLogs() async {
    try {
      var events = _diskStore.loadEvents();
      log.info('[Statsig] Attempting to flush past events 💡, '
          'Event count: ${events.length}');


      for (String event in events) {
        try {
          Map<String, dynamic> data = jsonDecode(event);
          _queue.add(StatsigEvent.fromJson(data));
        } catch (e) {
          log.severe('[Statsig] Failed to decode event 😞 error: ${e.toString()}');
        }
      }

      await _flush();
    } catch(e) {
      log.severe('[Statsig] Failed to flush failed events 😞 error: ${e.toString()}');
    }
  }
}
