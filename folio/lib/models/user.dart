import 'dart:convert';

import 'package:folio_kreta_api/client/api.dart';
import 'package:folio_kreta_api/models/school.dart';
import 'package:folio_kreta_api/models/student.dart';
import 'package:uuid/uuid.dart';

const String demoUserId = 'demo-user-00000000-0000-0000-000000000000';

enum Role { student, parent }

class User {
  late String id;

  String username;
  String password;
  String instituteCode;
  String name;
  Student student;
  Role role;
  String nickname;
  String picture;
  int gradeStreak;

  // ujkreta OAuth tokenek
  String accessToken;
  DateTime accessTokenExpire;
  String refreshToken;

  // Régi KRÉTA IDP mezők.
  // Az ujkreta használatához már nem szükségesek,
  // de kompatibilitás miatt megtartjuk őket.
  String idpApplication;
  String idpRememberBrowser;

  String get displayName => nickname != '' ? nickname : name;

  bool get hasStreak => gradeStreak > 0;

  User({
    String? id,
    required this.name,
    required this.username,
    required this.password,
    required this.instituteCode,
    required this.student,
    required this.role,
    this.nickname = "",
    this.picture = "",
    this.gradeStreak = 0,
    required this.accessToken,
    required this.accessTokenExpire,
    required this.refreshToken,
    this.idpApplication = "",
    this.idpRememberBrowser = "",
  }) {
    if (id != null) {
      this.id = id;
    } else {
      this.id = const Uuid().v4();
    }
  }

  factory User.fromMap(Map map) {
    return User(
      id: map["id"],
      instituteCode: map["institute_code"] ?? "",
      username: map["username"] ?? "",
      password: map["password"] ?? "",
      name: (map["name"] ?? "Ismeretlen Diák").toString().trim(),
      student: map["student"] != null && map["student"] != 'null'
          ? Student.fromJson(jsonDecode(map["student"]))
          : Student(
              id: const Uuid().v4(),
              name: 'Ismeretlen Diák',
              school: School(
                instituteCode: '',
                name: '',
                city: '',
              ),
              birth: DateTime.now(),
              yearId: '1',
              parents: [],
              gradeDelay: 0,
            ),
      role: Role.values[
          (map["role"] ?? Role.student.index).clamp(0, Role.values.length - 1)],
      nickname: map["nickname"] ?? "",
      picture: map["picture"] ?? "",
      gradeStreak: map["grade_streak"] ?? 0,
      accessToken: map["access_token"] ?? "",
      accessTokenExpire: DateTime.parse(
        map["access_token_expire"] != null &&
                map["access_token_expire"].toString().isNotEmpty
            ? map["access_token_expire"].toString()
            : DateTime.now().toIso8601String(),
      ),
      refreshToken: map["refresh_token"] ?? "",
      idpApplication: map["idp_application"] ?? "",
      idpRememberBrowser: map["idp_remember_browser"] ?? "",
    );
  }

  Map<String, Object?> toMap() {
    return {
      "id": id,
      "username": username,
      "password": password,
      "institute_code": instituteCode,
      "name": name,
      "student": jsonEncode(student.json),
      "role": role.index,
      "nickname": nickname,
      "picture": picture,
      "grade_streak": gradeStreak,
      "access_token": accessToken,
      "access_token_expire": accessTokenExpire.toIso8601String(),
      "refresh_token": refreshToken,
      "idp_application": idpApplication,
      "idp_remember_browser": idpRememberBrowser,
    };
  }

  @override
  String toString() => jsonEncode(toMap());

  static User demo() {
    return User(
      id: demoUserId,
      name: 'Demo Diák',
      username: 'demo',
      password: '',
      instituteCode: 'demo',
      student: Student(
        id: demoUserId,
        name: 'Demo Diák',
        school: School(
          instituteCode: 'demo',
          name: 'Demo Iskola',
          city: 'Budapest',
        ),
        birth: DateTime(2005, 9, 1),
        yearId: '1',
        parents: [],
        gradeDelay: 0,
      ),
      role: Role.student,
      nickname: 'Demo',
      accessToken: 'demo',
      accessTokenExpire: DateTime.now().add(
        const Duration(days: 365),
      ),
      refreshToken: 'demo',
    );
  }

  bool get isDemo => id == demoUserId;

  /// ujkreta password grant.
  ///
  /// A szerver:
  /// POST /connect/token
  ///
  /// Elvárt mezők:
  /// grant_type=password
  /// username=...
  /// password=...
  static Map<String, String> loginBody({
    required String username,
    required String password,
    String instituteCode = "",
  }) {
    return {
      "grant_type": "password",
      "username": username,
      "password": password,
    };
  }

  /// ujkreta refresh token grant.
  static Map<String, String> refreshBody({
    required String refreshToken,
    String instituteCode = "",
  }) {
    return {
      "grant_type": "refresh_token",
      "refresh_token": refreshToken,
    };
  }

  /// Az ujkreta jelenlegi működéséhez logout nem szükséges.
  ///
  /// A metódust kompatibilitás miatt megtartjuk.
  static Map<String, String> logoutBody({
    required String refreshToken,
  }) {
    return {
      "refresh_token": refreshToken,
    };
  }
}