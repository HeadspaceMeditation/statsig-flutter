import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'disk_util.dart';
import 'network_service.dart';
import 'statsig_event.dart';

const maxQueueLength = 1000;
const loggingIntervalMillis = 10000;
const failedEventsFilename = "failed_events.json";

class StatsigLogger {
  final NetworkService _network;
  final List<StatsigEvent> _queue = [];
  int _flushBatchSize = 50;

  late Timer _flushTimer;

  Timer get flushTimer => _flushTimer;

  StatsigLogger(this._network) {
    _loadFailedLogs();
    _initUpFlushTimer();
  }

  void _initUpFlushTimer() {
    _flushTimer = Timer.periodic(Duration(milliseconds: loggingIntervalMillis), (_) {
      _flush();
    });
  }

  void enqueue(StatsigEvent event) {
    _queue.add(event);

    if (_queue.length >= _flushBatchSize) {
      _flush();
    }
  }

  Future<void> shutdown() async {
    _flushTimer.cancel();
    await _flush(true);
  }

  void resume() {
    _initUpFlushTimer();
  }

  Future<void> _flush([bool isShuttingDown = false]) async {
    if (_queue.isEmpty) {
      return;
    }

    /// Copy logged events
    List<StatsigEvent> events = List.from(_queue);
    /// Clear current queue
    _queue.clear();
    var success = await _network.sendEvents(events);
    if (success) {
      return;
    }

    if (isShuttingDown) {
      /// Add any event that came after we have attempted to send events to the server
      events.addAll(_queue);
      await DiskUtil.write(failedEventsFilename, json.encode(events));
    } else {
      _flushBatchSize = min(_flushBatchSize * 2, maxQueueLength);
      _queue.addAll(events);
    }
  }

  Future<void> _loadFailedLogs() async {
    try {
      var contents = await DiskUtil.read(
        failedEventsFilename,
        destroyAfterReading: true,
      );

      var events = json.decode(contents) as List;
      for (var element in events) {
        _queue.add(StatsigEvent.fromJson(element));
      }

      if (_queue.isNotEmpty) {
        _flush();
      }
    } catch(e) {
      return;
    }
  }
}
