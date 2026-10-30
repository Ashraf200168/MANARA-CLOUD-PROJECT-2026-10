import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_app/screens/sheikh_exams_screen.dart';

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> openEditor(
  WidgetTester tester, {
  Map<String, dynamic>? question,
  void Function(Map<String, dynamic>?)? onSave,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (_, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final value = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (_) => QuestionEditorDialog(question: question),
              );
              onSave?.call(value);
            },
            child: const Text('فتح المحرر'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('فتح المحرر'));
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), value);
  await tester.pump();
}

void main() {
  testWidgets(
    'new choice question starts with three separate answers and adds another',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openEditor(tester);
      expect(field('نص الإجابة 1'), findsOneWidget);
      expect(field('نص الإجابة 2'), findsOneWidget);
      expect(field('نص الإجابة 3'), findsOneWidget);
      expect(field('نص الإجابة 4'), findsNothing);
      await fill(tester, 'نص الإجابة 1', 'الإجابة الأولى');
      await tester.ensureVisible(find.text('إضافة إجابة'));
      await tester.tap(find.text('إضافة إجابة'));
      await tester.pumpAndSettle();
      expect(field('نص الإجابة 4'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('نص الإجابة 1')).controller!.text,
        'الإجابة الأولى',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selecting a correct answer saves its index and survives changing question type',
    (tester) async {
      Map<String, dynamic>? saved;
      await openEditor(tester, onSave: (value) => saved = value);
      await fill(tester, 'نص السؤال', 'سؤال جديد');
      for (var index = 1; index <= 3; index++) {
        await fill(tester, 'نص الإجابة $index', 'إجابة $index');
      }
      final correct = find.byType(RadioListTile<int>).at(2);
      await tester.ensureVisible(correct);
      await tester.tap(correct);
      await tester.pumpAndSettle();
      final type = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(type);
      await tester.tap(type);
      await tester.pumpAndSettle();
      await tester.tap(find.text('إجابة قصيرة').last);
      await tester.pumpAndSettle();
      await tester.tap(type);
      await tester.pumpAndSettle();
      await tester.tap(find.text('اختيار من متعدد').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('نص الإجابة 3')).controller!.text,
        'إجابة 3',
      );
      expect(
        tester
            .widget<RadioListTile<int>>(find.byType(RadioListTile<int>).at(2))
            .selected,
        isTrue,
      );
      await tester.tap(find.text('حفظ السؤال'));
      await tester.pumpAndSettle();
      expect(saved!['data']['correct'], 2);
      expect(saved!['data']['options'], ['إجابة 1', 'إجابة 2', 'إجابة 3']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'deleting an earlier answer preserves correct answer identity and source notes',
    (tester) async {
      Map<String, dynamic>? saved;
      await openEditor(
        tester,
        question: {
          'prompt': 'سؤال سابق',
          'type': 'choice',
          'points': 2,
          'data': {
            'options': ['الأولى', 'الثانية', 'الصحيحة'],
            'correct': 2,
            'explanation': 'شرح محفوظ',
            'bank': {'id': 42},
          },
        },
        onSave: (value) => saved = value,
      );
      await tester.ensureVisible(find.byTooltip('حذف الإجابة 1'));
      await tester.tap(find.byTooltip('حذف الإجابة 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ السؤال'));
      await tester.pumpAndSettle();
      expect(saved!['data']['options'], ['الثانية', 'الصحيحة']);
      expect(saved!['data']['correct'], 1);
      expect(saved!['data']['explanation'], 'شرح محفوظ');
      expect(saved!['data']['bank']['id'], 42);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty answers and a missing correct answer show clear validation',
    (tester) async {
      await openEditor(tester);
      await fill(tester, 'نص السؤال', 'سؤال جديد');
      await tester.tap(find.text('حفظ السؤال'));
      await tester.pumpAndSettle();
      expect(
        find.text('أكمل جميع الإجابات أو احذف الخانات الفارغة.'),
        findsOneWidget,
      );
      for (var index = 1; index <= 3; index++) {
        await fill(tester, 'نص الإجابة $index', 'إجابة $index');
      }
      await tester.tap(find.text('حفظ السؤال'));
      await tester.pumpAndSettle();
      expect(find.text('حدّد الإجابة الصحيحة قبل الحفظ.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a selected answer can be removed and must be explicitly reselected',
    (tester) async {
      await openEditor(
        tester,
        question: {
          'prompt': 'سؤال',
          'type': 'choice',
          'points': 1,
          'data': {
            'options': ['أ', 'ب', 'ج'],
            'correct': 1,
          },
        },
      );
      await tester.ensureVisible(find.byTooltip('حذف الإجابة 2'));
      await tester.tap(find.byTooltip('حذف الإجابة 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ السؤال'));
      await tester.pumpAndSettle();
      expect(find.text('حدّد الإجابة الصحيحة قبل الحفظ.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'duplicate answers are rejected and multiline answers remain one option',
    (tester) async {
      Map<String, dynamic>? saved;
      await openEditor(
        tester,
        question: {
          'prompt': 'سؤال',
          'type': 'choice',
          'points': 1,
          'data': {
            'options': ['الأولى', ' الثانية ', 'الثانية'],
            'correct': 0,
          },
        },
        onSave: (value) => saved = value,
      );
      await tester.tap(find.text('حفظ السؤال'));
      await tester.pumpAndSettle();
      expect(
        find.text('توجد إجابات مكررة. اجعل كل إجابة مختلفة.'),
        findsOneWidget,
      );
      await fill(tester, 'نص الإجابة 3', 'إجابة طويلة\nفي سطرين');
      await tester.tap(find.text('حفظ السؤال'));
      await tester.pumpAndSettle();
      expect(saved!['data']['options'], [
        'الأولى',
        'الثانية',
        'إجابة طويلة\nفي سطرين',
      ]);
      expect(saved!['data']['correct'], 0);
      expect(tester.takeException(), isNull);
    },
  );
}
