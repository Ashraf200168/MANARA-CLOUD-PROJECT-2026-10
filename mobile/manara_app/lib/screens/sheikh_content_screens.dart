import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';

class SheikhBooksScreen extends StatefulWidget {
  const SheikhBooksScreen({
    super.key,
    required this.api,
    required this.adminToken,
  });
  final ApiClient api;
  final String adminToken;

  @override
  State<SheikhBooksScreen> createState() => _SheikhBooksScreenState();
}

class _SheikhBooksScreenState extends State<SheikhBooksScreen> {
  List<dynamic> items = const [];
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
      final value = await widget.api.adminBooks(widget.adminToken);
      if (mounted) setState(() => items = value);
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _OnlineAdminScaffold(
    title: 'إدارة الكتب',
    loading: loading,
    onRefresh: _load,
    action: FilledButton.icon(
      onPressed: loading ? null : _upload,
      icon: const Icon(Icons.upload_file_outlined),
      label: const Text('رفع PDF'),
    ),
    children: [
      if (error != null) _ErrorBox(error!),
      const _PageIntro(
        title: 'مكتبة البرنامج',
        subtitle:
            'تُرفع الكتب إلى التخزين السحابي ثم ينزّلها الطالب داخل التطبيق.',
      ),
      const SizedBox(height: 14),
      if (items.isEmpty)
        const _EmptyBox('لا توجد كتب.')
      else
        ...items.map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.picture_as_pdf)),
              title: Text(item['title']?.toString() ?? 'كتاب'),
              subtitle: Text(
                item['description']?.toString().isNotEmpty == true
                    ? item['description'].toString()
                    : item['original_name']?.toString() ?? '',
              ),
              trailing: IconButton(
                tooltip: 'حذف',
                color: const Color(0xFFB3261E),
                onPressed: () => _delete(item),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          );
        }),
    ],
  );

  Future<void> _upload() async {
    final selected = await FilePicker.pickFile(
      dialogTitle: 'اختر كتاب PDF',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (selected == null || !mounted) return;
    final title = TextEditingController(
      text: selected.name.replaceFirst(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      ),
    );
    final description = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بيانات الكتاب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'اسم الكتاب'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'وصف مختصر'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('رفع الكتاب'),
          ),
        ],
      ),
    );
    final bookTitle = title.text.trim();
    final bookDescription = description.text.trim();
    title.dispose();
    description.dispose();
    if (confirmed != true || bookTitle.isEmpty) return;
    setState(() => loading = true);
    try {
      final bytes = await selected.readAsBytes();
      await widget.api.uploadBook(
        adminToken: widget.adminToken,
        title: bookTitle,
        description: bookDescription,
        fileName: selected.name,
        bytes: bytes,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم رفع الكتاب.')));
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    if (!await _confirmAdmin(
      context,
      'حذف الكتاب؟',
      'سيُحذف ملف PDF من التخزين السحابي.',
    )) {
      return;
    }
    try {
      await widget.api.deleteBook(
        widget.adminToken,
        int.parse(item['id'].toString()),
      );
      await _load();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }
}

class SheikhAdviceScreen extends StatefulWidget {
  const SheikhAdviceScreen({
    super.key,
    required this.api,
    required this.adminToken,
  });
  final ApiClient api;
  final String adminToken;

  @override
  State<SheikhAdviceScreen> createState() => _SheikhAdviceScreenState();
}

class _SheikhAdviceScreenState extends State<SheikhAdviceScreen> {
  List<dynamic> items = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final value = await widget.api.adminAdvice(widget.adminToken);
      if (mounted) setState(() => items = value);
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _OnlineAdminScaffold(
    title: 'الفوائد والنصائح',
    loading: loading,
    onRefresh: _load,
    action: FilledButton.icon(
      onPressed: _add,
      icon: const Icon(Icons.add),
      label: const Text('إضافة'),
    ),
    children: [
      if (error != null) _ErrorBox(error!),
      const _PageIntro(
        title: 'فوائد الطلاب',
        subtitle: 'تظهر هذه النصوص في الصفحة الرئيسية وتُحفظ على جهاز الطالب.',
      ),
      const SizedBox(height: 14),
      if (items.isEmpty)
        const _EmptyBox('لا توجد فوائد.')
      else
        ...items.map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: Color(0xFFD9AA48)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['text']?.toString() ?? ''),
                        if ((item['author']?.toString() ?? '').isNotEmpty)
                          Text(
                            item['author'].toString(),
                            style: const TextStyle(color: Color(0xFF617986)),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    color: const Color(0xFFB3261E),
                    onPressed: () => _delete(item),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          );
        }),
    ],
  );

  Future<void> _add() async {
    final text = TextEditingController();
    final author = TextEditingController();
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة فائدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: text,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'نص الفائدة'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: author,
              decoration: const InputDecoration(labelText: 'المصدر أو القائل'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    final value = text.text.trim();
    final source = author.text.trim();
    text.dispose();
    author.dispose();
    if (yes != true || value.isEmpty) return;
    try {
      await widget.api.addAdvice(widget.adminToken, value, source);
      await _load();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    if (!await _confirmAdmin(
      context,
      'حذف الفائدة؟',
      'لن تظهر للطلاب بعد الحذف.',
    )) {
      return;
    }
    try {
      await widget.api.deleteAdvice(
        widget.adminToken,
        int.parse(item['id'].toString()),
      );
      await _load();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }
}

class SheikhTopicsScreen extends StatefulWidget {
  const SheikhTopicsScreen({
    super.key,
    required this.api,
    required this.adminToken,
  });
  final ApiClient api;
  final String adminToken;

  @override
  State<SheikhTopicsScreen> createState() => _SheikhTopicsScreenState();
}

class _SheikhTopicsScreenState extends State<SheikhTopicsScreen> {
  List<dynamic> items = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final value = await widget.api.adminTopics(widget.adminToken);
      if (mounted) setState(() => items = value);
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _OnlineAdminScaffold(
    title: 'أبواب الأسئلة',
    loading: loading,
    onRefresh: _load,
    action: FilledButton.icon(
      onPressed: () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('باب جديد'),
    ),
    children: [
      if (error != null) _ErrorBox(error!),
      const _PageIntro(
        title: 'تصنيف الأسئلة الشرعية',
        subtitle: 'ينتقي الطالب الباب المناسب قبل إرسال سؤاله بسرية.',
      ),
      const SizedBox(height: 14),
      if (items.isEmpty)
        const _EmptyBox('لا توجد أبواب.')
      else
        ...items.map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(item['icon']?.toString() ?? '◈'),
              ),
              title: Text(item['name']?.toString() ?? 'باب'),
              subtitle: Text(
                '${item['code'] ?? ''} · ${item['inquiry_count'] ?? 0} سؤال${item['active'] == false ? ' · متوقف' : ''}',
              ),
              onTap: () => _edit(item),
              trailing: IconButton(
                onPressed: (item['inquiry_count'] ?? 0) == 0
                    ? () => _delete(item)
                    : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          );
        }),
    ],
  );

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _TopicDialog(topic: item, next: items.length + 1),
    );
    if (value == null) return;
    try {
      if (item == null) {
        await widget.api.addTopic(widget.adminToken, value);
      } else {
        await widget.api.updateTopic(
          widget.adminToken,
          int.parse(item['id'].toString()),
          value,
        );
      }
      await _load();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    if (!await _confirmAdmin(
      context,
      'حذف الباب؟',
      'لا يمكن حذف باب مرتبط بأسئلة.',
    )) {
      return;
    }
    try {
      await widget.api.deleteTopic(
        widget.adminToken,
        int.parse(item['id'].toString()),
      );
      await _load();
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }
}

