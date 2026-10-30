import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../app_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({this.token = ''});

  String token;

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}$path');
    final headers = <String, String>{
      'apikey': AppConfig.publishableKey,
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if ((bearerToken ?? token).isNotEmpty)
        'Authorization': 'Bearer ${bearerToken ?? token}',
    };

    try {
      late http.Response response;
      final encoded = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 18));
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 18));
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 18));
        default:
          response = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 18));
      }
      final dynamic decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map
            ? (decoded['error']?.toString() ?? 'تعذر إكمال الطلب')
            : 'تعذر إكمال الطلب';
        throw ApiException(message, statusCode: response.statusCode);
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'انتهت مهلة الاتصال. تحقق من الإنترنت وحاول مجددًا.',
      );
    } on FormatException {
      throw const ApiException('وصلت استجابة غير صالحة من الخادم.');
    } catch (_) {
      throw const ApiException(
        'لا يوجد اتصال بالخادم الآن. ستبقى البيانات المحفوظة متاحة.',
      );
    }
  }

  Future<Map<String, dynamic>> publicHome() async =>
      Map<String, dynamic>.from(await _request('/api/public/home') as Map);

  Future<Map<String, dynamic>> login(String code) async =>
      Map<String, dynamic>.from(
        await _request(
              '/api/student/login',
              method: 'POST',
              body: {'code': code},
            )
            as Map,
      );

  Future<Map<String, dynamic>> profile() async =>
      Map<String, dynamic>.from(await _request('/api/student/profile') as Map);

  Future<Map<String, dynamic>> updateStudentProfile({
    required String name,
    required String gender,
    required Map<String, dynamic> profile,
  }) async => Map<String, dynamic>.from(
    await _request(
          '/api/student/profile',
          method: 'PUT',
          body: {'name': name, 'gender': gender, 'profile': profile},
        )
        as Map,
  );

  Future<void> studentLogout() async {
    await _request('/api/student/logout', method: 'POST', body: const {});
  }

  Future<List<dynamic>> support() async =>
      List<dynamic>.from(await _request('/api/student/support') as List);

  Future<void> sendSupport(String subject, String message) async {
    await _request(
      '/api/student/support',
      method: 'POST',
      body: {'subject': subject, 'message': message},
    );
  }

  Future<Map<String, dynamic>> startExam(int examId) async =>
      Map<String, dynamic>.from(
        await _request(
              '/api/student/exams/$examId/start',
              method: 'POST',
              body: {'pledge': true},
            )
            as Map,
      );

  Future<Map<String, dynamic>> submitExam(
    int examId,
    Map<String, dynamic> answers,
  ) async => Map<String, dynamic>.from(
    await _request(
          '/api/student/exams/$examId/submit',
          method: 'POST',
          body: {'answers': answers},
        )
        as Map,
  );

  Future<Map<String, dynamic>> reviewExam(int examId) async =>
      Map<String, dynamic>.from(
        await _request('/api/student/exams/$examId/review') as Map,
      );

  Future<Map<String, dynamic>> examCertificate(int examId) async =>
      Map<String, dynamic>.from(
        await _request('/api/student/exams/$examId/certificate') as Map,
      );

  Future<String> bookUrl(int bookId) async {
    final result = Map<String, dynamic>.from(
      await _request('/api/public/book/$bookId') as Map,
    );
    return result['url']?.toString() ?? '';
  }

  Future<Map<String, dynamic>> sendInquiry({
    required int topicId,
    required String gender,
    required String question,
  }) async => Map<String, dynamic>.from(
    await _request(
          '/api/public/inquiries',
          method: 'POST',
          body: {'topicId': topicId, 'gender': gender, 'question': question},
        )
        as Map,
  );

  Future<Map<String, dynamic>> inquiry(String code) async =>
      Map<String, dynamic>.from(
        await _request('/api/public/inquiries/${Uri.encodeComponent(code)}')
            as Map,
      );

  Future<Map<String, dynamic>> adminLogin(
    String username,
    String password,
  ) async => Map<String, dynamic>.from(
    await _request(
          '/api/admin/login',
          method: 'POST',
          body: {'username': username, 'password': password},
          bearerToken: '',
        )
        as Map,
  );

  Future<Map<String, dynamic>> adminDashboard(String adminToken) async =>
      Map<String, dynamic>.from(
        await _request('/api/admin/dashboard', bearerToken: adminToken) as Map,
      );

  Future<List<dynamic>> adminInquiries(String adminToken) async =>
      List<dynamic>.from(
        await _request('/api/admin/inquiries', bearerToken: adminToken) as List,
      );

  Future<List<dynamic>> adminSupport(String adminToken) async =>
      List<dynamic>.from(
        await _request('/api/admin/support', bearerToken: adminToken) as List,
      );

  Future<Map<String, dynamic>> adminStudents(String adminToken) async =>
      Map<String, dynamic>.from(
        await _request('/api/admin/students', bearerToken: adminToken) as Map,
      );

  Future<void> updateStudentStatus({
    required String adminToken,
    required int id,
    required String status,
    String reviewNote = '',
  }) async {
    await _request(
      '/api/admin/students/$id/status',
      method: 'PUT',
      bearerToken: adminToken,
      body: {'status': status, 'reviewNote': reviewNote},
    );
  }

  Future<void> updateStudent({
    required String adminToken,
    required int id,
    required Map<String, dynamic> value,
  }) async {
    await _request(
      '/api/admin/students/$id',
      method: 'PUT',
      bearerToken: adminToken,
      body: value,
    );
  }

  Future<void> deleteStudent(String adminToken, int id) async {
    await _request(
      '/api/admin/students/$id',
      method: 'DELETE',
      bearerToken: adminToken,
    );
  }

  Future<List<dynamic>> adminExams(String adminToken) async =>
      List<dynamic>.from(
        await _request('/api/admin/exams', bearerToken: adminToken) as List,
      );

  Future<Map<String, dynamic>> adminExam(String adminToken, int id) async =>
      Map<String, dynamic>.from(
        await _request('/api/admin/exams/$id', bearerToken: adminToken) as Map,
      );

  Future<int> createExam(String adminToken, Map<String, dynamic> value) async {
    final result = Map<String, dynamic>.from(
      await _request(
            '/api/admin/exams',
            method: 'POST',
            bearerToken: adminToken,
            body: value,
          )
          as Map,
    );
    return int.parse(result['id'].toString());
  }

  Future<void> updateExam(
    String adminToken,
    int id,
    Map<String, dynamic> value,
  ) async {
    await _request(
      '/api/admin/exams/$id',
      method: 'PUT',
      bearerToken: adminToken,
      body: value,
    );
  }

  Future<void> deleteExam(String adminToken, int id) async {
    await _request(
      '/api/admin/exams/$id',
      method: 'DELETE',
      bearerToken: adminToken,
    );
  }

  Future<void> createQuestion(
    String adminToken,
    int examId,
    Map<String, dynamic> value,
  ) async {
    await _request(
      '/api/admin/exams/$examId/questions',
      method: 'POST',
      bearerToken: adminToken,
      body: value,
    );
  }

  Future<void> updateQuestion(
    String adminToken,
    int questionId,
    Map<String, dynamic> value,
  ) async {
    await _request(
      '/api/admin/questions/$questionId',
      method: 'PUT',
      bearerToken: adminToken,
      body: value,
    );
  }

  Future<void> deleteQuestion(String adminToken, int questionId) async {
    await _request(
      '/api/admin/questions/$questionId',
      method: 'DELETE',
      bearerToken: adminToken,
    );
  }

  Future<void> assignStudents(
    String adminToken,
    int examId,
    List<int> studentIds,
  ) async {
    await _request(
      '/api/admin/exams/$examId/students',
      method: 'POST',
      bearerToken: adminToken,
      body: {'studentIds': studentIds},
    );
  }

  Future<void> deleteAssignment(String adminToken, int assignmentId) async {
    await _request(
      '/api/admin/assignments/$assignmentId',
      method: 'DELETE',
      bearerToken: adminToken,
    );
  }

  Future<List<dynamic>> adminExamResults(String adminToken, int examId) async =>
      List<dynamic>.from(
        await _request(
              '/api/admin/exams/$examId/results',
              bearerToken: adminToken,
            )
            as List,
      );

  Future<void> resetSheikhTest(String adminToken, int assignmentId) async {
    await _request(
      '/api/admin/test-assignment/reset',
      method: 'POST',
      bearerToken: adminToken,
      body: {'assignmentId': assignmentId},
    );
  }

  Future<Map<String, dynamic>> adminQuestionBank(String adminToken) async =>
      Map<String, dynamic>.from(
        await _request('/api/admin/question-bank', bearerToken: adminToken)
            as Map,
      );

  Future<void> createExamFromBank(
    String adminToken,
    Map<String, dynamic> value,
  ) async {
    await _request(
      '/api/admin/exams/from-bank',
      method: 'POST',
      bearerToken: adminToken,
      body: value,
    );
  }

  Future<List<dynamic>> adminBooks(String adminToken) async =>
      List<dynamic>.from(
        await _request('/api/admin/books', bearerToken: adminToken) as List,
      );

  Future<List<dynamic>> adminBookRoadmaps(String adminToken) async =>
      List<dynamic>.from(
        await _request('/api/admin/book-roadmaps', bearerToken: adminToken)
            as List,
      );

  Future<Map<String, dynamic>> adminBookRoadmap(
    String adminToken,
    int bookId,
  ) async => Map<String, dynamic>.from(
    await _request(
          '/api/admin/books/$bookId/roadmap',
          bearerToken: adminToken,
        )
        as Map,
  );

  Future<void> uploadBook({
    required String adminToken,
    required String title,
    required String description,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/admin/books').replace(
      queryParameters: {
        'title': title,
        'description': description,
        'name': fileName,
      },
    );
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'apikey': AppConfig.publishableKey,
              'Authorization': 'Bearer $adminToken',
              'Accept': 'application/json',
              'Content-Type': 'application/pdf',
            },
            body: bytes,
          )
          .timeout(const Duration(minutes: 2));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final decoded = response.body.isEmpty
            ? const <String, dynamic>{}
            : jsonDecode(utf8.decode(response.bodyBytes));
        throw ApiException(
          decoded is Map
              ? decoded['error']?.toString() ?? 'تعذر رفع الكتاب'
              : 'تعذر رفع الكتاب',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('استغرق رفع الكتاب وقتًا طويلًا. حاول مجددًا.');
    } catch (_) {
      throw const ApiException('تعذر الاتصال بالخادم لرفع الكتاب.');
    }
  }

  Future<void> deleteBook(String adminToken, int id) async {
    await _request(
      '/api/admin/books/$id',
      method: 'DELETE',
      bearerToken: adminToken,
    );
  }

  Future<List<dynamic>> adminAdvice(String adminToken) async =>
      List<dynamic>.from(
        await _request('/api/admin/advice', bearerToken: adminToken) as List,
      );

  Future<void> addAdvice(String adminToken, String text, String author) async {
    await _request(
      '/api/admin/advice',
      method: 'POST',
      bearerToken: adminToken,
      body: {'text': text, 'author': author, 'active': true},
    );
  }

  Future<void> deleteAdvice(String adminToken, int id) async {
    await _request(
      '/api/admin/advice/$id',
      method: 'DELETE',
      bearerToken: adminToken,
    );
  }

  Future<List<dynamic>> adminTopics(String adminToken) async =>
      List<dynamic>.from(
        await _request('/api/admin/topics', bearerToken: adminToken) as List,
      );

  Future<void> addTopic(String adminToken, Map<String, dynamic> value) async {
    await _request(
      '/api/admin/topics',
      method: 'POST',
      bearerToken: adminToken,
      body: value,
    );
  }

  Future<void> updateTopic(
    String adminToken,
    int id,
    Map<String, dynamic> value,
  ) async {
    await _request(
      '/api/admin/topics/$id',
      method: 'PUT',
      bearerToken: adminToken,
      body: value,
    );
  }

  Future<void> deleteTopic(String adminToken, int id) async {
    await _request(
      '/api/admin/topics/$id',
      method: 'DELETE',
      bearerToken: adminToken,
    );
  }

  Future<Map<String, dynamic>> adminSettings(String adminToken) async =>
      Map<String, dynamic>.from(
        await _request('/api/admin/settings', bearerToken: adminToken) as Map,
      );

  Future<void> updateSettings(
    String adminToken,
    Map<String, dynamic> value,
  ) async {
    await _request(
      '/api/admin/settings',
      method: 'PUT',
      bearerToken: adminToken,
      body: value,
    );
  }

  Future<void> changeAdminPassword(
    String adminToken,
    String currentPassword,
    String newPassword,
  ) async {
    await _request(
      '/api/admin/change-password',
      method: 'POST',
      bearerToken: adminToken,
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<void> answerInquiry({
    required String adminToken,
    required int id,
    required String answer,
    required bool publishPublic,
  }) async {
    await _request(
      '/api/admin/inquiries/$id',
      method: 'PUT',
      bearerToken: adminToken,
      body: {
        'answer': answer,
        'status': 'answered',
        'publishPublic': publishPublic,
      },
    );
  }

  Future<void> answerSupport({
    required String adminToken,
    required int id,
    required String reply,
    required String status,
  }) async {
    await _request(
      '/api/admin/support/$id',
      method: 'PUT',
      bearerToken: adminToken,
      body: {'reply': reply, 'status': status},
    );
  }

  Future<void> adminLogout(String adminToken) async {
    await _request(
      '/api/admin/logout',
      method: 'POST',
      bearerToken: adminToken,
      body: const {},
    );
  }
}
