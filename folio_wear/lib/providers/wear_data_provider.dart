import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/wear_lesson.dart';
import '../models/wear_notification.dart';

class WearDataProvider with ChangeNotifier {
  static const _channel = MethodChannel('hu.ekrata.ellenorzoplusz.wear/data');

  static void Function(double delta)? onRotaryInput;

  List<WearLesson> _lessons = [];
  List<WearNotification> _notifications = [];
  DateTime? _lastSync;
  bool _connected = false;
  bool _offlineMode = false;
  bool _isPaired = false;
  String _pairingCode = '';

  List<WearLesson> get lessons => _lessons;
  List<WearNotification> get notifications => _notifications;
  DateTime? get lastSync => _lastSync;
  bool get connected => _connected;
  bool get offlineMode => _offlineMode;
  bool get isPaired => _isPaired;
  String get pairingCode => _pairingCode;

  WearDataProvider() {
    _channel.setMethodCallHandler(_handleNativeCall);
    _loadCached();
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onTimetableReceived':
        _parseTimetable(call.arguments as String);
        break;
      case 'onNotificationsReceived':
        _parseNotifications(call.arguments as String);
        break;
      case 'onConnectionChanged':
        _connected = call.arguments as bool;
        if (_connected && !_isPaired && _pairingCode.isNotEmpty) {
          _sendPairingRequest();
        }
        notifyListeners();
        break;
      case 'onRotaryInput':
        onRotaryInput?.call((call.arguments as num).toDouble());
        break;
      case 'onPairConfirmed':
        final code = call.arguments as String;
        if (code == _pairingCode) {
          _isPaired = true;
          try { await _channel.invokeMethod('setIsPaired', true); } catch (_) {}
          notifyListeners();
        }
        break;
    }
  }

  void _parseTimetable(String json) {
    try {
      final raw = jsonDecode(json) as List<dynamic>;
      _lessons = raw
          .map((e) => WearLesson.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      _lastSync = DateTime.now();
      notifyListeners();
    } catch (e) {
      debugPrint('WearDataProvider: timetable parse error: $e');
    }
  }

  void _parseNotifications(String json) {
    try {
      final raw = jsonDecode(json) as List<dynamic>;
      _notifications = raw
          .map((e) =>
              WearNotification.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    } catch (e) {
      debugPrint('WearDataProvider: notifications parse error: $e');
    }
  }

  Future<void> _loadCached() async {
    try {
      final result = await _channel.invokeMethod<Map>('getCachedData') as Map?;
      if (result != null) {
        if (result['timetable'] != null) {
          _parseTimetable(result['timetable'] as String);
        }
        if (result['notifications'] != null) {
          _parseNotifications(result['notifications'] as String);
        }
        if (result['connected'] != null) {
          _connected = result['connected'] as bool;
        }
        if (result['offlineMode'] != null) {
          _offlineMode = result['offlineMode'] as bool;
        }
        if (result['isPaired'] != null) {
          _isPaired = result['isPaired'] as bool;
        }
        if (result['pairingCode'] != null) {
          _pairingCode = result['pairingCode'] as String;
        }
      }
    } catch (_) {}

    // Generate pairing code if missing
    if (_pairingCode.isEmpty) {
      _pairingCode = _generateCode();
      try { await _channel.invokeMethod('setPairingCode', _pairingCode); } catch (_) {}
    }

    notifyListeners();

    if (!_offlineMode) {
      requestSync();
    }

    // Pull retry: if lessons are still empty after 4s, pull from native cache
    Future.delayed(const Duration(seconds: 4), () async {
      if (_lessons.isEmpty) {
        try {
          await _channel.invokeMethod('pullDataNow');
        } catch (_) {}
      }
    });
  }

  String _generateCode() =>
      List.generate(6, (_) => Random().nextInt(10)).join();

  Future<void> _sendPairingRequest() async {
    try { await _channel.invokeMethod('sendPairingRequest', _pairingCode); } catch (_) {}
  }

  Future<void> requestSync() async {
    try { await _channel.invokeMethod('requestSync'); } catch (_) {}
  }

  Future<void> setOfflineMode(bool offline) async {
    _offlineMode = offline;
    try { await _channel.invokeMethod('setOfflineMode', offline); } catch (_) {}
    notifyListeners();
  }

  Future<void> unpair() async {
    _isPaired = false;
    _pairingCode = _generateCode();
    try {
      await _channel.invokeMethod('setIsPaired', false);
      await _channel.invokeMethod('setPairingCode', _pairingCode);
    } catch (_) {}
    notifyListeners();
  }

  WearLesson? get currentLesson {
    final now = DateTime.now();
    try {
      return _lessons.firstWhere((l) => l.isActiveAt(now) && !l.isCancelled);
    } catch (_) { return null; }
  }

  WearLesson? get nextLesson {
    final now = DateTime.now();
    try {
      return _lessons.firstWhere((l) => l.start.isAfter(now) && !l.isCancelled);
    } catch (_) { return null; }
  }

  List<WearLesson> get todayLessons {
    final today = DateTime.now();
    return _lessons.where((l) =>
        l.start.year == today.year &&
        l.start.month == today.month &&
        l.start.day == today.day).toList();
  }

  /// All lessons in the synced week, grouped by day — used when today is empty.
  Map<DateTime, List<WearLesson>> get weekLessonsByDay {
    final map = <DateTime, List<WearLesson>>{};
    for (final l in _lessons) {
      final day = DateTime(l.start.year, l.start.month, l.start.day);
      map.putIfAbsent(day, () => []).add(l);
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }
}
