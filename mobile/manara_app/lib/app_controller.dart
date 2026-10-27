import 'package:flutter/foundation.dart';

import 'services/api_client.dart';
import 'services/book_storage.dart';
import 'services/local_store.dart';

class AppController extends ChangeNotifier {
  AppController._(this.store, this.api, this.books);

  final LocalStore store;
  final ApiClient api;
  final BookStorage books;

  Map<String, dynamic>? home;
  Map<String, dynamic>? profile;
  List<dynamic> tickets = const [];
  List<dynamic> inquiries = const [];
  DateTime? lastSync;
  bool syncing = false;
  bool online = false;
  String? notice;

  bool get loggedIn => api.token.isNotEmpty && profile != null;
  Map<String, dynamic>? get student => profile?['student'] is Map
      ? Map<String, dynamic>.from(profile!['student'] as Map)
      : null;
  List<dynamic> get assignments => profile?['assignments'] is List
      ? List<dynamic>.from(profile!['assignments'] as List)
      : const [];

  static Future<AppController> create() async {
    final store = await LocalStore.create();
    final controller = AppController._(
      store,
      ApiClient(token: store.token),
      const BookStorage(),
    );
    controller.home = store.cachedHome;
    controller.profile = store.cachedProfile;
    controller.tickets = store.cachedSupport;
    controller.inquiries = store.cachedInquiries;
    controller.lastSync = store.lastSync;
    return controller;
  }

  Future<void> initialize() async {
    notifyListeners();
    await syncAll(silent: home != null);
  }

  Future<void> syncAll({bool silent = false}) async {
    if (syncing) return;
    syncing = true;
    if (!silent) notice = null;
    notifyListeners();
    var anySuccess = false;
    try {
      final freshHome = await api.publicHome();
      home = freshHome;
      await store.saveHome(freshHome);
      anySuccess = true;
      await _refreshInquiries();
      if (api.token.isNotEmpty) {
        final freshProfile = await api.profile();
        profile = freshProfile;
        await store.saveProfile(freshProfile);
        final freshTickets = await api.support();
        tickets = freshTickets;
        await store.saveSupport(freshTickets);
      }
      online = true;
      lastSync = DateTime.now();
      await store.saveLastSync(lastSync!);
      notice = null;
    } on ApiException catch (error) {
      online = anySuccess;
      notice = error.message;
      if (error.statusCode == 401) {
        await logout(localOnly: true);
        notice = 'انتهت جلسة الدخول. أدخل معرّفك مرة أخرى عند توفر الإنترنت.';
      }
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<String?> login(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return 'اكتب معرّف الطالب';
    syncing = true;
    notice = null;
    notifyListeners();
    try {
      final result = await api.login(code);
      final status = result['status']?.toString() ?? '';
      if (status != 'approved') {
        return status == 'pending'
            ? 'طلبك ما زال بانتظار موافقة الشيخ.'
            : 'لم تتم الموافقة على هذا الطلب.';
      }
      final token = result['studentToken']?.toString() ?? '';
      if (token.isEmpty) return 'لم يصل رمز جلسة صالح من الخادم.';
      api.token = token;
      await store.saveToken(token);
      await store.saveStudentCode(code);
      final cached = Map<String, dynamic>.from(result)..remove('studentToken');
      profile = cached;
      await store.saveProfile(cached);
      online = true;
      lastSync = DateTime.now();
      await store.saveLastSync(lastSync!);
      return null;
    } on ApiException catch (error) {
      online = false;
      return error.message;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<String?> updateStudentProfile({
    required String name,
    required String gender,
    required Map<String, dynamic> details,
  }) async {
    syncing = true;
    notice = null;
    notifyListeners();
    try {
      final fresh = await api.updateStudentProfile(
        name: name,
        gender: gender,
        profile: details,
      );
      profile = fresh;
      await store.saveProfile(fresh);
      online = true;
      lastSync = DateTime.now();
      await store.saveLastSync(lastSync!);
      return null;
    } on ApiException catch (error) {
      online = false;
      notice = error.message;
      return error.message;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> logout({bool localOnly = false}) async {
    if (!localOnly && api.token.isNotEmpty) {
      try {
        await api.studentLogout();
      } on ApiException {
        // Local logout must always complete, even if the device is offline.
      }
    }
    api.token = '';
    profile = null;
    tickets = const [];
    await store.clearStudent();
    notifyListeners();
  }

  Future<String?> sendSupport(String subject, String message) async {
    try {
      await api.sendSupport(subject, message);
      tickets = await api.support();
      await store.saveSupport(tickets);
      online = true;
      notifyListeners();
      return null;
    } on ApiException catch (error) {
      online = false;
      notifyListeners();
      return error.message;
    }
  }

  Future<void> _refreshInquiries() async {
    if (inquiries.isEmpty) return;
    final refreshed = <dynamic>[];
    for (final raw in inquiries) {
      final cached = Map<String, dynamic>.from(raw as Map);
      final code =
          cached['public_code']?.toString() ?? cached['code']?.toString();
      if (code == null || code.isEmpty) {
        refreshed.add(cached);
        continue;
      }
      try {
        final fresh = await api.inquiry(code);
        refreshed.add({...cached, ...fresh, 'public_code': code});
      } on ApiException {
        refreshed.add(cached);
      }
    }
    inquiries = refreshed;
    await store.saveInquiries(inquiries);
  }

  Future<String?> sendInquiry({
    required int topicId,
    required String topicName,
    required String gender,
    required String question,
  }) async {
    try {
      final result = await api.sendInquiry(
        topicId: topicId,
        gender: gender,
        question: question,
      );
      final code = result['code']?.toString() ?? '';
      inquiries = [
        {
          ...result,
          'public_code': code,
          'topic_name': topicName,
          'gender': gender,
          'question': question,
          'status': 'new',
        },
        ...inquiries,
      ];
      await store.saveInquiries(inquiries);
      online = true;
      notifyListeners();
      return null;
    } on ApiException catch (error) {
      online = false;
      notifyListeners();
      return error.message;
    }
  }

  Future<Map<String, dynamic>> startExam(int id) => api.startExam(id);
  Future<Map<String, dynamic>> submitExam(
    int id,
    Map<String, dynamic> answers,
  ) => api.submitExam(id, answers);
  Future<Map<String, dynamic>> reviewExam(int id) async {
    try {
      final review = await api.reviewExam(id);
      await store.saveExamReview(id, review);
      return review;
    } on ApiException {
      final cached = store.examReview(id);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> examCertificate(int id) async {
    try {
      final certificate = await api.examCertificate(id);
      await store.saveExamCertificate(id, certificate);
      return certificate;
    } on ApiException {
      final cached = store.examCertificate(id);
      if (cached != null) return cached;
      rethrow;
    }
  }
}
