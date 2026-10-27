import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  LocalStore(this._preferences);

  final SharedPreferences _preferences;

  static const _homeKey = 'cached_home_v1';
  static const _profileKey = 'cached_profile_v1';
  static const _supportKey = 'cached_support_v1';
  static const _inquiriesKey = 'cached_inquiries_v1';
  static const _studentTokenKey = 'student_token_v1';
  static const _studentCodeKey = 'student_code_v1';
  static const _lastSyncKey = 'last_sync_v1';

  static Future<LocalStore> create() async {
    return LocalStore(await SharedPreferences.getInstance());
  }

  Map<String, dynamic>? readMap(String key) {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  List<dynamic> readList(String key) {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return List<dynamic>.from(jsonDecode(raw) as List);
    } catch (_) {
      return const [];
    }
  }

  Future<void> writeJson(String key, Object value) =>
      _preferences.setString(key, jsonEncode(value));

  Map<String, dynamic>? get cachedHome => readMap(_homeKey);
  Map<String, dynamic>? get cachedProfile => readMap(_profileKey);
  List<dynamic> get cachedSupport => readList(_supportKey);
  List<dynamic> get cachedInquiries => readList(_inquiriesKey);
  String get token => _preferences.getString(_studentTokenKey) ?? '';
  String get studentCode => _preferences.getString(_studentCodeKey) ?? '';
  DateTime? get lastSync =>
      DateTime.tryParse(_preferences.getString(_lastSyncKey) ?? '');

  Future<void> saveHome(Map<String, dynamic> value) =>
      writeJson(_homeKey, value);
  Future<void> saveProfile(Map<String, dynamic> value) =>
      writeJson(_profileKey, value);
  Future<void> saveSupport(List<dynamic> value) =>
      writeJson(_supportKey, value);
  Future<void> saveInquiries(List<dynamic> value) =>
      writeJson(_inquiriesKey, value);
  Future<void> saveToken(String value) =>
      _preferences.setString(_studentTokenKey, value);
  Future<void> saveStudentCode(String value) =>
      _preferences.setString(_studentCodeKey, value);
  Future<void> saveLastSync(DateTime value) =>
      _preferences.setString(_lastSyncKey, value.toIso8601String());

  Future<void> saveExamDraft(int examId, Map<String, dynamic> answers) =>
      writeJson('exam_draft_$examId', answers);
  Map<String, dynamic> examDraft(int examId) =>
      readMap('exam_draft_$examId') ?? <String, dynamic>{};
  Future<void> clearExamDraft(int examId) =>
      _preferences.remove('exam_draft_$examId');

  Future<void> saveExamReview(int examId, Map<String, dynamic> review) =>
      writeJson('exam_review_$examId', review);
  Map<String, dynamic>? examReview(int examId) =>
      readMap('exam_review_$examId');

  Future<void> saveExamCertificate(
    int examId,
    Map<String, dynamic> certificate,
  ) => writeJson('exam_certificate_$examId', certificate);
  Map<String, dynamic>? examCertificate(int examId) =>
      readMap('exam_certificate_$examId');

  Future<void> clearStudent() async {
    await _preferences.remove(_studentTokenKey);
    await _preferences.remove(_studentCodeKey);
    await _preferences.remove(_profileKey);
    await _preferences.remove(_supportKey);
    final privateExamKeys = _preferences.getKeys().where(
      (key) =>
          key.startsWith('exam_draft_') ||
          key.startsWith('exam_review_') ||
          key.startsWith('exam_certificate_'),
    );
    for (final key in privateExamKeys) {
      await _preferences.remove(key);
    }
  }
}
