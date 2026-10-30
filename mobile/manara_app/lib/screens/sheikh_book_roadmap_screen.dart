import 'package:flutter/material.dart';

import '../services/api_client.dart';

class SheikhBookRoadmapsScreen extends StatefulWidget {
  const SheikhBookRoadmapsScreen({
    super.key,
    required this.api,
    required this.adminToken,
  });

  final ApiClient api;
  final String adminToken;

  @override
  State<SheikhBookRoadmapsScreen> createState() =>
      _SheikhBookRoadmapsScreenState();
}

class _SheikhBookRoadmapsScreenState extends State<SheikhBookRoadmapsScreen> {
  List<dynamic> roadmaps = const [];
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
      final result = await widget.api.adminBookRoadmaps(widget.adminToken);
      if (mounted) setState(() => roadmaps = result);
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('مسارات الكتب'),
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: loading ? null : _load,
          icon: const Icon(Icons.sync_rounded),
        ),
      ],
    ),
    body: loading && roadmaps.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              children: [
                const Text(
                  'خارطة تقدّم الطلاب',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF123E59),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'اختر كتابًا لترى درجات كل طالب امتحانًا بعد امتحان حتى الاختبار النهائي.',
                ),
                const SizedBox(height: 16),
                if (error != null) _RoadmapError(error!),
                if (roadmaps.isEmpty)
                  const _EmptyRoadmap(
                    text: 'لا توجد كتب بعد. أضف كتابًا ثم اربط به الامتحانات.',
                  )
                else
                  ...roadmaps.map((raw) {
                    final roadmap = Map<String, dynamic>.from(raw as Map);
                    final book = _asMap(roadmap['book']);
                    final summary = _asMap(roadmap['summary']);
                    final finalExam = roadmap['finalExam'] == null
                        ? null
                        : _asMap(roadmap['finalExam']);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SheikhBookRoadmapDetailScreen(
                                api: widget.api,
                                adminToken: widget.adminToken,
                                bookId: _asInt(book['id']),
                                bookTitle: book['title']?.toString() ?? 'كتاب',
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Color(0xFFFFF2C8),
                                    foregroundColor: Color(0xFF9B7626),
                                    child: Icon(Icons.route_outlined),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      book['title']?.toString() ?? 'كتاب',
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF123E59),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_left_rounded),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _InfoPill(
                                    icon: Icons.assignment_outlined,
                                    text:
                                        '${summary['activeExams'] ?? 0} امتحان محتسب',
                                  ),
                                  _InfoPill(
                                    icon: Icons.people_outline,
                                    text: '${summary['students'] ?? 0} طالب',
                                  ),
                                  _InfoPill(
                                    icon: Icons.donut_large_outlined,
                                    text:
                                        'متوسط الإنجاز ${summary['averageCompletion'] ?? 0}٪',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value:
                                    (_asDouble(summary['averageCompletion']) /
                                            100)
                                        .clamp(0, 1),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(99),
                                backgroundColor: const Color(0xFFE3EDF2),
                                color: const Color(0xFF2F8392),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                finalExam == null
                                    ? 'لم يُحدّد امتحان نهائي لهذا الكتاب بعد.'
                                    : 'النهائي: ${finalExam['title']}',
                                style: TextStyle(
                                  color: finalExam == null
                                      ? const Color(0xFF7C858B)
                                      : const Color(0xFF8A6A22),
                                  fontWeight: FontWeight.w700,
                                ),
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
}

class SheikhBookRoadmapDetailScreen extends StatefulWidget {
  const SheikhBookRoadmapDetailScreen({
    super.key,
    required this.api,
    required this.adminToken,
    required this.bookId,
    required this.bookTitle,
  });

  final ApiClient api;
  final String adminToken;
  final int bookId;
  final String bookTitle;

  @override
  State<SheikhBookRoadmapDetailScreen> createState() =>
      _SheikhBookRoadmapDetailScreenState();
}

class _SheikhBookRoadmapDetailScreenState
    extends State<SheikhBookRoadmapDetailScreen> {
  Map<String, dynamic>? roadmap;
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
      final result = await widget.api.adminBookRoadmap(
        widget.adminToken,
        widget.bookId,
      );
      if (mounted) setState(() => roadmap = result);
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = roadmap;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookTitle),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: loading && value == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  if (error != null) _RoadmapError(error!),
                  if (value != null) ..._content(value),
                ],
              ),
            ),
    );
  }

  List<Widget> _content(Map<String, dynamic> value) {
    final summary = _asMap(value['summary']);
    final exams = List<dynamic>.from(value['exams'] as List? ?? const []);
    final students = List<dynamic>.from(value['students'] as List? ?? const []);
    return [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _SummaryCard(
            label: 'امتحانات المسار',
            value: '${summary['activeExams'] ?? 0}',
            icon: Icons.flag_outlined,
          ),
          _SummaryCard(
            label: 'طلاب بدأوا',
            value: '${summary['students'] ?? 0}',
            icon: Icons.people_outline,
          ),
          _SummaryCard(
            label: 'أكملوا المسار',
            value: '${summary['completedStudents'] ?? 0}',
            icon: Icons.verified_outlined,
          ),
          _SummaryCard(
            label: 'متوسط الإنجاز',
            value: '${summary['averageCompletion'] ?? 0}٪',
            icon: Icons.donut_large_outlined,
          ),
        ],
      ),
      const SizedBox(height: 24),
      const Text(
        'محطات الكتاب',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w900,
          color: Color(0xFF123E59),
        ),
      ),
      const SizedBox(height: 10),
      if (exams.isEmpty)
        const _EmptyRoadmap(text: 'لم تُربط امتحانات بهذا الكتاب بعد.')
      else
        _ExamRoadmap(exams: exams),
      const SizedBox(height: 24),
      Text(
        'تقدّم الطلاب (${students.length})',
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w900,
          color: Color(0xFF123E59),
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'الإنجاز = الامتحانات المسلّمة بلا مخالفة ÷ امتحانات الكتاب المنشورة والمغلقة. '
        'المعدل = مجموع الدرجات ÷ مجموع الدرجات الكلية للامتحانات المسلّمة فقط. '
        'المسودات والمسابقات العامة لا تُحتسب.',
        style: TextStyle(color: Color(0xFF59666D), fontSize: 13),
      ),
      const SizedBox(height: 10),
      if (students.isEmpty)
        const _EmptyRoadmap(
          text: 'لا يوجد طالب مرتبط بأي امتحان في هذا الكتاب.',
        )
      else
        ...students.map(
          (raw) => _StudentProgressCard(
            student: Map<String, dynamic>.from(raw as Map),
            exams: exams,
          ),
        ),
    ];
  }
}

