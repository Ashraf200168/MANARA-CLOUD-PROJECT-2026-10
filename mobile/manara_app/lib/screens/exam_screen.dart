import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../services/api_client.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({
    super.key,
    required this.controller,
    required this.examId,
    required this.payload,
  });

  final AppController controller;
  final int examId;
  final Map<String, dynamic> payload;

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  late final List<dynamic> questions;
  late final DateTime deadline;
  late Map<String, dynamic> answers;
  Timer? timer;
  int current = 0;
  bool submitting = false;
  bool backgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    questions = List<dynamic>.from(
      widget.payload['questions'] as List? ?? const [],
    );
    deadline =
        DateTime.tryParse(
          widget.payload['deadline']?.toString() ?? '',
        )?.toLocal() ??
        DateTime.now().add(const Duration(minutes: 30));
    answers = widget.controller.store.examDraft(widget.examId);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_remaining == Duration.zero && !submitting) _submit(automatic: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() => backgrounded = state != AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  Duration get _remaining {
    final value = deadline.difference(DateTime.now());
    return value.isNegative ? Duration.zero : value;
  }

  String get _clock {
    final value = _remaining;
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Future<void> _saveAnswer(int questionId, dynamic value) async {
    setState(() => answers[questionId.toString()] = value);
    await widget.controller.store.saveExamDraft(widget.examId, answers);
  }

  @override
  Widget build(BuildContext context) {
    final answered = answers.values
        .where((value) => value != null && value.toString().isNotEmpty)
        .length;
    final question = questions.isEmpty
        ? null
        : Map<String, dynamic>.from(questions[current] as Map);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('الامتحان ما زال جاريًا'),
            content: const Text(
              'ستبقى إجاباتك محفوظة على الجهاز، لكن يجب العودة والتسليم قبل انتهاء الوقت.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('متابعة الامتحان'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('الخروج مؤقتًا'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  widget.payload['title']?.toString() ?? 'الامتحان',
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'تمت الإجابة عن $answered من ${questions.length}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFBFD5E0)),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsetsDirectional.only(end: 12),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: _remaining.inMinutes < 5
                    ? const Color(0xFF7E2E2A)
                    : const Color(0xFF0A2D42),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _clock,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: questions.isEmpty
            ? const Center(child: Text('لا توجد أسئلة في هذا الامتحان.'))
            : Column(
                children: [
                  if (backgrounded)
                    const Material(
                      color: Color(0xFFFFE3DE),
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'أعد فتح التطبيق فورًا؛ وقت الامتحان يستمر في الخلفية.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  LinearProgressIndicator(
                    value: (current + 1) / questions.length,
                    minHeight: 5,
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(questions.length, (index) {
                            final q = Map<String, dynamic>.from(
                              questions[index] as Map,
                            );
                            final hasAnswer = answers.containsKey(
                              q['id'].toString(),
                            );
                            return InkWell(
                              onTap: () => setState(() => current = index),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: index == current
                                      ? const Color(0xFF123E59)
                                      : hasAnswer
                                      ? const Color(0xFFE1F4EB)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: index == current
                                        ? const Color(0xFF123E59)
                                        : const Color(0xFFCADCE5),
                                  ),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: index == current
                                        ? Colors.white
                                        : const Color(0xFF123E59),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 20),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text('السؤال ${current + 1}'),
                                    ),
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(
                                        '${question!['points']} درجة',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  question['prompt']?.toString() ?? '',
                                  textAlign: TextAlign.start,
                                  textDirection: TextDirection.rtl,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF123E59),
                                        height: 1.55,
                                      ),
                                ),
                                const SizedBox(height: 20),
                                _QuestionInput(
                                  question: question,
                                  value: answers[question['id'].toString()],
                                  onChanged: (value) => _saveAnswer(
                                    int.parse(question['id'].toString()),
                                    value,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFDCE9EF)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: current < questions.length - 1
                                ? FilledButton.icon(
                                    onPressed: () => setState(() => current++),
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      textDirection: TextDirection.ltr,
                                    ),
                                    label: const Text('التالي'),
                                  )
                                : FilledButton.icon(
                                    onPressed: submitting ? null : _submit,
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                    ),
                                    label: Text(
                                      submitting
                                          ? 'جارٍ التسليم…'
                                          : 'تسليم الامتحان',
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: current == 0
                                  ? null
                                  : () => setState(() => current--),
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                textDirection: TextDirection.ltr,
                              ),
                              label: const Text('السابق'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _submit({bool automatic = false}) async {
    if (submitting) return;
    if (!automatic) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تسليم نهائي'),
          content: Text(
            'أجبت عن ${answers.length} من ${questions.length}. بعد التسليم لا يمكن تعديل الإجابات.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('مراجعة الإجابات'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تسليم الآن'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => submitting = true);
    try {
      final result = await widget.controller.submitExam(widget.examId, answers);
      await widget.controller.store.clearExamDraft(widget.examId);
      timer?.cancel();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.task_alt_rounded,
            size: 54,
            color: Color(0xFF167451),
          ),
          title: const Text('تم التسليم بنجاح'),
          content: Text(
            'نتيجتك ${result['score']} من ${result['maxScore']} (${result['percentage']}٪).',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('العودة إلى صفحتي'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            '${error.message} إجاباتك محفوظة على الجهاز، أعد الاتصال وحاول فورًا.',
          ),
        ),
      );
    }
  }
}

class _QuestionInput extends StatelessWidget {
  const _QuestionInput({
    required this.question,
    required this.value,
    required this.onChanged,
  });
  final Map<String, dynamic> question;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    final type = question['type']?.toString() ?? '';
    if (type == 'choice') {
      final options = List<dynamic>.from(
        question['options'] as List? ?? const [],
      );
      return Column(
        children: List.generate(
          options.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AnswerOption(
              selected: value is num && value.toInt() == index,
              label: options[index].toString(),
              onTap: () => onChanged(index),
            ),
          ),
        ),
      );
    }
    if (type == 'truefalse') {
      return Column(
        children: [
          _AnswerOption(
            selected: value == true,
            label: 'صح',
            onTap: () => onChanged(true),
          ),
          const SizedBox(height: 10),
          _AnswerOption(
            selected: value == false,
            label: 'خطأ',
            onTap: () => onChanged(false),
          ),
        ],
      );
    }
    if (type == 'matching') {
      final left = List<dynamic>.from(question['left'] as List? ?? const []);
      final right = List<dynamic>.from(question['right'] as List? ?? const []);
      final current = value is Map
          ? Map<String, dynamic>.from(value as Map)
          : <String, dynamic>{};
      return Column(
        children: List.generate(
          left.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              initialValue: current[index.toString()]?.toString(),
              isExpanded: true,
              alignment: AlignmentDirectional.centerStart,
              decoration: InputDecoration(
                labelText: left[index].toString(),
                alignLabelWithHint: true,
              ),
              items: right
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.toString(),
                      child: Text(
                        item.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (selected) {
                final next = Map<String, dynamic>.from(current);
                next[index.toString()] = selected;
                onChanged(next);
              },
            ),
          ),
        ),
      );
    }
    return TextFormField(
      initialValue: value?.toString() ?? '',
      minLines: 2,
      maxLines: 5,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: question['placeholder']?.toString() ?? 'اكتب إجابتك',
      ),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE4F1F6) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? const Color(0xFF246B89) : const Color(0xFFCADCE5),
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: const Color(0xFF246B89),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.start,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}
