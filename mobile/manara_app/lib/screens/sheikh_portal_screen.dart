import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'sheikh_book_roadmap_screen.dart';
import 'sheikh_content_screens.dart';
import 'sheikh_exams_screen.dart';
import 'sheikh_students_screen.dart';

class SheikhPortalScreen extends StatefulWidget {
  const SheikhPortalScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<SheikhPortalScreen> createState() => _SheikhPortalScreenState();
}

class _SheikhPortalScreenState extends State<SheikhPortalScreen> {
  final username = TextEditingController(text: 'sheikh');
  final password = TextEditingController();
  String adminToken = '';
  String adminName = '';
  String? error;
  bool loading = false;
  bool hidePassword = true;
  Map<String, dynamic>? dashboard;
  List<dynamic> inquiries = const [];
  List<dynamic> support = const [];

  bool get loggedIn => adminToken.isNotEmpty;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (username.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'اكتب اسم المستخدم وكلمة المرور.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.adminLogin(
        username.text.trim(),
        password.text,
      );
      final token = result['adminToken']?.toString() ?? '';
      if (token.isEmpty) throw const ApiException('لم تصل جلسة دخول صالحة.');
      adminToken = token;
      adminName = result['username']?.toString() ?? username.text.trim();
      password.clear();
      await _refresh(showSpinner: false);
    } on ApiException catch (exception) {
      error = exception.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _refresh({bool showSpinner = true}) async {
    if (!loggedIn) return;
    if (showSpinner) setState(() => loading = true);
    try {
      final values = await Future.wait<dynamic>([
        widget.api.adminDashboard(adminToken),
        widget.api.adminInquiries(adminToken),
        widget.api.adminSupport(adminToken),
      ]);
      if (!mounted) return;
      setState(() {
        dashboard = Map<String, dynamic>.from(values[0] as Map);
        inquiries = List<dynamic>.from(values[1] as List);
        support = List<dynamic>.from(values[2] as List);
        error = null;
      });
    } on ApiException catch (exception) {
      if (!mounted) return;
      if (exception.statusCode == 401) {
        setState(() {
          adminToken = '';
          dashboard = null;
          inquiries = const [];
          support = const [];
          error = 'انتهت جلسة الشيخ. سجّل الدخول من جديد.';
        });
      } else {
        setState(() => error = exception.message);
      }
    } finally {
      if (mounted && showSpinner) setState(() => loading = false);
    }
  }

  Future<void> _logout() async {
    final token = adminToken;
    setState(() {
      adminToken = '';
      dashboard = null;
      inquiries = const [];
      support = const [];
      error = null;
    });
    if (token.isNotEmpty) {
      try {
        await widget.api.adminLogout(token);
      } on ApiException {
        // The local session is already removed; remote expiry remains a fallback.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loggedIn) return _buildLogin();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('لوحة الشيخ', style: TextStyle(fontSize: 18)),
              Text(
                adminName,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 11, color: Color(0xFFBFD5E0)),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: loading ? null : _refresh,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded),
            ),
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFBFD5E0),
            indicatorColor: Color(0xFFD9AA48),
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'الملخص'),
              Tab(icon: Icon(Icons.question_answer_outlined), text: 'الأسئلة'),
              Tab(icon: Icon(Icons.support_agent_outlined), text: 'الدعم'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (error != null)
              Material(
                color: const Color(0xFFFFE9E6),
                child: ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.error_outline,
                    color: Color(0xFFB3261E),
                  ),
                  title: Text(error!),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _DashboardTab(
                    data: dashboard,
                    onRefresh: _refresh,
                    api: widget.api,
                    adminToken: adminToken,
                  ),
                  _InquiriesTab(
                    items: inquiries,
                    onRefresh: _refresh,
                    onAnswer: _answerInquiry,
                  ),
                  _SupportTab(
                    items: support,
                    onRefresh: _refresh,
                    onAnswer: _answerSupport,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogin() => Scaffold(
    appBar: AppBar(title: const Text('دخول الشيخ')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/manara-icon.png',
                            width: 82,
                            height: 82,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'لوحة الشيخ',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF123E59),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'دخول خاص لإدارة الأسئلة والدعم ومتابعة النتائج.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: username,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'اسم المستخدم',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        autofillHints: const [AutofillHints.password],
                        obscureText: hidePassword,
                        textDirection: TextDirection.ltr,
                        onSubmitted: (_) => loading ? null : _login(),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: hidePassword
                                ? 'إظهار كلمة المرور'
                                : 'إخفاء كلمة المرور',
                            onPressed: () =>
                                setState(() => hidePassword = !hidePassword),
                            icon: Icon(
                              hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: const TextStyle(color: Color(0xFFB3261E)),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: loading ? null : _login,
                        icon: loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('دخول آمن'),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'لا يحتفظ التطبيق بكلمة المرور، وتُغلق جلسة الشيخ عند إغلاق هذه الصفحة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF617986),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _answerInquiry(Map<String, dynamic> item) async {
    final answer = TextEditingController(text: item['answer']?.toString());
    var publish = item['publish_public'] == true;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('رد الشيخ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item['question']?.toString() ?? ''),
                const SizedBox(height: 14),
                TextField(
                  controller: answer,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: 'الجواب'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: publish,
                  onChanged: (value) =>
                      setDialogState(() => publish = value ?? false),
                  title: const Text('نشر السؤال والجواب دون هوية'),
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حفظ الرد'),
            ),
          ],
        ),
      ),
    );
    if (save != true || answer.text.trim().isEmpty) {
      answer.dispose();
      return;
    }
    try {
      await widget.api.answerInquiry(
        adminToken: adminToken,
        id: int.parse(item['id'].toString()),
        answer: answer.text.trim(),
        publishPublic: publish,
      );
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ جواب الشيخ.')));
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      answer.dispose();
    }
  }

  Future<void> _answerSupport(Map<String, dynamic> item) async {
    final reply = TextEditingController(text: item['reply']?.toString());
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رد الدعم الفني'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(item['message']?.toString() ?? ''),
              const SizedBox(height: 14),
              TextField(
                controller: reply,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(labelText: 'الرد'),
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
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حفظ الرد'),
          ),
        ],
      ),
    );
    if (save != true || reply.text.trim().isEmpty) {
      reply.dispose();
      return;
    }
    try {
      await widget.api.answerSupport(
        adminToken: adminToken,
        id: int.parse(item['id'].toString()),
        reply: reply.text.trim(),
        status: 'answered',
      );
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إرسال الرد للطالب.')));
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      reply.dispose();
    }
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    required this.data,
    required this.onRefresh,
    required this.api,
    required this.adminToken,
  });

  final Map<String, dynamic>? data;
  final Future<void> Function() onRefresh;
  final ApiClient api;
  final String adminToken;

  @override
  Widget build(BuildContext context) {
    final value = data;
    if (value == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final stats = <(String, String, IconData)>[
      ('الطلاب المقبولون', '${value['students'] ?? 0}', Icons.people_outline),
      ('طلبات التسجيل', '${value['registrations'] ?? 0}', Icons.person_add_alt),
      ('التسليمات', '${value['submissions'] ?? 0}', Icons.fact_check_outlined),
      (
        'مخالفات النزاهة',
        '${value['integrityViolations'] ?? 0}',
        Icons.gpp_bad_outlined,
      ),
      (
        'أسئلة بحاجة لرد',
        '${value['pending'] ?? 0}',
        Icons.question_answer_outlined,
      ),
      (
        'دعم بحاجة لرد',
        '${value['supportPending'] ?? 0}',
        Icons.support_agent_outlined,
      ),
    ];
    final recent = List<dynamic>.from(value['recent'] as List? ?? const []);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            'نظرة عامة',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF123E59),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.35,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: stats.length,
            itemBuilder: (context, index) {
              final stat = stats[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(stat.$3, color: const Color(0xFF246B89)),
                      Text(
                        stat.$2,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF123E59),
                        ),
                      ),
                      Text(
                        stat.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'إدارة المنصة',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF123E59),
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.45,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _AdminDestination(
                icon: Icons.people_alt_outlined,
                label: 'الطلاب',
                onTap: () => _open(
                  context,
                  SheikhStudentsScreen(api: api, adminToken: adminToken),
                ),
              ),
              _AdminDestination(
                icon: Icons.assignment_outlined,
                label: 'الامتحانات',
                onTap: () => _open(
                  context,
                  SheikhExamsScreen(api: api, adminToken: adminToken),
                ),
              ),
              _AdminDestination(
                icon: Icons.route_outlined,
                label: 'مسارات الكتب',
                onTap: () => _open(
                  context,
                  SheikhBookRoadmapsScreen(
                    api: api,
                    adminToken: adminToken,
                  ),
                ),
              ),
              _AdminDestination(
                icon: Icons.account_tree_outlined,
                label: 'بنك الأسئلة',
                onTap: () => _open(
                  context,
                  SheikhQuestionBankScreen(api: api, adminToken: adminToken),
                ),
              ),
              _AdminDestination(
                icon: Icons.menu_book_outlined,
                label: 'الكتب',
                onTap: () => _open(
                  context,
                  SheikhBooksScreen(api: api, adminToken: adminToken),
                ),
              ),
              _AdminDestination(
                icon: Icons.lightbulb_outline,
                label: 'الفوائد',
                onTap: () => _open(
                  context,
                  SheikhAdviceScreen(api: api, adminToken: adminToken),
                ),
              ),
              _AdminDestination(
                icon: Icons.category_outlined,
                label: 'أبواب الأسئلة',
                onTap: () => _open(
                  context,
                  SheikhTopicsScreen(api: api, adminToken: adminToken),
                ),
              ),
              _AdminDestination(
                icon: Icons.settings_outlined,
                label: 'بيانات الصفحة',
                onTap: () => _open(
                  context,
                  SheikhSettingsScreen(api: api, adminToken: adminToken),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'أحدث النتائج',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF123E59),
            ),
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            const _SheikhEmpty(text: 'لا توجد نتائج حتى الآن.')
          else
            ...recent.take(10).map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              final violation =
                  (item['violation_type']?.toString() ?? '').isNotEmpty;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: violation
                        ? const Color(0xFFFFE9E6)
                        : const Color(0xFFE6F6EF),
                    child: Icon(
                      violation ? Icons.warning_amber : Icons.check,
                      color: violation
                          ? const Color(0xFFB3261E)
                          : const Color(0xFF167451),
                    ),
                  ),
                  title: Text(item['name']?.toString() ?? 'طالب'),
                  subtitle: Text(item['title']?.toString() ?? 'امتحان'),
                  trailing: Text(
                    violation
                        ? 'مخالفة نزاهة'
                        : '${item['score'] ?? 0} / ${item['max_score'] ?? 0}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: violation
                          ? const Color(0xFFB3261E)
                          : const Color(0xFF123E59),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => page),
    ).then((_) => onRefresh());
  }
}