class _ExamRoadmap extends StatelessWidget {
  const _ExamRoadmap({required this.exams, this.results = const {}});

  final List<dynamic> exams;
  final Map<int, Map<String, dynamic>> results;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: results.isEmpty ? 160 : 200,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: exams.length,
      separatorBuilder: (_, _) => const Center(
        child: SizedBox(
          width: 30,
          child: Divider(thickness: 2, color: Color(0xFF9CC4D3)),
        ),
      ),
      itemBuilder: (context, index) {
        final exam = Map<String, dynamic>.from(exams[index] as Map);
        final isFinal = exam['isFinal'] == true;
        final isDraft = exam['status'] == 'draft';
        final result = results[_asInt(exam['id'])];
        return SizedBox(
          width: 126,
          child: Column(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: isFinal
                    ? const Color(0xFFD9AA48)
                    : isDraft
                    ? const Color(0xFFDCE4E8)
                    : const Color(0xFF246B89),
                foregroundColor: isDraft
                    ? const Color(0xFF59666D)
                    : Colors.white,
                child: isFinal
                    ? const Icon(Icons.emoji_events_outlined)
                    : Text(
                        '${exam['roadmapPosition'] ?? index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                exam['title']?.toString() ?? 'امتحان',
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                isFinal
                    ? 'نهائي'
                    : isDraft
                    ? 'مسودة — لا يُحتسب'
                    : 'مرحلة',
                style: TextStyle(
                  fontSize: 12,
                  color: isFinal
                      ? const Color(0xFF8A6A22)
                      : const Color(0xFF718087),
                ),
              ),
              if (result != null) ...[
                const SizedBox(height: 5),
                Text(
                  result['percentage'] == null
                      ? _statusLabel(result['status']?.toString() ?? '')
                      : '${result['score']} / ${result['maxScore']} · ${result['percentage']}٪',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _statusColor(result['status']?.toString() ?? ''),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class _StudentProgressCard extends StatelessWidget {
  const _StudentProgressCard({required this.student, required this.exams});

  final Map<String, dynamic> student;
  final List<dynamic> exams;

  @override
  Widget build(BuildContext context) {
    final progress = List<dynamic>.from(student['exams'] as List? ?? const []);
    final byExam = <int, Map<String, dynamic>>{
      for (final raw in progress)
        _asInt((raw as Map)['examId']): Map<String, dynamic>.from(raw),
    };
    final completion = _asDouble(student['completionRate']);
    final average = student['averagePercentage'];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: CircleAvatar(
          backgroundColor: completion >= 100
              ? const Color(0xFFDDF3E9)
              : const Color(0xFFE4F0F5),
          foregroundColor: completion >= 100
              ? const Color(0xFF19714E)
              : const Color(0xFF246B89),
          child: Icon(
            completion >= 100 ? Icons.verified_rounded : Icons.person_outline,
          ),
        ),
        title: Text(
          student['name']?.toString() ?? 'طالب',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF123E59),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              student['studentCode']?.toString() ?? '',
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (completion / 100).clamp(0, 1),
              minHeight: 7,
              borderRadius: BorderRadius.circular(99),
              backgroundColor: const Color(0xFFE3EDF2),
              color: completion >= 100
                  ? const Color(0xFF2A8B68)
                  : const Color(0xFF2F8392),
            ),
            const SizedBox(height: 5),
            Text(
              '${student['completedExams'] ?? 0} من ${student['totalExams'] ?? 0} — إنجاز ${completion.round()}٪${average == null ? '' : ' — معدل المسلّم $average٪'}',
            ),
          ],
        ),
        children: [
          const Divider(),
          _ExamRoadmap(exams: exams, results: byExam),
          if (average != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'معدل الكتاب حتى الآن: $average٪ — '
                'مجموع الدرجات ${student['earnedScore']} من ${student['assessedMaxScore']}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          Text(
            student['finalStatus'] == 'not_configured'
                ? 'لم يُحدّد الامتحان النهائي بعد.'
                : 'الامتحان النهائي: ${_statusLabel(student['finalStatus']?.toString() ?? '')}',
          ),
          ...exams.map((raw) {
            final exam = Map<String, dynamic>.from(raw as Map);
            final result = byExam[_asInt(exam['id'])] ?? const {};
            final status = result['status']?.toString() ?? 'not_assigned';
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(_statusIcon(status), color: _statusColor(status)),
              title: Text(
                exam['title']?.toString() ?? 'امتحان',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(_statusLabel(status)),
              trailing: result['percentage'] == null
                  ? null
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${result['score']} / ${result['maxScore']}',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${result['percentage']}٪',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _statusColor(status),
                          ),
                        ),
                      ],
                    ),
            );
          }),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 46) / 2,
    child: Card(
      color: const Color(0xFFF8FCFE),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF2F8392)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF123E59),
              ),
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFF0F7FA),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF246B89)),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}

