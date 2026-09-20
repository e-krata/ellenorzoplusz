// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:folio_kreta_api/models/exam.dart';
import 'package:folio_kreta_api/models/homework.dart';
import 'package:folio_kreta_api/models/lesson.dart';
import 'package:folio_kreta_api/models/week.dart';
import 'package:folio_kreta_api/providers/absence_provider.dart';
import 'package:folio_kreta_api/providers/exam_provider.dart';
import 'package:folio_kreta_api/providers/grade_provider.dart';
import 'package:folio_kreta_api/providers/homework_provider.dart';
import 'package:folio_kreta_api/providers/message_provider.dart';
import 'package:folio_kreta_api/providers/note_provider.dart';
import 'package:folio_kreta_api/providers/timetable_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';

/// Serializes Kréta data and sends it to the paired WearOS watch via
/// Android's Wearable Data Layer API (method channel → WearSyncManager.kt).
///
/// Call [syncToWatch] after every [syncAll] and whenever timetable changes.
class WearProvider with ChangeNotifier {
  static const _channel = MethodChannel('hu.ekrata.ellenorzoplusz/wear_sync');

  bool _watchConnected = false;
  bool _syncEnabled = true;
  DateTime? _lastSync;
  String _lastTimetableHash = '';
  String _lastNotificationsHash = '';
  String _lastTimetableJson = '';
  String _lastNotificationsJson = '';

  /// Non-null when the watch has sent a pairing request and needs confirmation.
  String? _pendingPairCode;

  bool get watchConnected => _watchConnected;
  bool get syncEnabled => _syncEnabled;
  DateTime? get lastSync => _lastSync;
  String? get pendingPairCode => _pendingPairCode;

  WearProvider() {
    _channel.setMethodCallHandler(_handleNativeCall);
    _init();
  }

  // ── Initialization ───────────────────────────────────────────────────────

  Future<void> _init() async {
    await _loadSettings();
    await _checkConnection();
    await _scheduleMorningSync();
  }

  Future<void> _loadSettings() async {
    try {
      final enabled =
          await _channel.invokeMethod<bool>('getSyncEnabled') ?? true;
      _syncEnabled = enabled;
    } catch (_) {}
  }

  // ── Connection ───────────────────────────────────────────────────────────

