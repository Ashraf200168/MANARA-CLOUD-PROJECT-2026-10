import 'package:flutter/material.dart';

import '../services/api_client.dart';

class SheikhStudentsScreen extends StatefulWidget {
  const SheikhStudentsScreen({
    super.key,
    required this.api,
    required this.adminToken,
  });

  final ApiClient api;
  final String adminToken;

  @override
  State<SheikhStudentsScreen> createState() => _SheikhStudentsScreenState();
}

class _SheikhStudentsScreenState extends State<SheikhStudentsScreen> {
  Map<String, dynamic>? data;
  String? error;
  bool loading = true;
  String search = '';

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
      final fresh = await widget.api.adminStudents(widget.adminToken);
      if (mounted) setState(() => data = fresh);
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = data;
    final pending = List<dynamic>.from(value?['pending'] as List? ?? const []);
    final allStudents = List<dynamic>.from(
      value?['students'] as List? ?? const [],
    );
    final term = search.trim().toLowerCase();
    final students = allStudents.where((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      return term.isEmpty ||
          (item['name']?.toString().toLowerCase() ?? '').contains(term) ||
          (item['code']?.toString().toLowerCase() ?? '').contains(term);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلاب'),
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
                  if (error != null) _ErrorCard(error!),
                  _Stats(data: value?['stats'] as Map?),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'طلبات التسجيل',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF123E59),
                          ),
                        ),
                      ),
                      _CountBadge('${pending.length} طلب'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (pending.isEmpty)
                    const _Empty(text: 'لا توجد طلبات تنتظر الموافقة.')
                  else
                    ...pending.map(
                      (raw) => _PendingCard(
                        student: Map<String, dynamic>.from(raw as Map),
                        onApprove: () => _status(raw, 'approved'),
                        onReject: () => _reject(raw),
                        onEdit: () => _edit(raw),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'الطلاب المقبولون',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF123E59),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (value) => setState(() => search = value),
                    decoration: const InputDecoration(
                      hintText: 'البحث بالاسم أو المعرّف الدائم',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (students.isEmpty)
                    const _Empty(text: 'لا يوجد طالب مطابق.')
                  else
                    ...students.map(
                      (raw) => _StudentCard(
                        student: Map<String, dynamic>.from(raw as Map),
                        onEdit: () => _edit(raw),
                        onDelete: () => _delete(raw),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _status(dynamic raw, String status, [String note = '']) async {
    final student = Map<String, dynamic>.from(raw as Map);
    try {
      await widget.api.updateStudentStatus(
        adminToken: widget.adminToken,
        id: int.parse(student['id'].toString()),
        status: status,
        reviewNote: note,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved' ? 'تم قبول الطالب.' : 'تم رفض الطلب.',
            ),
          ),
        );
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> _reject(dynamic raw) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفض طلب التسجيل'),
        content: TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'ملاحظة اختيارية تظهر للطالب',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('رفض الطلب'),
          ),
        ],
      ),
    );
    final value = note.text.trim();
    note.dispose();
    if (confirmed == true) await _status(raw, 'rejected', value);
  }

  Future<void> _edit(dynamic raw) async {
    final student = Map<String, dynamic>.from(raw as Map);
    final profile = Map<String, dynamic>.from(
      student['profile'] as Map? ?? const {},
    );
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _StudentEditor(student: student, profile: profile),
    );
    if (result == null) return;
    try {
      await widget.api.updateStudent(
        adminToken: widget.adminToken,
        id: int.parse(student['id'].toString()),
        value: result,
      );
      await _load();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> _delete(dynamic raw) async {
    final student = Map<String, dynamic>.from(raw as Map);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الطالب؟'),
        content: Text(
          'سيُحذف ${student['name']} ومحاولاته ونتائجه نهائيًا. لا يمكن التراجع عن ذلك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.deleteStudent(
        widget.adminToken,
        int.parse(student['id'].toString()),
      );
      await _load();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }
}

class _StudentEditor extends StatefulWidget {
  const _StudentEditor({required this.student, required this.profile});

  final Map<String, dynamic> student;
  final Map<String, dynamic> profile;

  @override
  State<_StudentEditor> createState() => _StudentEditorState();
}

class _StudentEditorState extends State<_StudentEditor> {
  late final Map<String, TextEditingController> fields;
  late String gender;