class _RoadmapError extends StatelessWidget {
  const _RoadmapError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFFFE9E6),
    child: ListTile(
      leading: const Icon(Icons.error_outline, color: Color(0xFFB3261E)),
      title: Text(message),
    ),
  );
}

class _EmptyRoadmap extends StatelessWidget {
  const _EmptyRoadmap({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text(text, textAlign: TextAlign.center)),
    ),
  );
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

double _asDouble(dynamic value) =>
    double.tryParse(value?.toString() ?? '') ?? 0;

String _statusLabel(String status) => switch (status) {
  'completed' => 'مكتمل',
  'violation' => 'مخالفة نزاهة — لا يُحتسب',
  'started' => 'قيد الحل',
  'ready' => 'جاهز للبدء',
  _ => 'غير مرتبط بهذا الامتحان',
};

IconData _statusIcon(String status) => switch (status) {
  'completed' => Icons.check_circle_outline,
  'violation' => Icons.gpp_bad_outlined,
  'started' => Icons.pending_outlined,
  'ready' => Icons.schedule_outlined,
  _ => Icons.remove_circle_outline,
};

Color _statusColor(String status) => switch (status) {
  'completed' => const Color(0xFF19714E),
  'violation' => const Color(0xFFB3261E),
  'started' => const Color(0xFFB56A12),
  'ready' => const Color(0xFF246B89),
  _ => const Color(0xFF7C858B),
};
