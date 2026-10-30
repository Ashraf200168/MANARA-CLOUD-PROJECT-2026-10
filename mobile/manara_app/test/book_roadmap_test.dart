import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_app/screens/sheikh_book_roadmap_screen.dart';
import 'package:manara_app/screens/sheikh_exams_screen.dart';
import 'package:manara_app/services/api_client.dart';

class _RoadmapApi extends ApiClient {
  @override
  Future<Map<String, dynamic>> adminBookRoadmap(String token, int id) async => {
    'summary': {
      'activeExams': 2,
      'students': 1,
      'completedStudents': 0,
      'averageCompletion': 50,
    },
    'exams': [
      {'id': 1, 'title': 'امتحان المرحلة الأولى', 'roadmapPosition': 1},
      {
        'id': 2,
        'title': 'امتحان الكتاب النهائي',
        'roadmapPosition': 2,
        'isFinal': true,
      },
    ],
    'students': [
      {
        'id': 8,
        'name': 'طالب الاختبار',
        'studentCode': 'ST-TEST',
        'completedExams': 1,
        'totalExams': 2,
        'completionRate': 50,
        'averagePercentage': 80,
        'earnedScore': 8,
        'assessedMaxScore': 10,
        'finalStatus': 'ready',
        'exams': [
          {
            'examId': 1,
            'status': 'completed',
            'score': 8,
            'maxScore': 10,
            'percentage': 80,
          },
          {'examId': 2, 'status': 'ready'},
        ],
      },
    ],
  };
}

Widget _app(Widget child) => MaterialApp(
  builder: (context, child) => Directionality(
    textDirection: TextDirection.rtl,
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.2)),
      child: child!,
    ),
  ),
  home: child,
);

void main() {
  testWidgets(
    'student path shows individual marks, aggregate, and final state on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          SheikhBookRoadmapDetailScreen(
            api: _RoadmapApi(),
            adminToken: 'test',
            bookId: 3,
            bookTitle: 'كتاب الاختبار',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('طالب الاختبار'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('طالب الاختبار'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('معدل الكتاب حتى الآن'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('معدل الكتاب حتى الآن: 80٪'), findsOneWidget);
      expect(find.textContaining('مجموع الدرجات 8 من 10'), findsOneWidget);
      expect(find.text('8 / 10'), findsOneWidget);
      expect(find.text('الامتحان النهائي: جاهز للبدء'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('exam editing preserves roadmap and certificate metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: ExamEditorDialog(
            books: [
              {'id': 3, 'title': 'كتاب الاختبار'},
            ],
            exam: {
              'title': 'نهائي',
              'book_id': 3,
              'roadmap_position': 4,
              'is_book_final': true,
              'certificate_enabled': true,
              'certificate_pass_percentage': 70,
            },
          ),
        ),
      ),
    );
    expect(find.text('4'), findsOneWidget);
    expect(find.text('هذا هو الامتحان النهائي للكتاب'), findsOneWidget);
    expect(
      find.widgetWithText(SwitchListTile, 'هذا هو الامتحان النهائي للكتاب'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