  Future<void> _checkConnection() async {
    try {
      final connected =
          await _channel.invokeMethod<bool>('isWatchConnected') ?? false;
      if (_watchConnected != connected) {
        _watchConnected = connected;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> refreshConnection() async {
    await _checkConnection();
    return _watchConnected;
  }

  // ── Public sync entry point ──────────────────────────────────────────────

  /// Called from [syncAll] after data fetch completes, and from the
  /// settings screen for manual sync. Reads current provider state via [ctx].
  Future<void> syncToWatch(BuildContext ctx) async {
    if (!_syncEnabled) return;

    final timetableJson = _buildTimetableJson(ctx);
    final notifJson = _buildNotificationsJson(ctx);

    final tHash = _hash(timetableJson);
    final nHash = _hash(notifJson);

    if (tHash != _lastTimetableHash) {
      _lastTimetableHash = tHash;
      await _sendTimetable(timetableJson);
    }
    if (nHash != _lastNotificationsHash) {
      _lastNotificationsHash = nHash;
      await _sendNotifications(notifJson);
    }
  }

  /// Force-send everything regardless of hash (used by manual sync button).
  Future<void> forceSyncToWatch(BuildContext ctx) async {
    if (!_syncEnabled) return;
    final timetableJson = _buildTimetableJson(ctx);
    final notifJson = _buildNotificationsJson(ctx);
    _lastTimetableHash = _hash(timetableJson);
    _lastNotificationsHash = _hash(notifJson);
    await _sendTimetable(timetableJson);
    await _sendNotifications(notifJson);
  }

  // ── JSON builders ────────────────────────────────────────────────────────

  String _buildTimetableJson(BuildContext ctx) {
    try {
      final timetable = Provider.of<TimetableProvider>(ctx, listen: false);
      final homeworks =
          Provider.of<HomeworkProvider>(ctx, listen: false).homework;
      final exams = Provider.of<ExamProvider>(ctx, listen: false).exams;

      final today = DateTime.now();
      final week = Week.fromDate(today);
      // Send the full week so the watch can filter for the current day itself.
      // This prevents stale "today-only" cache from showing wrong data next day.
      final lessons = [...(timetable.lessons[week] ?? [])]
        ..sort((a, b) => a.start.compareTo(b.start));

      return jsonEncode(
          lessons.map((l) => _lessonToWearJson(l, homeworks, exams)).toList());
    } catch (e) {
      if (kDebugMode) print('WearProvider: buildTimetableJson error: $e');
      return '[]';
    }
  }

  Map<String, dynamic> _lessonToWearJson(
      Lesson lesson, List<Homework> homeworks, List<Exam> exams) {
    String status = 'normal';
    if (lesson.status?.name == 'Elmaradt' ||
        (lesson.status?.id.contains('Elmaradt') ?? false)) {
      status = 'cancelled';
    } else if (lesson.substituteTeacher != null) {
      status = 'substitution';
    }

    final subjectName = (lesson.subject.renamedTo?.isNotEmpty ?? false)
        ? lesson.subject.renamedTo!
        : lesson.subject.name;

    final teacherName = lesson.substituteTeacher != null
        ? ((lesson.substituteTeacher!.renamedTo?.isNotEmpty ?? false)
            ? lesson.substituteTeacher!.renamedTo!
            : lesson.substituteTeacher!.name)
        : ((lesson.teacher.renamedTo?.isNotEmpty ?? false)
            ? lesson.teacher.renamedTo!
            : lesson.teacher.name);

    final index =
        int.tryParse(lesson.lessonIndex.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    // Match homework: assigned on the same day as this lesson, same subject.
    final lessonDay = DateTime(
        lesson.start.year, lesson.start.month, lesson.start.day);
    final hasHomework = homeworks.any((h) {
      final hDay =
          DateTime(h.lessonDate.year, h.lessonDate.month, h.lessonDate.day);
      return hDay == lessonDay && h.subject.name == lesson.subject.name;
    });

    // Match exam: written on the same day as this lesson, same subject.
    final hasExam = exams.any((e) {
      final eDay =
          DateTime(e.writeDate.year, e.writeDate.month, e.writeDate.day);
      return eDay == lessonDay && e.subject.name == lesson.subject.name;
    });

    return {
      'id': lesson.id,
      'subject': subjectName,
      'room': lesson.room,
      'teacher': teacherName,
      'start': lesson.start.millisecondsSinceEpoch,
      'end': lesson.end.millisecondsSinceEpoch,
      'lessonIndex': index,
      'status': status,
      'online': lesson.online,
      'hasHomework': hasHomework,
      'hasExam': hasExam,
    };
  }

  String _buildNotificationsJson(BuildContext ctx) {
    try {
      final grades = Provider.of<GradeProvider>(ctx, listen: false).grades;
      final messages =
          Provider.of<MessageProvider>(ctx, listen: false).messages;
      final notes = Provider.of<NoteProvider>(ctx, listen: false).notes;
      final absences =
          Provider.of<AbsenceProvider>(ctx, listen: false).absences;

      final items = <Map<String, dynamic>>[];

      for (final g in grades) {
        final value = g.value.valueName.isNotEmpty
            ? g.value.valueName
            : g.value.value > 0
                ? '${g.value.value}'
                : '';
        items.add({
          'id': g.id,
          'title': g.subject.name,
          'body':
              [g.description, value].where((s) => s.isNotEmpty).join(' – '),
          'type': 'grade',
          'gradeValue': g.value.value > 0 ? g.value.value : null,
          'timestamp': g.date.millisecondsSinceEpoch,
        });
      }

      for (final m in messages) {
        items.add({
          'id': '${m.id}',
          'title': m.subject,
          'body': m.author,
          'type': 'message',
          'timestamp': m.date.millisecondsSinceEpoch,
        });
      }

      for (final n in notes) {
        items.add({
          'id': n.id,
          'title': n.title,
          'body': n.content,
          'type': 'note',
          'timestamp': n.date.millisecondsSinceEpoch,
        });
      }

      for (final a in absences) {
        items.add({
          'id': a.id,
          'title': 'Hiányzás',
          'body': a.subject.name,
          'type': 'absence',
          'timestamp': a.date.millisecondsSinceEpoch,
        });
      }

      items.sort((a, b) =>
          (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      return jsonEncode(items.sublist(0, min(10, items.length)));
    } catch (e) {
      if (kDebugMode) print('WearProvider: buildNotificationsJson error: $e');
      return '[]';
    }
  }

  // ── Sending ──────────────────────────────────────────────────────────────

  Future<void> _sendTimetable(String json) async {
    try {
      await _channel.invokeMethod('sendTimetable', {'json': json});
      _lastTimetableJson = json;
      _lastSync = DateTime.now();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('WearProvider: sendTimetable error: $e');
    }
  }

  Future<void> _sendNotifications(String json) async {
    try {
      await _channel.invokeMethod('sendNotifications', {'json': json});
      _lastNotificationsJson = json;
      _lastSync = DateTime.now();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('WearProvider: sendNotifications error: $e');
    }
  }

  Future<void> _scheduleMorningSync() async {
    try {
      await _channel.invokeMethod('scheduleMorningSync');
    } catch (_) {}
  }

  Future<void> setSyncEnabled(bool enabled) async {
    _syncEnabled = enabled;
    try {
      await _channel.invokeMethod('setSyncEnabled', {'enabled': enabled});
    } catch (_) {}
    notifyListeners();
  }

  // ── Native call handler ──────────────────────────────────────────────────

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onConnectionChanged':
        _watchConnected = call.arguments as bool;
        notifyListeners();
        break;
      case 'onSyncRequested':
        // Re-send last in-memory JSON if available; otherwise fall back to
        // native cached data (WearSyncManager reads phone SharedPreferences).
        if (_lastTimetableJson.isNotEmpty) {
          await _sendTimetable(_lastTimetableJson);
        }
        if (_lastNotificationsJson.isNotEmpty) {
          await _sendNotifications(_lastNotificationsJson);
        }
        if (_lastTimetableJson.isEmpty && _lastNotificationsJson.isEmpty) {
          try {
            await _channel.invokeMethod('sendCachedToWatch');
          } catch (_) {}
        }
        break;
      case 'onPairRequest':
        // Watch sent its pairing code — store and notify UI.
        _pendingPairCode = call.arguments as String?;
        notifyListeners();
        break;
    }
  }

  /// Confirm pairing: validates the code the user typed and sends confirmation
  /// to the watch. Returns true if the code matches.
  Future<bool> confirmPairing(String enteredCode) async {
    if (_pendingPairCode == null || enteredCode != _pendingPairCode) {
      return false;
    }
    try {
      await _channel.invokeMethod(
          'sendPairConfirm', {'code': enteredCode});
    } catch (_) {}
    _pendingPairCode = null;
    notifyListeners();
    return true;
  }

  void dismissPairingRequest() {
    _pendingPairCode = null;
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _hash(String data) =>
      md5.convert(utf8.encode(data)).toString();
}