class _TopicDialog extends StatefulWidget {
  const _TopicDialog({required this.topic, required this.next});
  final Map<String, dynamic>? topic;
  final int next;

  @override
  State<_TopicDialog> createState() => _TopicDialogState();
}

class _TopicDialogState extends State<_TopicDialog> {
  late final TextEditingController name;
  late final TextEditingController code;
  late final TextEditingController icon;
  late final TextEditingController description;
  late final TextEditingController position;
  bool active = true;

  @override
  void initState() {
    super.initState();
    final item = widget.topic ?? const <String, dynamic>{};
    name = TextEditingController(text: item['name']?.toString());
    code = TextEditingController(text: item['code']?.toString());
    icon = TextEditingController(text: item['icon']?.toString() ?? '◈');
    description = TextEditingController(text: item['description']?.toString());
    position = TextEditingController(
      text: (item['position'] ?? widget.next).toString(),
    );
    active = item['active'] != false;
  }

  @override
  void dispose() {
    for (final controller in [name, code, icon, description, position]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.topic == null ? 'باب جديد' : 'تعديل الباب'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'اسم الباب'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: code,
            textDirection: TextDirection.ltr,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'رمز إنجليزي 2–6 أحرف',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: icon,
            decoration: const InputDecoration(labelText: 'الرمز الزخرفي'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: position,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الترتيب'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: description,
            decoration: const InputDecoration(labelText: 'وصف مختصر'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: active,
            onChanged: (value) => setState(() => active = value),
            title: const Text('إظهار الباب للطلاب'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          if (name.text.trim().isEmpty ||
              !RegExp(r'^[A-Za-z0-9]{2,6}$').hasMatch(code.text.trim())) {
            return;
          }
          Navigator.pop(context, {
            'name': name.text.trim(),
            'code': code.text.trim().toUpperCase(),
            'icon': icon.text.trim(),
            'position': int.tryParse(position.text) ?? widget.next,
            'description': description.text.trim(),
            'active': active,
          });
        },
        child: const Text('حفظ'),
      ),
    ],
  );
}

class SheikhQuestionBankScreen extends StatefulWidget {
  const SheikhQuestionBankScreen({
    super.key,
    required this.api,
    required this.adminToken,
  });
  final ApiClient api;
  final String adminToken;