class _AdminDestination extends StatelessWidget {
  const _AdminDestination({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: const Color(0xFF246B89), size: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const Icon(
                  Icons.arrow_back_ios_new,
                  size: 15,
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _InquiriesTab extends StatelessWidget {
  const _InquiriesTab({
    required this.items,
    required this.onRefresh,
    required this.onAnswer,
  });

  final List<dynamic> items;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Map<String, dynamic>) onAnswer;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(18),
      children: [
        if (items.isEmpty)
          const _SheikhEmpty(text: 'لا توجد أسئلة واردة.')
        else
          ...items.map((raw) {
            final item = Map<String, dynamic>.from(raw as Map);
            final answered = item['status'] == 'answered';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatusBadge(
                          text: answered ? 'تمت الإجابة' : 'جديد',
                          success: answered,
                        ),
                        const Spacer(),
                        Text(item['topic_name']?.toString() ?? 'سؤال شرعي'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item['question']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.6,
                      ),
                    ),
                    if (answered) ...[
                      const Divider(height: 26),
                      Text(item['answer']?.toString() ?? ''),
                    ],
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => onAnswer(item),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: Text(answered ? 'تعديل الجواب' : 'كتابة الجواب'),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    ),
  );
}

class _SupportTab extends StatelessWidget {
  const _SupportTab({
    required this.items,
    required this.onRefresh,
    required this.onAnswer,
  });

  final List<dynamic> items;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Map<String, dynamic>) onAnswer;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(18),
      children: [
        if (items.isEmpty)
          const _SheikhEmpty(text: 'لا توجد طلبات دعم.')
        else
          ...items.map((raw) {
            final item = Map<String, dynamic>.from(raw as Map);
            final answered = item['status'] != 'new';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatusBadge(
                          text: answered ? 'تم الرد' : 'جديد',
                          success: answered,
                        ),
                        const Spacer(),
                        Text(item['student_name']?.toString() ?? 'طالب'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item['subject']?.toString() ?? 'مشكلة تقنية',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(item['message']?.toString() ?? ''),
                    if ((item['reply']?.toString() ?? '').isNotEmpty) ...[
                      const Divider(height: 26),
                      Text(item['reply'].toString()),
                    ],
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => onAnswer(item),
                      icon: const Icon(Icons.reply_rounded),
                      label: Text(answered ? 'تعديل الرد' : 'الرد على الطالب'),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.success});

  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: success ? const Color(0xFFE6F6EF) : const Color(0xFFFFF3D8),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: success ? const Color(0xFF167451) : const Color(0xFF8A5B00),
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    ),
  );
}

class _SheikhEmpty extends StatelessWidget {
  const _SheikhEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Center(child: Text(text)),
    ),
  );
}
