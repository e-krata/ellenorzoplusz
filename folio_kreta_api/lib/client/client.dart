// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:folio/api/providers/database_provider.dart';
import 'package:folio/api/providers/status_provider.dart';
import 'package:folio/api/providers/user_provider.dart';
import 'package:folio/models/settings.dart';
import 'package:folio/models/user.dart';
import 'package:folio_kreta_api/client/api.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class KretaClient {
  String? accessToken;
  String? refreshToken;
  String? idToken;
  String? userAgent;

  // Régi Folio-kompatibilitás miatt marad.
  // ujkreta nem használja.
  String? idpApplicationCookie;

  late http.Client client;

  late final SettingsProvider _settings;
  late final UserProvider _user;
  late final DatabaseProvider _database;
  late final StatusProvider _status;

  KretaClient({
    this.accessToken,
    required SettingsProvider settings,
    required UserProvider user,
    required DatabaseProvider database,
    required StatusProvider status,
  })  : _settings = settings,
        _user = user,
        _database = database,
        _status = status,
        userAgent = settings.config.userAgent {
    final ioclient = HttpClient();

    ioclient.badCertificateCallback = _checkCerts;

    client = IOClient(ioclient);
  }

  bool _checkCerts(
    X509Certificate cert,
    String host,
    int port,
  ) {
    return _settings.developerMode;
  }

  Map<String, String> _headers({
    Map<String, String>? headers,
    bool withAuthorization = true,
    bool jsonContentType = false,
  }) {
    final result = <String, String>{
      ...?headers,
    };

    if (withAuthorization) {
      accessToken ??= _user.user?.accessToken;

      if (!result.containsKey("authorization") &&
          accessToken != null &&
          accessToken!.isNotEmpty) {
        result["authorization"] = "Bearer $accessToken";
      }
    }

    if (!result.containsKey("accept")) {
      result["accept"] = "application/json";
    }

    if (userAgent != null &&
        userAgent!.isNotEmpty &&
        !result.containsKey("user-agent")) {
      result["user-agent"] = userAgent!;
    }

    if (jsonContentType &&
        !result.containsKey("content-type")) {
      result["content-type"] = "application/json";
    }

    // NINCS apiKey.
    // NINCS idp.application cookie.
    //
    // Az ujkreta ezek nélkül használható.

    return result;
  }

  dynamic _decode(
    http.Response response, {
    bool json = true,
    bool raw = false,
  }) {
    if (raw) {
      return response.bodyBytes;
    }

    if (!json) {
      return response.body;
    }

    if (response.body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  Future<dynamic> getAPI(
    String url, {
    Map<String, String>? headers,
    bool autoHeader = true,
    bool json = true,
    bool rawResponse = false,
  }) async {
    if (rawResponse) {
      json = false;
    }

    try {
      final headerMap = autoHeader
          ? _headers(headers: headers)
          : <String, String>{
              ...?headers,
            };

      final res = await client.get(
        Uri.parse(url),
        headers: headerMap,
      );

      _status.triggerRequest(res);

      if (res.statusCode < 200 ||
          res.statusCode >= 300) {
        print(
          "ERROR: GET $url -> "
          "${res.statusCode}: ${res.body}",
        );

        return null;
      }

      return _decode(
        res,
        json: json,
        raw: rawResponse,
      );
    } on http.ClientException catch (error) {
      print(
        "ERROR: KretaClient.getAPI ($url): "
        "${error.message}",
      );
    } catch (error) {
      print(
        "ERROR: KretaClient.getAPI ($url) "
        "${error.runtimeType}: $error",
      );
    }

    return null;
  }

  Future<dynamic> postAPI(
    String url, {
    Map<String, String>? headers,
    bool autoHeader = true,
    bool json = true,
    Object? body,
  }) async {
    try {
      final isTokenEndpoint =
          url == KretaAPI.login;

      final headerMap = autoHeader
          ? _headers(
              headers: headers,
              withAuthorization: !isTokenEndpoint,
              jsonContentType: body is! String,
            )
          : <String, String>{
              ...?headers,
            };

      final res = await client.post(
        Uri.parse(url),
        headers: headerMap,
        body: body,
      );

      _status.triggerRequest(res);

      if (res.statusCode < 200 ||
          res.statusCode >= 300) {
        print(
          "ERROR: POST $url -> "
          "${res.statusCode}: ${res.body}",
        );
      }

      return _decode(
        res,
        json: json,
      );
    } on http.ClientException catch (error) {
      print(
        "ERROR: KretaClient.postAPI ($url): "
        "${error.message}",
      );
    } catch (error) {
      print(
        "ERROR: KretaClient.postAPI ($url) "
        "${error.runtimeType}: $error",
      );
    }

    return null;
  }

  Future<dynamic> deleteAPI(
    String url, {
    Map<String, String>? headers,
    bool autoHeader = true,
  }) async {
    try {
      final headerMap = autoHeader
          ? _headers(headers: headers)
          : <String, String>{
              ...?headers,
            };

      final res = await client.delete(
        Uri.parse(url),
        headers: headerMap,
      );

      _status.triggerRequest(res);

      return res.statusCode;
    } on http.ClientException catch (error) {
      print(
        "ERROR: KretaClient.deleteAPI ($url): "
        "${error.message}",
      );
    } catch (error) {
      print(
        "ERROR: KretaClient.deleteAPI ($url) "
        "${error.runtimeType}: $error",
      );
    }

    return null;
  }

  Future<dynamic> postFormAPI(
    String url, {
    Map<String, String>? headers,
    bool autoHeader = true,
    Map<String, String>? formFields,
  }) async {
    try {
      final headerMap = autoHeader
          ? _headers(
              headers: headers,
              withAuthorization: url != KretaAPI.login,
            )
          : <String, String>{
              ...?headers,
            };

      headerMap["content-type"] =
          "application/x-www-form-urlencoded; charset=UTF-8";

      final encoded = (formFields ?? {}).entries
          .map(
            (e) =>
                "${Uri.encodeQueryComponent(e.key)}="
                "${Uri.encodeQueryComponent(e.value)}",
          )
          .join("&");

      final res = await client.post(
        Uri.parse(url),
        headers: headerMap,
        body: encoded,
      );

      _status.triggerRequest(res);

      if (res.statusCode < 200 ||
          res.statusCode >= 300) {
        print(
          "ERROR: FORM POST $url -> "
          "${res.statusCode}: ${res.body}",
        );
      }

      return res.statusCode;
    } on http.ClientException catch (error) {
      print(
        "ERROR: KretaClient.postFormAPI ($url): "
        "${error.message}",
      );
    } catch (error) {
      print(
        "ERROR: KretaClient.postFormAPI ($url) "
        "${error.runtimeType}: $error",
      );
    }

    return null;
  }

  Future<dynamic> sendFilesAPI(
    String url, {
    Map<String, String>? headers,
    bool autoHeader = true,
    Map<String, String>? body,
  }) async {
    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse(url),
      );

      if (autoHeader) {
        request.headers.addAll(
          _headers(headers: headers),
        );
      } else if (headers != null) {
        request.headers.addAll(headers);
      }

      request.fields.addAll(body ?? {});

      final res = await request.send();

      print(
        "POST multipart $url -> ${res.statusCode}",
      );

      return res.statusCode;
    } on http.ClientException catch (error) {
      print(
        "ERROR: KretaClient.sendFilesAPI ($url): "
        "${error.message}",
      );
    } catch (error) {
      print(
        "ERROR: KretaClient.sendFilesAPI ($url) "
        "${error.runtimeType}: $error",
      );
    }

    return null;
  }

  Future<String?> refreshLogin() async {
    final loginUser = _user.user;

    if (loginUser == null) {
      return null;
    }

    refreshToken ??= loginUser.refreshToken;

    if (!DateTime.now().isAfter(
      loginUser.accessTokenExpire,
    )) {
      return 'success';
    }

    final token = refreshToken;

    if (token == null || token.isEmpty) {
      return null;
    }

    final body = Uri(
      queryParameters: User.refreshBody(
        refreshToken: token,
        instituteCode: loginUser.instituteCode,
      ),
    ).query;

    final result = await postAPI(
      KretaAPI.login,
      headers: {
        "content-type":
            "application/x-www-form-urlencoded; charset=UTF-8",
        "accept": "application/json",
      },
      body: body,
    );

    if (result is! Map) {
      return null;
    }

    if (result["error"] != null) {
      if (result["error"] == "invalid_grant") {
        return "refresh_token_expired";
      }

      return null;
    }

    final newAccessToken = result["access_token"];

    if (newAccessToken is String &&
        newAccessToken.isNotEmpty) {
      accessToken = newAccessToken;
      loginUser.accessToken = newAccessToken;

      final expiresIn =
          result["expires_in"] is num
              ? (result["expires_in"] as num).toInt()
              : 43200;

      loginUser.accessTokenExpire =
          DateTime.now().add(
        Duration(
          seconds: expiresIn > 30
              ? expiresIn - 30
              : expiresIn,
        ),
      );
    }

    final newRefreshToken =
        result["refresh_token"];

    if (newRefreshToken is String &&
        newRefreshToken.isNotEmpty) {
      refreshToken = newRefreshToken;
      loginUser.refreshToken = newRefreshToken;
    }

    final newIdToken = result["id_token"];

    if (newIdToken is String) {
      idToken = newIdToken;
    }

    await _database.store.storeUser(loginUser);

    _user.refresh();

    return 'success';
  }

  Future<void> logout() async {
    final loginUser = _user.user;

    final token =
        refreshToken ?? loginUser?.refreshToken;

    if (token == null || token.isEmpty) {
      return;
    }

    await postAPI(
      KretaAPI.logout,
      headers: {
        "content-type":
            "application/x-www-form-urlencoded; charset=UTF-8",
      },
      body: Uri(
        queryParameters: User.logoutBody(
          refreshToken: token,
        ),
      ).query,
      json: false,
    );
  }
}