  @override
  State<SheikhQuestionBankScreen> createState() =>
      _SheikhQuestionBankScreenState();
}

class _SheikhQuestionBankScreenState extends State<SheikhQuestionBankScreen> {
  Map<String, dynamic>? data;
  List<dynamic> books = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final values = await Future.wait<dynamic>([
        widget.api.adminQuestionBank(widget.adminToken),
        widget.api.adminBooks(widget.adminToken),
      ]);
      if (mounted) {
        setState(() {
          data = Map<String, dynamic>.from(values[0] as Map);
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
  Widget build(BuildContext context) {
    final value = data ?? const <String, dynamic>{};
    return _OnlineAdminScaffold(
      title: 'بنك الأسئلة',
      loading: loading,
      onRefresh: _load,
      action: FilledButton.icon(
        onPressed: data == null ? null : _create,
        icon: const Icon(Icons.casino_outlined),
        label: const Text('إنشاء امتحان'),
      ),
      children: [
        if (error != null) _ErrorBox(error!),
        const _PageIntro(
          title: 'إنشاء امتحان عشوائي',
          subtitle:
              'ينتقي الخادم أسئلة غير مكررة ويُنشئ الامتحان كمسودة أو منشور.',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Metric('إجمالي الأسئلة', '${value['total'] ?? 0}'),
            _Metric('اختيار متعدد', '${value['choice'] ?? 0}'),
            _Metric('صح أو خطأ', '${value['truefalse'] ?? 0}'),
            _Metric('المحاور', '${value['categoryCount'] ?? 0}'),
          ],
        ),
      ],
    );
  }

  Future<void> _create() async {
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _BankExamDialog(data: data!, books: books),
    );
    if (value == null) return;
    setState(() => loading = true);
    try {
      await widget.api.createExamFromBank(widget.adminToken, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء الامتحان من بنك الأسئلة.')),
        );
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class _BankExamDialog extends StatefulWidget {
  const _BankExamDialog({required this.data, required this.books});
  final Map<String, dynamic> data;
  final List<dynamic> books;

  @override
  State<_BankExamDialog> createState() => _BankExamDialogState();
}

class _BankExamDialogState extends State<_BankExamDialog> {
  static const _allCategories = '__all_categories__';
  static const _allDifficulties = '__all_difficulties__';
  static const _noBookId = -1;

  final title = TextEditingController(text: 'اختبار عشوائي من بنك الأسئلة');
  final count = TextEditingController(text: '50');
  final points = TextEditingController(text: '2');
  final duration = TextEditingController(text: '60');
  String category = _allCategories;
  String difficulty = _allDifficulties;
  int bookId = _noBookId;
  String status = 'draft';
  String accessMode = 'private';

  @override
  void dispose() {
    title.dispose();
    count.dispose();
    points.dispose();
    duration.dispose();
    super.dispose();
  }

  List<String> _values(String key, String name) =>
      List<dynamic>.from(widget.data[key] as List? ?? const [])
          .map(
            (raw) =>
                Map<String, dynamic>.from(raw as Map)[name]?.toString() ?? '',
          )
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('امتحان من البنك'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'العنوان'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: count,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'عدد الأسئلة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: points,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'درجة السؤال'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المدة بالدقائق'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: category,
              isExpanded: true,
              alignment: AlignmentDirectional.centerStart,
              decoration: const InputDecoration(labelText: 'المحور'),
              items: [
                const DropdownMenuItem<String>(
                  value: _allCategories,
                  child: Text('جميع المحاور'),
                ),
                ..._values('categories', 'category').map(
                  (v) => DropdownMenuItem<String>(
                    value: v,
                    child: Text(
                      v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) =>
                  setState(() => category = value ?? _allCategories),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: difficulty,
              isExpanded: true,
              alignment: AlignmentDirectional.centerStart,
              decoration: const InputDecoration(labelText: 'الصعوبة'),
              items: [
                const DropdownMenuItem<String>(
                  value: _allDifficulties,
                  child: Text('جميع المستويات'),
                ),
                ..._values('difficulties', 'difficulty').map(
                  (v) => DropdownMenuItem<String>(
                    value: v,
                    child: Text(
                      v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) =>
                  setState(() => difficulty = value ?? _allDifficulties),
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
                  final b = Map<String, dynamic>.from(raw as Map);
                  return DropdownMenuItem<int>(
                    value: int.parse(b['id'].toString()),
                    child: Text(
                      b['title']?.toString() ?? 'كتاب',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: (value) => setState(() => bookId = value ?? _noBookId),
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
              ],
              onChanged: (value) => setState(() => status = value ?? 'draft'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: accessMode,
              isExpanded: true,
              alignment: AlignmentDirectional.centerStart,
              decoration: const InputDecoration(labelText: 'طريقة الدخول'),
              items: const [
                DropdownMenuItem(value: 'private', child: Text('خاص للطلاب')),
                DropdownMenuItem(value: 'public', child: Text('مسابقة عامة')),
              ],
              onChanged: (value) =>
                  setState(() => accessMode = value ?? 'private'),
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
          Navigator.pop(context, {
            'title': title.text.trim(),
            'questionCount': int.tryParse(count.text) ?? 50,
            'pointsPerQuestion': double.tryParse(points.text) ?? 2,
            'durationMinutes': int.tryParse(duration.text) ?? 60,
            'bookId': bookId == _noBookId ? null : bookId,
            'category': category == _allCategories ? null : category,
            'difficulty': difficulty == _allDifficulties ? null : difficulty,
            'status': status,
            'accessMode': accessMode,
          });
        },
        child: const Text('إنشاء'),
      ),
    ],
  );
}

class SheikhSettingsScreen extends StatefulWidget {
  const SheikhSettingsScreen({
    super.key,
    required this.api,
    required this.adminToken,
  });
  final ApiClient api;
  final String adminToken;
  @override
  State<SheikhSettingsScreen> createState() => _SheikhSettingsScreenState();
}

class _SheikhSettingsScreenState extends State<SheikhSettingsScreen> {
  final fields = <String, TextEditingController>{};
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data = await widget.api.adminSettings(widget.adminToken);
      for (final key in [
        'sheikh_name',
        'page_title',
        'bio',
        'whatsapp',
        'telegram',
        'instagram',
        'welcome',
      ]) {
        fields.putIfAbsent(key, () => TextEditingController());
        fields[key]!.text = data[key]?.toString() ?? '';
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _OnlineAdminScaffold(
    title: 'بيانات الصفحة',
    loading: loading,
    onRefresh: _load,
    action: FilledButton.icon(
      onPressed: fields.isEmpty ? null : _save,
      icon: const Icon(Icons.save_outlined),
      label: const Text('حفظ'),
    ),
    children: [
      if (error != null) _ErrorBox(error!),
      const _PageIntro(
        title: 'هوية المنصة',
        subtitle: 'تظهر هذه البيانات في الموقع وتصل إلى التطبيق عند المزامنة.',
      ),
      const SizedBox(height: 14),
      if (fields.isNotEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _field('sheikh_name', 'اسم الشيخ'),
                const SizedBox(height: 10),
                _field('page_title', 'عنوان الصفحة'),
                const SizedBox(height: 10),
                _field('welcome', 'عبارة الترحيب', lines: 2),
                const SizedBox(height: 10),
                _field('bio', 'نبذة الصفحة', lines: 4),
                const SizedBox(height: 10),
                _field('whatsapp', 'واتساب'),
                const SizedBox(height: 10),
                _field('telegram', 'تلغرام'),
                const SizedBox(height: 10),
                _field('instagram', 'إنستغرام'),
              ],
            ),
          ),
        ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: _changePassword,
        icon: const Icon(Icons.password),
        label: const Text('تغيير كلمة مرور الشيخ'),
      ),
    ],
  );
  Widget _field(String key, String label, {int lines = 1}) => TextField(
    controller: fields[key],
    minLines: lines,
    maxLines: lines == 1 ? 1 : 6,
    decoration: InputDecoration(labelText: label),
  );
  Future<void> _save() async {
    setState(() => loading = true);
    try {
      await widget.api.updateSettings(widget.adminToken, {
        for (final e in fields.entries) e.key: e.value.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ بيانات الصفحة.')));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController(), next = TextEditingController();
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الحالية',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الجديدة — 10 أحرف على الأقل',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تغيير'),
          ),
        ],
      ),
    );
    final a = current.text, b = next.text;
    current.dispose();
    next.dispose();
    if (yes != true || b.length < 10) return;
    try {
      await widget.api.changeAdminPassword(widget.adminToken, a, b);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور.')));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }
}

class _OnlineAdminScaffold extends StatelessWidget {
  const _OnlineAdminScaffold({
    required this.title,
    required this.loading,
    required this.onRefresh,
    required this.children,
    this.action,
  });
  final String title;
  final bool loading;
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        IconButton(
          onPressed: loading ? null : onRefresh,
          icon: const Icon(Icons.sync_rounded),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          if (loading) const LinearProgressIndicator(),
          if (action != null) ...[
            Align(alignment: Alignment.centerRight, child: action!),
            const SizedBox(height: 16),
          ],
          ...children,
        ],
      ),
    ),
  );
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: Color(0xFF123E59),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: const TextStyle(color: Color(0xFF617986), height: 1.5),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label, value;
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
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xFF123E59),
          ),
        ),
        Text(label),
      ],
    ),
  );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Center(child: Text(text)),
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.text);
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

Future<bool> _confirmAdmin(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    ) ??
    false;