  @override
  void initState() {
    super.initState();
    fields = {
      'name': TextEditingController(text: widget.student['name']?.toString()),
      'fullName': TextEditingController(
        text: widget.profile['fullName']?.toString(),
      ),
      'country': TextEditingController(
        text: widget.profile['country']?.toString(),
      ),
      'city': TextEditingController(text: widget.profile['city']?.toString()),
      'ageRange': TextEditingController(
        text: widget.profile['ageRange']?.toString(),
      ),
      'education': TextEditingController(
        text: widget.profile['education']?.toString(),
      ),
      'contact': TextEditingController(
        text: widget.profile['contact']?.toString(),
      ),
      'about': TextEditingController(text: widget.profile['about']?.toString()),
      'reviewNote': TextEditingController(
        text: widget.student['reviewNote']?.toString(),
      ),
    };
    gender = widget.student['gender']?.toString() ?? '';
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تعديل ملف الطالب'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field('name', 'الاسم أو اللقب'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: gender,
              decoration: const InputDecoration(labelText: 'الجنس'),
              items: const [
                DropdownMenuItem(value: '', child: Text('لم يُفصح')),
                DropdownMenuItem(value: 'man', child: Text('رجل')),
                DropdownMenuItem(value: 'woman', child: Text('امرأة')),
              ],
              onChanged: (value) => gender = value ?? '',
            ),
            const SizedBox(height: 10),
            _field('fullName', 'الاسم الكامل'),
            const SizedBox(height: 10),
            _field('country', 'الدولة'),
            const SizedBox(height: 10),
            _field('city', 'المدينة'),
            const SizedBox(height: 10),
            _field('ageRange', 'الفئة العمرية'),
            const SizedBox(height: 10),
            _field('education', 'المستوى العلمي'),
            const SizedBox(height: 10),
            _field('contact', 'وسيلة التواصل'),
            const SizedBox(height: 10),
            _field('about', 'نبذة أو ملاحظة', lines: 3),
            const SizedBox(height: 10),
            _field('reviewNote', 'ملاحظة الشيخ'),
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
          if (fields['name']!.text.trim().length < 2) return;
          Navigator.pop(context, {
            'name': fields['name']!.text.trim(),
            'gender': gender,
            'profile': {
              for (final key in [
                'fullName',
                'country',
                'city',
                'ageRange',
                'education',
                'contact',
                'about',
              ])
                key: fields[key]!.text.trim(),
            },
            'reviewNote': fields['reviewNote']!.text.trim(),
          });
        },
        child: const Text('حفظ'),
      ),
    ],
  );

  Widget _field(String key, String label, {int lines = 1}) => TextField(
    controller: fields[key],
    minLines: lines,
    maxLines: lines == 1 ? 1 : 5,
    decoration: InputDecoration(labelText: label),
  );
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.student,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
  });

  final Map<String, dynamic> student;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(
      student['profile'] as Map? ?? const {},
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              student['name']?.toString() ?? 'طالب جديد',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            SelectableText(
              student['code']?.toString() ?? '',
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 8),
            Text(
              [
                    profile['fullName'],
                    profile['country'],
                    profile['city'],
                    profile['contact'],
                  ]
                  .where((value) => value?.toString().isNotEmpty == true)
                  .join(' · '),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check),
                  label: const Text('قبول'),
                ),
                OutlinedButton(onPressed: onEdit, child: const Text('تعديل')),
                TextButton(onPressed: onReject, child: const Text('رفض')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> student;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final assignments = List<dynamic>.from(
      student['assignments'] as List? ?? const [],
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Text((student['name']?.toString() ?? 'ط').characters.first),
        ),
        title: Text(
          student['name']?.toString() ?? 'طالب',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${student['code'] ?? ''} · ${assignments.length} امتحان',
          textDirection: TextDirection.rtl,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (assignments.isEmpty)
            const ListTile(title: Text('لا توجد امتحانات مرتبطة.'))
          else
            ...assignments.map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              final violation =
                  (item['violationType']?.toString() ?? '').isNotEmpty;
              final submitted = item['submittedAt'] != null;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item['examTitle']?.toString() ?? 'امتحان'),
                subtitle: Text(
                  violation
                      ? 'مخالفة نزاهة'
                      : submitted
                      ? 'تم التسليم'
                      : item['startedAt'] != null
                      ? 'قيد الحل'
                      : 'جاهز',
                ),
                trailing: submitted
                    ? Text(
                        '${item['score'] ?? 0} / ${item['maxScore'] ?? 0}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: violation
                              ? const Color(0xFFB3261E)
                              : const Color(0xFF123E59),
                        ),
                      )
                    : null,
              );
            }),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل الملف'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'حذف الطالب',
                color: const Color(0xFFB3261E),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.data});
  final Map? data;

  @override
  Widget build(BuildContext context) {
    final value = Map<String, dynamic>.from(data ?? const {});
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SmallStat('الطلاب', '${value['totalStudents'] ?? 0}'),
        _SmallStat('طلبات', '${value['pendingRequests'] ?? 0}'),
        _SmallStat('تسليمات', '${value['submitted'] ?? 0}'),
        _SmallStat('المتوسط', '${value['averagePercentage'] ?? 0}٪'),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: (MediaQuery.sizeOf(context).width - 56) / 2,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFDCE9EF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFF123E59),
          ),
        ),
        Text(label),
      ],
    ),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3D8),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(text),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text(text)),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard(this.text);
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
