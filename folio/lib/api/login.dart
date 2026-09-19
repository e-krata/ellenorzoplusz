// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:folio/api/providers/database_provider.dart';
import 'package:folio/api/providers/user_provider.dart';
import 'package:folio/models/user.dart';
import 'package:folio_kreta_api/client/api.dart';
import 'package:folio_kreta_api/client/client.dart';
import 'package:folio_kreta_api/models/student.dart';
import 'package:folio_kreta_api/models/week.dart';
import 'package:folio_kreta_api/providers/absence_provider.dart';
import 'package:folio_kreta_api/providers/event_provider.dart';
import 'package:folio_kreta_api/providers/exam_provider.dart';
import 'package:folio_kreta_api/providers/grade_provider.dart';
import 'package:folio_kreta_api/providers/homework_provider.dart';
import 'package:folio_kreta_api/providers/note_provider.dart';
import 'package:folio_kreta_api/providers/timetable_provider.dart';
import 'package:provider/provider.dart';

enum LoginState {
  missingFields,
  invalidGrant,
  failed,
  normal,
  inProgress,
  success,
}

Future<LoginState> newLoginAPI({
  required String username,
  required String password,
  BuildContext? context,
  String instituteCode = "ujkreta",
  void Function(User)? onLogin,
  void Function()? onSuccess,
}) async {
  if (username.trim().isEmpty ||
      password.isEmpty) {
    return LoginState.missingFields;
  }

  if (context == null) {
    return LoginState.failed;
  }

  final client = Provider.of<KretaClient>(
    context,
    listen: false,
  );

  final body = User.loginBody(
    username: username.trim(),
    password: password,
    instituteCode: instituteCode,
  );

  final encodedBody =
      Uri(queryParameters: body).query;

  final result = await client.postAPI(
    KretaAPI.login,
    headers: {
      "content-type":
          "application/x-www-form-urlencoded; charset=UTF-8",
      "accept": "application/json",
    },
    autoHeader: true,
    body: encodedBody,
  );

  if (result is! Map) {
    return LoginState.failed;
  }

  if (result["error"] != null) {
    if (kDebugMode) {
      print(
        "ujkreta login error: "
        "${result["error"]}",
      );

      print(
        "ujkreta login response: $result",
      );
    }

    if (result["error"] == "invalid_grant") {
      return LoginState.invalidGrant;
    }

    return LoginState.failed;
  }

  final accessToken = result["access_token"];
  final refreshToken = result["refresh_token"];

  if (accessToken is! String ||
      accessToken.isEmpty ||
      refreshToken is! String ||
      refreshToken.isEmpty) {
    print(
      "ujkreta: hiányzó token mezők: $result",
    );

    return LoginState.failed;
  }

  try {
    client.accessToken = accessToken;
    client.refreshToken = refreshToken;

    final expiresIn =
        result["expires_in"] is num
            ? (result["expires_in"] as num).toInt()
            : 43200;

    final studentJson = await client.getAPI(
      KretaAPI.student(instituteCode),
      headers: {
        "accept": "application/json",
      },
    );

    if (studentJson is! Map) {
      print(
        "ujkreta: TanuloAdatlap válasz érvénytelen",
      );

      return LoginState.failed;
    }

    final student =
        Student.fromJson(studentJson);

    final user = User(
      username: username.trim(),
      password: password,
      instituteCode: instituteCode,
      name: student.name,
      student: student,
      role: Role.student,
      accessToken: accessToken,
      accessTokenExpire:
          DateTime.now().add(
        Duration(
          seconds: expiresIn > 30
              ? expiresIn - 30
              : expiresIn,
        ),
      ),
      refreshToken: refreshToken,
    );

    user.idpApplication = "";
    user.idpRememberBrowser = "";

    onLogin?.call(user);

    final database =
        Provider.of<DatabaseProvider>(
      context,
      listen: false,
    );

    final userProvider =
        Provider.of<UserProvider>(
      context,
      listen: false,
    );

    await database.store.storeUser(user);

    userProvider.addUser(user);
    userProvider.setUser(user.id);

    // Az ujkreta nem használja a hivatalos
    // KRÉTA push notification szolgáltatást.

    try {
      await Future.wait([
        Provider.of<GradeProvider>(
          context,
          listen: false,
        ).fetch(),

        Provider.of<TimetableProvider>(
          context,
          listen: false,
        ).fetch(
          week: Week.current(),
        ),

        Provider.of<ExamProvider>(
          context,
          listen: false,
        ).fetch(),

        Provider.of<HomeworkProvider>(
          context,
          listen: false,
        ).fetch(),

        Provider.of<NoteProvider>(
          context,
          listen: false,
        ).fetch(),

        Provider.of<EventProvider>(
          context,
          listen: false,
        ).fetch(),

        Provider.of<AbsenceProvider>(
          context,
          listen: false,
        ).fetch(),
      ]);
    } catch (error) {
      print(
        "WARNING: ujkreta adatok betöltése sikertelen: "
        "$error",
      );
    }

    onSuccess?.call();

    return LoginState.success;
  } catch (error, stack) {
    print(
      "ERROR: ujkreta login: $error",
    );

    if (kDebugMode) {
      print(stack);
    }

    return LoginState.failed;
  }
}