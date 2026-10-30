import 'package:flutter/material.dart';

import '../services/api_client.dart';

class SheikhExamsScreen extends StatefulWidget {
  const SheikhExamsScreen({
    super.key,
    required this.api,
    required this.adminToken,
  });

  final ApiClient api;
  final String adminToken;

  @override
  State<SheikhExamsScreen> createState() => _SheikhExamsScreenState();
}

class _SheikhExamsScreenState extends State<SheikhExamsScreen> {
  List<dynamic> exams = const [];
  List<dynamic> books = const [];
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait<dynamic>([
        widget.api.adminExams(widget.adminToken),
        widget.api.adminBooks(widget.adminToken),
      ]);
      if (mounted) {
        setState(() {
          exams = List<dynamic>.from(values[0] as List);
          books = List<dynamic>.from(values[1] as List);
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('إدارة الامتحانات'),
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.sync_rounded)),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _create,
      icon: const Icon(Icons.add),
      label: const Text('امتحان جديد'),
    ),
    body: loading && exams.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
              children: [
                if (error != null) _AdminError(error!),
                const Text(
                  'الامتحانات',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF123E59),
                  ),
                ),
                const Text(
                  'الإنشاء والنشر والأسئلة وربط الطلاب تتم مباشرة مع السحابة.',
                ),
                const SizedBox(height: 16),
                if (exams.isEmpty)
                  const _EmptyAdmin(text: 'لا توجد امتحانات بعد.')
                else
                  ...exams.map((raw) {
                    final exam = Map<String, dynamic>.from(raw as Map);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _open(exam),
                        borderRadius: BorderRadius.circular(22),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _ExamStatus(exam['status']?.toString() ?? ''),
                                  const SizedBox(width: 8),
                                  Text(
                                    exam['access_mode'] == 'public'
                                        ? 'مسابقة عامة'
                                        : 'امتحان خاص',
                                  ),
                                  const Spacer(),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') _edit(exam);
                                      if (value == 'delete') _delete(exam);
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('تعديل البيانات'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('حذف الامتحان'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                exam['title']?.toString() ?? 'امتحان',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF123E59),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 14,
                                runSpacing: 6,
                                children: [
                                  Text('${exam['question_count'] ?? 0} سؤال'),
                                  Text('${exam['total_points'] ?? 0} درجة'),
                                  Text('${exam['student_count'] ?? 0} طالب'),
                                  Text(
                                    '${exam['duration_minutes'] ?? 0} دقيقة',
                                  ),
                                  if (exam['certificate_enabled'] == true)
                                    Text(
                                      'شهادة من ${exam['certificate_pass_percentage'] ?? 50}٪',
                                      style: const TextStyle(
                                        color: Color(0xFF8A6A22),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  if (exam['book_id'] != null)
                                    Text(
                                      exam['is_book_final'] == true
                                          ? 'الاختبار النهائي للكتاب'
                                          : 'المرحلة ${exam['roadmap_position'] ?? '—'} من الكتاب',
                                      style: const TextStyle(
                                        color: Color(0xFF246B89),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
  );

  Future<void> _create() async {
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ExamEditorDialog(books: books),
    );
    if (value == null) return;
    try {
      final id = await widget.api.createExam(widget.adminToken, value);
      await _load();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => SheikhExamDetailScreen(
              api: widget.api,
              adminToken: widget.adminToken,
              examId: id,
              books: books,
            ),
          ),
        ).then((_) => _load());
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> _edit(Map<String, dynamic> exam) async {
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ExamEditorDialog(exam: exam, books: books),
    );
    if (value == null) return;
    try {
      await widget.api.updateExam(
        widget.adminToken,
        int.parse(exam['id'].toString()),
        value,
      );
      await _load();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> _delete(Map<String, dynamic> exam) async {
    final yes = await _confirm(
      context,
      'حذف الامتحان؟',
      'سيُحذف الامتحان وأسئلته ومحاولاته ونتائجه نهائيًا.',
    );
    if (!yes) return;
    try {
      await widget.api.deleteExam(
        widget.adminToken,
        int.parse(exam['id'].toString()),
      );
      await _load();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  void _open(Map<String, dynamic> exam) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SheikhExamDetailScreen(
          api: widget.api,
          adminToken: widget.adminToken,
          examId: int.parse(exam['id'].toString()),
          books: books,
        ),
      ),
    ).then((_) => _load());
  }
}

class SheikhExamDetailScreen extends StatefulWidget {
  const SheikhExamDetailScreen({
    super.key,
    required this.api,
    required this.adminToken,
    required this.examId,
    required this.books,
  });

  final ApiClient api;
  final String adminToken;
  final int examId;
  final List<dynamic> books;

  @override
  State<SheikhExamDetailScreen> createState() => _SheikhExamDetailScreenState();
}

class _SheikhExamDetailScreenState extends State<SheikhExamDetailScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final fresh = await widget.api.adminExam(
        widget.adminToken,
        widget.examId,
      );
      if (mounted) setState(() => data = fresh);
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exam = Map<String, dynamic>.from(data?['exam'] as Map? ?? const {});
    final questions = List<dynamic>.from(
      data?['questions'] as List? ?? const [],
    );
    final assignments = List<dynamic>.from(
      data?['assignments'] as List? ?? const [],
    );
    final available = List<dynamic>.from(
      data?['availableStudents'] as List? ?? const [],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(exam['title']?.toString() ?? 'تفاصيل الامتحان'),
        actions: [
          IconButton(
            tooltip: 'إضافة سؤال جديد',
            onPressed: _addQuestion,
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            tooltip: 'تعديل الامتحان',
            onPressed: exam.isEmpty ? null : () => _editExam(exam),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.sync_rounded)),
        ],
      ),
      body: loading && data == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  if (error != null) _AdminError(error!),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ExamStatus(exam['status']?.toString() ?? ''),
                      Chip(
                        label: Text(
                          exam['access_mode'] == 'public'
                              ? 'مسابقة عامة'
                              : 'امتحان خاص متصل',
                        ),
                      ),
                      Chip(
                        label: Text('${exam['duration_minutes'] ?? 0} دقيقة'),
                      ),
                      if (exam['certificate_enabled'] == true)
                        Chip(
                          avatar: const Icon(
                            Icons.workspace_premium_outlined,
                            size: 18,
                            color: Color(0xFF8A6A22),
                          ),
                          label: Text(
                            'شهادة عند ${exam['certificate_pass_percentage'] ?? 50}٪',
                          ),
                          backgroundColor: const Color(0xFFFFF4D1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'الأسئلة (${questions.length})',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF123E59),
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _addQuestion,
                        icon: const Icon(Icons.add),
                        label: const Text('سؤال'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (questions.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.quiz_outlined,
                              size: 42,
                              color: Color(0xFF246B89),
                            ),
                            const SizedBox(height: 10),
                            const Text('لم تُضف أسئلة بعد.'),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _addQuestion,
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة السؤال الأول'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...questions.asMap().entries.map((entry) {
                      final question = Map<String, dynamic>.from(
                        entry.value as Map,
                      );
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'السؤال ${entry.key + 1} · ${_typeName(question['type'])} · ${question['points']} درجة',
                                      style: const TextStyle(
                                        color: Color(0xFF617986),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'تعديل',
                                    onPressed: () => _editQuestion(question),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'حذف',
                                    color: const Color(0xFFB3261E),
                                    onPressed: () => _deleteQuestion(question),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              Text(
                                question['prompt']?.toString() ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  if (exam['access_mode'] != 'public') ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'الطلاب المرتبطون (${assignments.where((raw) => (raw as Map)['is_test'] != true).length})',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF123E59),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: available.isEmpty
                              ? null
                              : () => _assign(available),
                          icon: const Icon(Icons.person_add_alt),
                          label: const Text('إضافة'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (assignments.isEmpty)
                      const _EmptyAdmin(text: 'لا يوجد طلاب مرتبطون.')
                    else
                      ...assignments.map((raw) {
                        final item = Map<String, dynamic>.from(raw as Map);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(item['name']?.toString() ?? 'طالب'),
                            subtitle: Text(
                              item['student_code']?.toString() ?? '',
                            ),
                            trailing: item['is_test'] == true
                                ? TextButton(
                                    onPressed: () => _resetTest(item),
                                    child: const Text('إعادة التجربة'),
                                  )
                                : IconButton(
                                    tooltip: 'إزالة من الامتحان',
                                    color: const Color(0xFFB3261E),
                                    onPressed: () => _removeAssignment(item),
                                    icon: const Icon(
                                      Icons.person_remove_outlined,
                                    ),
                                  ),
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _showResults,
                      icon: const Icon(Icons.bar_chart_outlined),
                      label: const Text('عرض نتائج الطلاب'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _editExam(Map<String, dynamic> exam) async {
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ExamEditorDialog(exam: exam, books: widget.books),
    );
    if (value == null) return;
    try {
      await widget.api.updateExam(widget.adminToken, widget.examId, value);
      await _load();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> _addQuestion() async {
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const QuestionEditorDialog(),
    );
    if (value == null) return;
    try {
      await widget.api.createQuestion(widget.adminToken, widget.examId, value);
      await _load();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> _editQuestion(Map<String, dynamic> question) async {
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => QuestionEditorDialog(question: question),
    );
    if (value == null) return;
    try {
      await widget.api.updateQuestion(
        widget.adminToken,
        int.parse(question['id'].toString()),
        value,
      );
      await _load();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> _deleteQuestion(Map<String, dynamic> question) async {
    if (!await _confirm(
      context,
      'حذف السؤال؟',
      'لن يظهر السؤال للطلاب بعد الحذف.',
    )) {
      return;
    }
    try {
      await widget.api.deleteQuestion(
        widget.adminToken,
        int.parse(question['id'].toString()),
      );
      await _load();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> _assign(List<dynamic> available) async {
    final selected = <int>{};
    final search = TextEditingController();
    var filter = '';
    final availableIds = available
        .map(
          (raw) =>
              int.parse(Map<String, dynamic>.from(raw as Map)['id'].toString()),
        )
        .toSet();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final allSelected =
              availableIds.isNotEmpty && selected.length == availableIds.length;
          final visibleStudents = available.where((raw) {
            final student = Map<String, dynamic>.from(raw as Map);
            if (filter.isEmpty) return true;
            final value =
                '${student['name'] ?? ''} ${student['student_code'] ?? ''}'
                    .toLowerCase();
            return value.contains(filter);
          }).toList();
          final selectAllValue = selected.isEmpty
              ? false
              : allSelected
              ? true
              : null;
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            title: const Text('ربط طلاب بالامتحان'),
            content: SizedBox(
              width: MediaQuery.sizeOf(dialogContext).width,
              height: MediaQuery.sizeOf(dialogContext).height * 0.62,
              child: Column(
                children: [
                  CheckboxListTile(
                    value: selectAllValue,
                    tristate: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (_) => setDialogState(() {
                      if (allSelected) {
                        selected.clear();
                      } else {
                        selected
                          ..clear()
                          ..addAll(availableIds);
                      }
                    }),
                    title: Text(
                      allSelected ? 'إلغاء اختيار الجميع' : 'اختيار الجميع',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'تم اختيار ${selected.length} من ${availableIds.length}',
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  TextField(
                    controller: search,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'بحث عن طالب',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setDialogState(
                      () => filter = value.trim().toLowerCase(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Scrollbar(
                      child: ListView.builder(
                        itemCount: visibleStudents.length,
                        itemBuilder: (context, index) {
                          final student = Map<String, dynamic>.from(
                            visibleStudents[index] as Map,
                          );
                          final id = int.parse(student['id'].toString());
                          return CheckboxListTile(
                            value: selected.contains(id),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (value) => setDialogState(() {
                              value == true
                                  ? selected.add(id)
                                  : selected.remove(id);
                            }),
                            title: Text(
                              student['name']?.toString() ?? 'طالب',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              student['student_code']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.right,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: Text('ربط المحددين (${selected.length})'),
              ),
            ],
          );
        },
      ),
    );
    search.dispose();
    if (confirmed != true) return;
    try {
      await widget.api.assignStudents(
        widget.adminToken,
        widget.examId,
        selected.toList(),
      );
      await _load();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> _removeAssignment(Map<String, dynamic> assignment) async {
    if (!await _confirm(
      context,
      'إزالة الطالب؟',
      'ستُحذف محاولته ونتيجته في هذا الامتحان فقط.',
    )) {
      return;
    }
    try {
      await widget.api.deleteAssignment(
        widget.adminToken,
        int.parse(assignment['id'].toString()),
      );
      await _load();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> _resetTest(Map<String, dynamic> assignment) async {
    try {
      await widget.api.resetSheikhTest(
        widget.adminToken,
        int.parse(assignment['id'].toString()),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أصبحت تجربة الشيخ جاهزة من جديد.')),
        );
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> _showResults() async {
    try {
      final results = await widget.api.adminExamResults(
        widget.adminToken,
        widget.examId,
      );
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => _ExamResultsScreen(results: results),
        ),
      );
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }
}

class _ExamResultsScreen extends StatelessWidget {
  const _ExamResultsScreen({required this.results});
  final List<dynamic> results;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('نتائج الطلاب')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        if (results.isEmpty)
          const _EmptyAdmin(text: 'لا يوجد طلاب في هذا الامتحان.')
        else
          ...results.map((raw) {
            final item = Map<String, dynamic>.from(raw as Map);
            final violation =
                (item['violation_type']?.toString() ?? '').isNotEmpty;
            final submitted = item['submitted_at'] != null;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: violation
                      ? const Color(0xFFFFE9E6)
                      : const Color(0xFFE6F6EF),
                  child: Icon(
                    violation ? Icons.warning_amber : Icons.person_outline,
                    color: violation
                        ? const Color(0xFFB3261E)
                        : const Color(0xFF167451),
                  ),
                ),
                title: Text(item['name']?.toString() ?? 'طالب'),
                subtitle: Text(
                  violation
                      ? 'مخالفة نزاهة'
                      : submitted
                      ? 'تم التسليم'
                      : item['status'] == 'started'
                      ? 'قيد الحل'
                      : 'جاهز للبدء',
                ),
                trailing: submitted
                    ? Text(
                        '${item['score'] ?? 0} / ${item['max_score'] ?? 0}\n${item['percentage'] ?? 0}٪',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      )
                    : null,
              ),
            );
          }),
      ],
    ),
  );
}

class ExamEditorDialog extends StatefulWidget {
  const ExamEditorDialog({super.key, this.exam, required this.books});

  final Map<String, dynamic>? exam;
  final List<dynamic> books;

  @override
  State<ExamEditorDialog> createState() => _ExamEditorDialogState();
}

class _ExamEditorDialogState extends State<ExamEditorDialog> {
  static const _noBookId = -1;

  late final TextEditingController title;
  late final TextEditingController instructions;
  late final TextEditingController duration;
  late final TextEditingController certificatePassPercentage;
  late final TextEditingController roadmapPosition;
  int bookId = _noBookId;
  String status = 'draft';
  String accessMode = 'private';
  bool certificateEnabled = false;
  bool isBookFinal = false;
  DateTime? startsAt;
  DateTime? endsAt;

  @override
  void initState() {
    super.initState();
    final exam = widget.exam ?? const <String, dynamic>{};
    title = TextEditingController(text: exam['title']?.toString());
    instructions = TextEditingController(
      text: exam['instructions']?.toString(),
    );
    duration = TextEditingController(
      text: (exam['duration_minutes'] ?? 30).toString(),
    );
    certificateEnabled =
        exam['certificate_enabled'] == true ||
        exam['certificateEnabled'] == true;
    certificatePassPercentage = TextEditingController(
      text:
          (exam['certificate_pass_percentage'] ??
                  exam['certificatePassPercentage'] ??
                  50)
              .toString(),
    );
    roadmapPosition = TextEditingController(
      text: (exam['roadmap_position'] ?? exam['roadmapPosition'] ?? '')
          .toString(),
    );
    isBookFinal = exam['is_book_final'] == true || exam['isBookFinal'] == true;
    bookId = exam['book_id'] == null
        ? _noBookId
        : int.tryParse(exam['book_id'].toString()) ?? _noBookId;
    status = exam['status']?.toString() ?? 'draft';
    accessMode = exam['access_mode']?.toString() ?? 'private';
    startsAt = DateTime.tryParse(
      exam['starts_at']?.toString() ?? '',
    )?.toLocal();
    endsAt = DateTime.tryParse(exam['ends_at']?.toString() ?? '')?.toLocal();
  }

  @override
  void dispose() {
    title.dispose();
    instructions.dispose();
    duration.dispose();
    certificatePassPercentage.dispose();
    roadmapPosition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.exam == null ? 'امتحان جديد' : 'تعديل الامتحان'),
    content: SizedBox(
      width: 540,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'عنوان الامتحان'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: bookId,
              isExpanded: true,
              alignment: AlignmentDirectional.centerStart,
              decoration: const InputDecoration(labelText: 'الكتاب'),
              items: [
                const DropdownMenuItem<int>(
                  value: _noBookId,
                  child: Text('بدون كتاب'),
                ),
                ...widget.books.map((raw) {
                  final book = Map<String, dynamic>.from(raw as Map);
                  return DropdownMenuItem<int>(
                    value: int.parse(book['id'].toString()),
                    child: Text(
                      book['title']?.toString() ?? 'كتاب',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: (value) => setState(() {
                bookId = value ?? _noBookId;
                if (bookId == _noBookId) isBookFinal = false;
              }),
            ),
            const SizedBox(height: 10),
            if (bookId != _noBookId) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4F8),
                  border: Border.all(color: const Color(0xFF9CC4D3)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: roadmapPosition,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ترتيب الامتحان في خارطة الكتاب',
                          helperText:
                              'اتركه فارغًا ليُضاف تلقائيًا بعد آخر امتحان.',
                          prefixIcon: Icon(Icons.route_outlined),
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: isBookFinal,
                        onChanged: (value) =>
                            setState(() => isBookFinal = value),
                        title: const Text(
                          'هذا هو الامتحان النهائي للكتاب',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          'يظهر للشيخ كآخر محطة في متابعة إنجاز الطالب.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            DropdownButtonFormField<String>(
              initialValue: accessMode,
              isExpanded: true,
              alignment: AlignmentDirectional.centerStart,
              decoration: const InputDecoration(labelText: 'طريقة الدخول'),
              items: const [
                DropdownMenuItem(
                  value: 'private',
                  child: Text('خاص — داخل صفحات الطلاب'),
                ),
                DropdownMenuItem(
                  value: 'public',
                  child: Text('مسابقة عامة — بلا تسجيل'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => accessMode = value ?? 'private'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المدة بالدقائق'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: status,
              isExpanded: true,
              alignment: AlignmentDirectional.centerStart,
              decoration: const InputDecoration(labelText: 'الحالة'),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                DropdownMenuItem(value: 'published', child: Text('منشور')),
                DropdownMenuItem(value: 'closed', child: Text('مغلق')),
              ],
              onChanged: (value) => setState(() => status = value ?? 'draft'),
            ),
            const SizedBox(height: 10),
            _DateField(
              label: 'وقت إتاحة الدخول',
              value: startsAt,
              onChanged: (value) => setState(() => startsAt = value),
            ),
            const SizedBox(height: 10),
            _DateField(
              label: 'انتهاء صلاحية الدخول',
              value: endsAt,
              onChanged: (value) => setState(() => endsAt = value),
            ),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E4),
                border: Border.all(color: const Color(0xFFE7C567)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: certificateEnabled,
                    onChanged: (value) =>
                        setState(() => certificateEnabled = value),
                    title: const Text(
                      'منح شهادة تفوق عند النجاح',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'تُنشأ تلقائيًا باسم الطالب ودرجته بعد اجتياز هذا الامتحان.',
                    ),
                    secondary: const Icon(
                      Icons.workspace_premium_outlined,
                      color: Color(0xFF9B7B37),
                    ),
                  ),
                  if (certificateEnabled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: TextField(
                        controller: certificatePassPercentage,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'نسبة النجاح لاستحقاق الشهادة',
                          suffixText: '٪',
                          helperText: 'قيمة من 0 إلى 100',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: instructions,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'تعليمات الطالب'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          if (title.text.trim().isEmpty) return;
          final passPercentage =
              double.tryParse(certificatePassPercentage.text.trim()) ?? 50;
          final roadmapText = roadmapPosition.text.trim();
          final roadmapValue = int.tryParse(roadmapText);
          if (bookId != _noBookId &&
              roadmapText.isNotEmpty &&
              (roadmapValue == null || roadmapValue <= 0)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ترتيب الامتحان يجب أن يكون رقمًا أكبر من صفر.'),
              ),
            );
            return;
          }
          if (certificateEnabled &&
              (passPercentage < 0 || passPercentage > 100)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('يجب أن تكون نسبة نجاح الشهادة بين 0 و100.'),
              ),
            );
            return;
          }
          Navigator.pop(context, {
            'title': title.text.trim(),
            'bookId': bookId == _noBookId ? null : bookId,
            'accessMode': accessMode,
            'durationMinutes': int.tryParse(duration.text) ?? 30,
            'startsAt': startsAt?.toUtc().toIso8601String(),
            'endsAt': endsAt?.toUtc().toIso8601String(),
            'status': status,
            'instructions': instructions.text.trim(),
            'certificateEnabled': certificateEnabled,
            'certificatePassPercentage': passPercentage,
            'roadmapPosition': bookId == _noBookId ? null : roadmapValue,
            'isBookFinal': bookId != _noBookId && isBookFinal,
          });
        },
        child: const Text('حفظ'),
      ),
    ],
  );
}

class QuestionEditorDialog extends StatefulWidget {
  const QuestionEditorDialog({super.key, this.question});
  final Map<String, dynamic>? question;

  @override
  State<QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends State<QuestionEditorDialog> {
  late final TextEditingController prompt;
  late final TextEditingController points;
  late final TextEditingController details;
  late final List<TextEditingController> choiceOptions;
  late final Map<String, dynamic> originalData;
  final Map<String, String> detailDrafts = {};
  int? correctChoice;
  String? validationMessage;
  bool validateChoices = false;
  late final TextEditingController explanation;
  late final TextEditingController evidence;
  late final TextEditingController guidance;
  String type = 'choice';
  bool trueFalse = true;

  @override
  void initState() {
    super.initState();
    final question = widget.question ?? const <String, dynamic>{};
    final data = Map<String, dynamic>.from(
      question['data'] as Map? ?? question['data_json'] as Map? ?? const {},
    );
    originalData = data;
    type = question['type']?.toString() ?? 'choice';
    prompt = TextEditingController(text: question['prompt']?.toString());
    points = TextEditingController(text: (question['points'] ?? 1).toString());
    final existingOptions = type == 'choice' && data['options'] is List
        ? List<dynamic>.from(data['options'] as List)
        : const <dynamic>[];
    choiceOptions = existingOptions.isEmpty
        ? List.generate(3, (_) => TextEditingController())
        : existingOptions
              .map((value) => TextEditingController(text: value.toString()))
              .toList();
    while (choiceOptions.length < 2) {
      choiceOptions.add(TextEditingController());
    }
    final existingCorrect = int.tryParse(data['correct']?.toString() ?? '');
    if (type == 'choice' &&
        existingCorrect != null &&
        existingCorrect >= 0 &&
        existingCorrect < existingOptions.length) {
      correctChoice = existingCorrect;
    }
    trueFalse = data['correct'] is bool ? data['correct'] as bool : true;
    details = TextEditingController(text: _detailsFor(type, data));
    explanation = TextEditingController(text: data['explanation']?.toString());
    evidence = TextEditingController(text: data['evidence']?.toString());
    guidance = TextEditingController(text: data['guidance']?.toString());
  }

  static String _detailsFor(String type, Map<String, dynamic> data) {
    if (type == 'matching') {
      return List<dynamic>.from(data['pairs'] as List? ?? const [])
          .map((raw) {
            final pair = Map<String, dynamic>.from(raw as Map);
            return '${pair['left'] ?? ''} | ${pair['right'] ?? ''}';
          })
          .join('\n');
    }
    if (type == 'short') {
      return List<dynamic>.from(
        data['accepted'] as List? ?? const [],
      ).join('\n');
    }
    return '';
  }

  @override
  void dispose() {
    for (final controller in [
      prompt,
      points,
      details,
      ...choiceOptions,
      explanation,
      evidence,
      guidance,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.question == null ? 'سؤال جديد' : 'تعديل السؤال'),
    content: SizedBox(
      width: 540,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              isExpanded: true,
              alignment: AlignmentDirectional.centerStart,
              decoration: const InputDecoration(labelText: 'نوع السؤال'),
              items: const [
                DropdownMenuItem(
                  value: 'choice',
                  child: Text('اختيار من متعدد'),
                ),
                DropdownMenuItem(value: 'truefalse', child: Text('صح أو خطأ')),
                DropdownMenuItem(
                  value: 'matching',
                  child: Text('وصل المطابقة'),
                ),
                DropdownMenuItem(value: 'short', child: Text('إجابة قصيرة')),
              ],
              onChanged: (value) => setState(() {
                detailDrafts[type] = details.text;
                type = value ?? 'choice';
                details.text = detailDrafts[type] ?? '';
                validationMessage = null;
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: prompt,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'نص السؤال'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: points,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الدرجة'),
            ),
            const SizedBox(height: 10),
            if (type == 'truefalse')
              DropdownButtonFormField<bool>(
                initialValue: trueFalse,
                isExpanded: true,
                alignment: AlignmentDirectional.centerStart,
                decoration: const InputDecoration(labelText: 'الإجابة الصحيحة'),
                items: const [
                  DropdownMenuItem(value: true, child: Text('صح')),
                  DropdownMenuItem(value: false, child: Text('خطأ')),
                ],
                onChanged: (value) => trueFalse = value ?? true,
              )
            else if (type == 'choice')
              _choiceFields()
            else ...[
              TextField(
                controller: details,
                minLines: 4,
                maxLines: 9,
                decoration: InputDecoration(
                  labelText: type == 'matching'
                      ? 'أزواج المطابقة — العنصر | مقابله'
                      : 'الإجابات المقبولة — إجابة في كل سطر',
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: explanation,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'الشرح بعد السؤال'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: evidence,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'الدليل أو المصدر'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: guidance,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'التوجيه'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      if (validationMessage != null)
        SizedBox(
          width: double.maxFinite,
          child: Semantics(
            liveRegion: true,
            child: Text(
              validationMessage!,
              style: const TextStyle(color: Color(0xFFB3261E)),
            ),
          ),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(onPressed: _save, child: const Text('حفظ السؤال')),
    ],
  );

  Widget _choiceFields() => RadioGroup<int>(
    groupValue: correctChoice,
    onChanged: (value) => setState(() => correctChoice = value),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('الإجابات', style: TextStyle(fontWeight: FontWeight.w900)),
        const Text(
          'اكتب كل إجابة في خانتها وحدّد الصحيحة. يمكنك حذف خانة للاكتفاء بإجابتين.',
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < choiceOptions.length; index++)
          Container(
            key: ObjectKey(choiceOptions[index]),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: correctChoice == index
                  ? const Color(0xFFEAF6EF)
                  : const Color(0xFFF5F9FC),
              border: Border.all(
                color: correctChoice == index
                    ? const Color(0xFF29805B)
                    : const Color(0xFFCADCE5),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'الإجابة ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'حذف الإجابة ${index + 1}',
                      onPressed: choiceOptions.length <= 2
                          ? null
                          : () => _removeChoice(index),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                TextField(
                  controller: choiceOptions[index],
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  onChanged: (_) {
                    if (validateChoices) setState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: 'نص الإجابة ${index + 1}',
                    errorText:
                        validateChoices &&
                            choiceOptions[index].text.trim().isEmpty
                        ? 'اكتب نص الإجابة أو احذف الخانة.'
                        : null,
                  ),
                ),
                RadioListTile<int>(
                  value: index,
                  title: Text(
                    correctChoice == index
                        ? 'هذه هي الإجابة الصحيحة'
                        : 'تحديد كإجابة صحيحة',
                  ),
                  selected: correctChoice == index,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: () =>
              setState(() => choiceOptions.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: const Text('إضافة إجابة'),
        ),
      ],
    ),
  );

  void _removeChoice(int index) {
    final removed = choiceOptions[index];
    setState(() {
      choiceOptions.removeAt(index);
      if (correctChoice == index) {
        correctChoice = null;
      } else if (correctChoice != null && correctChoice! > index) {
        correctChoice = correctChoice! - 1;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  void _invalid(String message) => setState(() => validationMessage = message);

  void _save() {
    if (prompt.text.trim().isEmpty) {
      _invalid('اكتب نص السؤال.');
      return;
    }
    final questionPoints = double.tryParse(points.text.trim());
    if (questionPoints == null ||
        !questionPoints.isFinite ||
        questionPoints < .25) {
      _invalid('اكتب درجة صالحة لا تقل عن 0.25.');
      return;
    }
    final lines = details.text
        .split(RegExp(r'\r?\n'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final data = <String, dynamic>{
      ...originalData,
      'explanation': explanation.text.trim(),
      'evidence': evidence.text.trim(),
      'guidance': guidance.text.trim(),
    };
    for (final key in ['options', 'correct', 'pairs', 'accepted']) {
      data.remove(key);
    }
    if (type == 'choice') {
      final options = choiceOptions
          .map((controller) => controller.text.trim())
          .toList();
      setState(() => validateChoices = true);
      if (options.any((value) => value.isEmpty)) {
        _invalid('أكمل جميع الإجابات أو احذف الخانات الفارغة.');
        return;
      }
      if (options.map((value) => value.toLowerCase()).toSet().length !=
          options.length) {
        _invalid('توجد إجابات مكررة. اجعل كل إجابة مختلفة.');
        return;
      }
      if (correctChoice == null ||
          correctChoice! < 0 ||
          correctChoice! >= options.length) {
        _invalid('حدّد الإجابة الصحيحة قبل الحفظ.');
        return;
      }
      data['options'] = options;
      data['correct'] = correctChoice;
    } else if (type == 'truefalse') {
      data['correct'] = trueFalse;
    } else if (type == 'matching') {
      final pairs = lines
          .map((line) => line.split('|').map((part) => part.trim()).toList())
          .where(
            (parts) => parts.length == 2 && parts.every((p) => p.isNotEmpty),
          )
          .map((parts) => {'left': parts[0], 'right': parts[1]})
          .toList();
      if (pairs.length < 2) {
        _invalid('أضف زوجين صالحين للمطابقة على الأقل.');
        return;
      }
      data['pairs'] = pairs;
    } else {
      if (lines.isEmpty) {
        _invalid('اكتب إجابة مقبولة واحدة على الأقل.');
        return;
      }
      data['accepted'] = lines;
    }
    Navigator.pop(context, {
      'type': type,
      'prompt': prompt.text.trim(),
      'points': questionPoints,
      'data': data,
    });
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: Row(
      children: [
        Expanded(
          child: Text(
            value == null
                ? 'غير محدد'
                : '${value!.year}/${value!.month}/${value!.day} — ${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}',
          ),
        ),
        IconButton(
          tooltip: 'اختيار',
          onPressed: () async {
            final base = value ?? DateTime.now();
            final date = await showDatePicker(
              context: context,
              initialDate: base,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
            );
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(base),
            );
            if (time == null) return;
            onChanged(
              DateTime(date.year, date.month, date.day, time.hour, time.minute),
            );
          },
          icon: const Icon(Icons.calendar_month_outlined),
        ),
        if (value != null)
          IconButton(
            tooltip: 'إزالة الوقت',
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.clear),
          ),
      ],
    ),
  );
}

class _ExamStatus extends StatelessWidget {
  const _ExamStatus(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final label =
        {'draft': 'مسودة', 'published': 'منشور', 'closed': 'مغلق'}[status] ??
        status;
    final color = status == 'published'
        ? const Color(0xFF167451)
        : status == 'closed'
        ? const Color(0xFFB3261E)
        : const Color(0xFF8A5B00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

String _typeName(dynamic type) =>
    {
      'choice': 'اختيار من متعدد',
      'truefalse': 'صح أو خطأ',
      'matching': 'وصل المطابقة',
      'short': 'إجابة قصيرة',
    }[type?.toString()] ??
    'سؤال';

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    ) ??
    false;

class _EmptyAdmin extends StatelessWidget {
  const _EmptyAdmin({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text(text)),
    ),
  );
}

class _AdminError extends StatelessWidget {
  const _AdminError(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFFFE9E6),
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(text, style: const TextStyle(color: Color(0xFFB3261E))),
    ),
  );
}
