import 'package:flutter/material.dart';

import '../app_config.dart';
import '../app_controller.dart';
import '../services/api_client.dart';
import 'book_reader_screen.dart';
import 'certificate_screen.dart';
import 'exam_screen.dart';
import 'sheikh_portal_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_refresh);
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _showLogin() async {
    final field = TextEditingController(text: controller.store.studentCode);
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 46,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7E3E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  Text(
                    'دخول الطالب',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF123E59),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'أدخل معرّفك الدائم. يلزم الإنترنت عند تسجيل الدخول أول مرة.',
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: field,
                    textCapitalization: TextCapitalization.characters,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'معرّف الطالب',
                      hintText: 'ST-XXXX-XXXX-XXXX',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: const TextStyle(color: Color(0xFFB3261E)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: controller.syncing
                        ? null
                        : () async {
                            final result = await controller.login(field.text);
                            if (!sheetContext.mounted) return;
                            if (result == null) {
                              Navigator.pop(sheetContext);
                            } else {
                              setSheetState(() => error = result);
                            }
                          },
                    icon: controller.syncing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_rounded),
                    label: const Text('فتح صفحتي'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    field.dispose();
  }

  void _openSheikhPortal() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SheikhPortalScreen(api: controller.api),
      ),
    );
  }

  Future<void> _openStudentCenter(int initialIndex) async {
    if (!controller.loggedIn) {
      await _showLogin();
      if (!mounted || !controller.loggedIn) return;
    }
    final loggedOut = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => _StudentCenterScreen(
          controller: controller,
          initialIndex: initialIndex,
        ),
      ),
    );
    if (loggedOut == true && mounted) {
      setState(() => _tab = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(
        controller: controller,
        onLogin: _showLogin,
        onSheikhLogin: _openSheikhPortal,
        onOpenProfile: () => _openStudentCenter(0),
        onOpenResults: () => _openStudentCenter(1),
      ),
      _ExamsPage(controller: controller, onLogin: _showLogin),
      _LibraryPage(controller: controller),
      _AskSheikhPage(controller: controller),
      _SupportPage(controller: controller, onLogin: _showLogin),
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 10,
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/manara-icon.png',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      AppConfig.appName,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    'التطبيق الرسمي للبرنامج',
                    style: TextStyle(fontSize: 11, color: Color(0xFFBFD5E0)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'دخول الشيخ',
            onPressed: _openSheikhPortal,
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: controller.syncing ? null : controller.syncAll,
            icon: controller.syncing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _ConnectionStrip(controller: controller),
          Expanded(
            child: IndexedStack(index: _tab, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'الامتحانات',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'المكتبة',
          ),
          NavigationDestination(
            icon: Icon(Icons.question_answer_outlined),
            selectedIcon: Icon(Icons.question_answer),
            label: 'اسأل الشيخ',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent),
            label: 'الدعم',
          ),
        ],
      ),
    );
  }
}

class _ConnectionStrip extends StatelessWidget {
  const _ConnectionStrip({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final hasCache = controller.home != null || controller.profile != null;
    final online = controller.online;
    final color = online ? const Color(0xFF167451) : const Color(0xFF8A5B00);
    final background = online
        ? const Color(0xFFE6F6EF)
        : const Color(0xFFFFF3D8);
    final text = controller.syncing
        ? 'جارٍ مزامنة البيانات…'
        : online
        ? 'متصل — البيانات محدّثة'
        : hasCache
        ? 'دون اتصال — تعرض آخر بيانات محفوظة'
        : 'يلزم الاتصال لتحميل البيانات أول مرة';
    return Material(
      color: background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: controller.syncing
                    ? SizedBox.square(
                        key: const ValueKey('syncing'),
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: color,
                        ),
                      )
                    : Icon(
                        online
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        key: const ValueKey('connection'),
                        size: 18,
                        color: color,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      final state = context.findAncestorStateOfType<_AppShellState>();
      await state?.controller.syncAll();
    },
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(18),
      children: children,
    ),
  );
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.controller,
    required this.onLogin,
    required this.onSheikhLogin,
    required this.onOpenProfile,
    required this.onOpenResults,
  });
  final AppController controller;
  final VoidCallback onLogin;
  final VoidCallback onSheikhLogin;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenResults;

  @override
  Widget build(BuildContext context) {
    final settings = controller.home?['settings'] is Map
        ? Map<String, dynamic>.from(controller.home!['settings'] as Map)
        : <String, dynamic>{};
    final advice = controller.home?['advice'] is List
        ? List<dynamic>.from(controller.home!['advice'] as List)
        : const [];
    final student = controller.student;
    return _PageBody(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF123E59), Color(0xFF246B89)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/manara-icon.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                student == null
                    ? (settings['welcome']?.toString() ??
                          'مرحبًا بك في برنامج القراءة')
                    : 'أهلًا ${student['name']}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                student == null
                    ? 'محتوى محفوظ يبقى معك، واتصال عند الامتحان أو وصول رد جديد.'
                    : 'معرّفك: ${student['code']}',
                style: const TextStyle(color: Color(0xFFD9E8EF), height: 1.6),
              ),
              if (student == null) ...[
                const SizedBox(height: 18),
                FilledButton.tonalIcon(
                  onPressed: onLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('دخول الطالب'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onSheikhLogin,
          icon: const Icon(Icons.admin_panel_settings_outlined),
          label: const Text('دخول الشيخ'),
        ),
        if (controller.notice != null) ...[
          const SizedBox(height: 14),
          _InfoCard(
            icon: Icons.info_outline,
            title: 'ملاحظة الاتصال',
            body: controller.notice!,
          ),
        ],
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'متاح دون إنترنت',
          subtitle: 'بعد المزامنة الأولى تبقى هذه البيانات على جهازك',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FeatureTile(
                icon: Icons.person_outline,
                title: 'صفحتي',
                subtitle: student == null ? 'سجّل الدخول' : 'محفوظة',
                onTap: onOpenProfile,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FeatureTile(
                icon: Icons.history_edu_outlined,
                title: 'النتائج',
                subtitle: '${controller.assignments.length} امتحان',
                onTap: onOpenResults,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'فوائد ونصائح',
          subtitle: 'آخر ما تم حفظه من المنصة',
        ),
        const SizedBox(height: 12),
        if (advice.isEmpty)
          const _EmptyCard(text: 'اتصل بالإنترنت مرة واحدة لتحميل الفوائد.')
        else
          ...advice.take(5).map((item) {
            final value = Map<String, dynamic>.from(item as Map);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InfoCard(
                icon: Icons.lightbulb_outline_rounded,
                title: value['author']?.toString().isNotEmpty == true
                    ? value['author'].toString()
                    : 'فائدة',
                body: value['text']?.toString() ?? '',
              ),
            );
          }),
      ],
    );
  }
}

class _StudentCenterScreen extends StatefulWidget {
  const _StudentCenterScreen({
    required this.controller,
    required this.initialIndex,
  });

  final AppController controller;
  final int initialIndex;

  @override
  State<_StudentCenterScreen> createState() => _StudentCenterScreenState();
}

class _StudentCenterScreenState extends State<_StudentCenterScreen> {
  bool working = false;

  Future<void> _refresh() async {
    await widget.controller.syncAll();
    if (mounted) setState(() {});
  }

  Future<void> _edit() async {
    final student = widget.controller.student;
    if (student == null) return;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (context) => _StudentProfileEditor(student: student),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => working = true);
    final error = await widget.controller.updateStudentProfile(
      name: result['name']?.toString() ?? '',
      gender: result['gender']?.toString() ?? '',
      details: Map<String, dynamic>.from(result['profile'] as Map? ?? const {}),
    );
    if (!mounted) return;
    setState(() => working = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'تم حفظ معلومات صفحتك.'),
        backgroundColor: error == null ? const Color(0xFF167451) : null,
      ),
    );
  }

  Future<void> _logout() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text(
          'سيُحذف تسجيل الدخول والبيانات الخاصة المحفوظة على هذا الجهاز. يمكنك الدخول لاحقًا بمعرّفك الدائم.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => working = true);
    await widget.controller.logout();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.controller.student ?? <String, dynamic>{};
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialIndex.clamp(0, 1).toInt(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('صفحة الطالب'),
          actions: [
            IconButton(
              tooltip: 'تحديث البيانات',
              onPressed: working || widget.controller.syncing ? null : _refresh,
              icon: working || widget.controller.syncing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded),
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFFD9AA48),
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFBFD5E0),
            tabs: [
              Tab(icon: Icon(Icons.person_outline), text: 'معلوماتي'),
              Tab(icon: Icon(Icons.history_edu_outlined), text: 'نتائجي'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _StudentInfoTab(
              student: student,
              onRefresh: _refresh,
              onEdit: working ? null : _edit,
              onLogout: working ? null : _logout,
            ),
            _StudentResultsTab(
              controller: widget.controller,
              onRefresh: _refresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentInfoTab extends StatelessWidget {
  const _StudentInfoTab({
    required this.student,
    required this.onRefresh,
    required this.onEdit,
    required this.onLogout,
  });

  final Map<String, dynamic> student;
  final Future<void> Function() onRefresh;
  final VoidCallback? onEdit;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(
      student['profile'] as Map? ?? const {},
    );
    final rows = <(String, String)>[
      ('الاسم أو اللقب', student['name']?.toString() ?? ''),
      ('الاسم الكامل', profile['fullName']?.toString() ?? ''),
      (
        'الجنس',
        student['gender'] == 'man'
            ? 'رجل'
            : student['gender'] == 'woman'
            ? 'امرأة'
            : '',
      ),
      ('الدولة', profile['country']?.toString() ?? ''),
      ('المدينة', profile['city']?.toString() ?? ''),
      ('الفئة العمرية', profile['ageRange']?.toString() ?? ''),
      ('المستوى العلمي', profile['education']?.toString() ?? ''),
      ('وسيلة التواصل', profile['contact']?.toString() ?? ''),
      ('نبذة', profile['about']?.toString() ?? ''),
    ];
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF123E59), Color(0xFF246B89)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: Color(0xFFF1C965),
                  size: 30,
                ),
                const SizedBox(height: 16),
                Text(
                  student['name']?.toString() ?? 'طالب',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  student['code']?.toString() ?? '',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: Color(0xFFD9E8EF),
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  _StudentInfoRow(label: rows[index].$1, value: rows[index].$2),
                  if (index != rows.length - 1)
                    const Divider(height: 1, indent: 18, endIndent: 18),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('تعديل معلوماتي'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StudentInfoRow extends StatelessWidget {
  const _StudentInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF617986),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value.trim().isEmpty ? 'غير مضاف' : value,
            style: const TextStyle(
              color: Color(0xFF123E59),
              fontWeight: FontWeight.w800,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StudentResultsTab extends StatelessWidget {
  const _StudentResultsTab({required this.controller, required this.onRefresh});

  final AppController controller;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final assignments = controller.assignments.reversed.toList();
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          const _SectionTitle(
            title: 'امتحاناتي ونتائجي',
            subtitle: 'اسحب للأسفل لتحديث آخر الامتحانات والدرجات',
          ),
          const SizedBox(height: 16),
          if (assignments.isEmpty)
            const _EmptyCard(text: 'لا يوجد امتحان مرتبط بصفحتك حاليًا.')
          else
            ...assignments.map(
              (raw) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ExamCard(
                  controller: controller,
                  data: Map<String, dynamic>.from(raw as Map),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudentProfileEditor extends StatefulWidget {
  const _StudentProfileEditor({required this.student});

  final Map<String, dynamic> student;

  @override
  State<_StudentProfileEditor> createState() => _StudentProfileEditorState();
}

class _StudentProfileEditorState extends State<_StudentProfileEditor> {
  final formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  late String gender;

  @override
  void initState() {
    super.initState();
    final profile = Map<String, dynamic>.from(
      widget.student['profile'] as Map? ?? const {},
    );
    fields = {
      'name': TextEditingController(text: widget.student['name']?.toString()),
      for (final key in const [
        'fullName',
        'country',
        'city',
        'ageRange',
        'education',
        'contact',
        'about',
      ])
        key: TextEditingController(text: profile[key]?.toString()),
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

  Widget _field(
    String key,
    String label, {
    int lines = 1,
    TextInputType? keyboardType,
  }) => TextFormField(
    controller: fields[key],
    maxLines: lines,
    keyboardType: keyboardType,
    textInputAction: lines == 1
        ? TextInputAction.next
        : TextInputAction.newline,
    decoration: InputDecoration(labelText: label),
    validator: key == 'name'
        ? (value) {
            final length = value?.trim().length ?? 0;
            if (length < 2 || length > 80) {
              return 'اكتب اسمًا أو لقبًا بين حرفين و80 حرفًا';
            }
            return null;
          }
        : null,
  );

  void _save() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, <String, dynamic>{
      'name': fields['name']!.text.trim(),
      'gender': gender,
      'profile': {
        for (final key in const [
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
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تعديل معلوماتي')),
    body: SafeArea(
      child: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const _InfoCard(
              icon: Icons.privacy_tip_outlined,
              title: 'معلومات صفحتك',
              body:
                  'يمكنك تحديث معلوماتك الشخصية. يبقى معرّف الطالب وحالة الحساب تحت إدارة الشيخ.',
            ),
            const SizedBox(height: 16),
            _field('name', 'الاسم أو اللقب'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: gender,
              decoration: const InputDecoration(labelText: 'الجنس'),
              items: const [
                DropdownMenuItem(value: '', child: Text('لم يُذكر')),
                DropdownMenuItem(value: 'man', child: Text('رجل')),
                DropdownMenuItem(value: 'woman', child: Text('امرأة')),
              ],
              onChanged: (value) => setState(() => gender = value ?? ''),
            ),
            const SizedBox(height: 12),
            _field('fullName', 'الاسم الكامل'),
            const SizedBox(height: 12),
            _field('country', 'الدولة'),
            const SizedBox(height: 12),
            _field('city', 'المدينة'),
            const SizedBox(height: 12),
            _field('ageRange', 'الفئة العمرية'),
            const SizedBox(height: 12),
            _field('education', 'المستوى العلمي'),
            const SizedBox(height: 12),
            _field(
              'contact',
              'وسيلة التواصل',
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            _field('about', 'نبذة أو ملاحظة', lines: 4),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ التعديلات'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

class _ExamsPage extends StatelessWidget {
  const _ExamsPage({required this.controller, required this.onLogin});
  final AppController controller;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    if (!controller.loggedIn) {
      return _PageBody(
        children: [
          const _SectionTitle(
            title: 'امتحاناتي ونتائجي',
            subtitle: 'تحتاج إلى معرّف الطالب لعرض الامتحانات الخاصة بك',
          ),
          const SizedBox(height: 18),
          _LoginRequired(onLogin: onLogin),
        ],
      );
    }
    final assignments = controller.assignments.reversed.toList();
    return _PageBody(
      children: [
        const _SectionTitle(
          title: 'امتحاناتي ونتائجي',
          subtitle: 'تُحفظ القائمة والنتائج الأخيرة على الجهاز',
        ),
        const SizedBox(height: 16),
        if (assignments.isEmpty)
          const _EmptyCard(text: 'لا يوجد امتحان مرتبط بصفحتك حاليًا.')
        else
          ...assignments.map(
            (raw) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ExamCard(
                controller: controller,
                data: Map<String, dynamic>.from(raw as Map),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.controller, required this.data});
  final AppController controller;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final submitted = data['submitted_at'] != null;
    final violation = (data['violation_type']?.toString() ?? '').isNotEmpty;
    final state = data['state']?.toString() ?? '';
    final review = data['reviewAvailable'] == true;
    final certificate = data['certificateAvailable'] == true;
    final stateText = submitted
        ? (violation ? 'مخالفة نزاهة' : 'تم التسليم')
        : state == 'open'
        ? 'متاح الآن'
        : state == 'upcoming'
        ? 'قادم'
        : 'انتهى';
    final stateColor = violation
        ? const Color(0xFFB3261E)
        : submitted
        ? const Color(0xFF167451)
        : const Color(0xFF8A5B00);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    stateText,
                    style: TextStyle(
                      color: stateColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${data['duration_minutes'] ?? '—'} دقيقة',
                  style: const TextStyle(color: Color(0xFF617986)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              data['title']?.toString() ?? 'امتحان',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF123E59),
              ),
            ),
            if (data['book_title'] != null) ...[
              const SizedBox(height: 6),
              Text(
                data['book_title'].toString(),
                style: const TextStyle(color: Color(0xFF617986)),
              ),
            ],
            if (submitted && !violation) ...[
              const SizedBox(height: 14),
              Text(
                'النتيجة: ${data['score'] ?? '—'} من ${data['max_score'] ?? '—'}  (${data['percentage'] ?? '—'}٪)',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
            const SizedBox(height: 16),
            if (!submitted && state == 'open')
              FilledButton.icon(
                onPressed: () => _start(context),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('بدء الامتحان'),
              )
            else if (submitted) ...[
              if (review)
                OutlinedButton.icon(
                  onPressed: () => _review(context),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('مراجعة الإجابات'),
                )
              else
                const Text(
                  'ستتاح مراجعة الإجابات بعد اكتمال مدة محاولتك.',
                  style: TextStyle(color: Color(0xFF617986)),
                ),
              if (certificate) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => _certificate(context),
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: const Text('عرض شهادة التفوق'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9B7B37),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context) async {
    if (!controller.online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يلزم اتصال ثابت بالإنترنت لبدء الامتحان.'),
        ),
      );
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قبل بدء الامتحان'),
        content: const Text(
          'أتعهد أن أجيب بنفسي. يجب إبقاء الاتصال متاحًا عند بدء الامتحان وتسليمه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('أتعهد وأبدأ'),
          ),
        ],
      ),
    );
    if (approved != true || !context.mounted) return;
    try {
      final examId = int.parse(data['exam_id'].toString());
      final payload = await controller.startExam(examId);
      if (!context.mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ExamScreen(
            controller: controller,
            examId: examId,
            payload: payload,
          ),
        ),
      );
      await controller.syncAll();
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _review(BuildContext context) async {
    try {
      final data = await controller.reviewExam(
        int.parse(this.data['exam_id'].toString()),
      );
      if (!context.mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => _ReviewPage(data: data)),
      );
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _certificate(BuildContext context) async {
    try {
      final certificate = await controller.examCertificate(
        int.parse(data['exam_id'].toString()),
      );
      if (!context.mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CertificateScreen(certificate: certificate),
        ),
      );
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _LibraryPage extends StatelessWidget {
  const _LibraryPage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final books = controller.home?['books'] is List
        ? List<dynamic>.from(controller.home!['books'] as List)
        : const [];
    return _PageBody(
      children: [
        const _SectionTitle(
          title: 'المكتبة',
          subtitle: 'نزّل الكتاب مرة واحدة ثم اقرأه داخل التطبيق دون إنترنت',
        ),
        const SizedBox(height: 16),
        if (books.isEmpty)
          const _EmptyCard(
            text: 'لا توجد كتب محفوظة بعد. اتصل بالإنترنت وحدّث الصفحة.',
          )
        else
          ...books.map((raw) {
            final book = Map<String, dynamic>.from(raw as Map);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BookCard(controller: controller, book: book),
            );
          }),
      ],
    );
  }
}

class _BookCard extends StatefulWidget {
  const _BookCard({required this.controller, required this.book});
  final AppController controller;
  final Map<String, dynamic> book;

  @override
  State<_BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<_BookCard> {
  bool checking = true;
  bool downloading = false;
  String? path;
  int received = 0;
  int total = 0;

  int get bookId => int.parse(widget.book['id'].toString());
  String get title => widget.book['title']?.toString() ?? 'كتاب';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final value = await widget.controller.books.localPath(bookId);
    if (mounted) {
      setState(() {
        path = value;
        checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = path != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFFFF0C5),
                  child: Icon(Icons.menu_book, color: Color(0xFF8A5B00)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.book['description']?.toString() ??
                            'من مكتبة البرنامج',
                        style: const TextStyle(color: Color(0xFF617986)),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (downloading) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: total > 0 ? received / total : null,
              ),
              const SizedBox(height: 6),
              Text(
                total > 0
                    ? 'جارٍ التنزيل ${((received / total) * 100).round()}٪'
                    : 'جارٍ تنزيل الكتاب…',
                style: const TextStyle(fontSize: 12, color: Color(0xFF617986)),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: checking || downloading
                        ? null
                        : available
                        ? _open
                        : _download,
                    icon: Icon(
                      available
                          ? Icons.chrome_reader_mode
                          : Icons.download_rounded,
                    ),
                    label: Text(
                      available ? 'قراءة دون إنترنت' : 'تنزيل الكتاب',
                    ),
                  ),
                ),
                if (available) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'حذف النسخة المحفوظة',
                    onPressed: downloading ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open() async {
    final localPath = path;
    if (localPath == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BookReaderScreen(title: title, path: localPath),
      ),
    );
  }

  Future<void> _download() async {
    if (!widget.controller.online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اتصل بالإنترنت لتنزيل الكتاب أول مرة.')),
      );
      return;
    }
    setState(() {
      downloading = true;
      received = 0;
      total = 0;
    });
    try {
      final url = await widget.controller.api.bookUrl(bookId);
      if (url.isEmpty) throw const ApiException('لم يصل رابط تنزيل صالح.');
      final localPath = await widget.controller.books.download(
        bookId: bookId,
        url: url,
        onProgress: (value, maximum) {
          if (mounted) {
            setState(() {
              received = value;
              total = maximum;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() {
        path = localPath;
        downloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الكتاب للقراءة دون إنترنت.')),
      );
      await _open();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => downloading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الكتاب من الجهاز؟'),
        content: const Text('يمكنك تنزيله مرة أخرى لاحقًا من مكتبة البرنامج.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.books.delete(bookId);
    if (mounted) setState(() => path = null);
  }
}

class _AskSheikhPage extends StatefulWidget {
  const _AskSheikhPage({required this.controller});
  final AppController controller;

  @override
  State<_AskSheikhPage> createState() => _AskSheikhPageState();
}

class _AskSheikhPageState extends State<_AskSheikhPage> {
  final question = TextEditingController();
  int? topicId;
  String gender = 'man';
  bool sending = false;

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topics = widget.controller.home?['topics'] is List
        ? List<dynamic>.from(widget.controller.home!['topics'] as List)
        : const [];
    final publicAnswers = widget.controller.home?['answers'] is List
        ? List<dynamic>.from(widget.controller.home!['answers'] as List)
        : const [];
    return _PageBody(
      children: [
        const _SectionTitle(
          title: 'اسأل الشيخ',
          subtitle: 'أرسل سؤالك بسرية واحفظ رمزه، وسيظهر الرد داخل التطبيق',
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  initialValue: topicId,
                  decoration: const InputDecoration(labelText: 'باب السؤال'),
                  items: topics.map((raw) {
                    final topic = Map<String, dynamic>.from(raw as Map);
                    return DropdownMenuItem<int>(
                      value: int.parse(topic['id'].toString()),
                      child: Text(
                        '${topic['icon'] ?? '◈'} ${topic['name'] ?? ''}',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => topicId = value),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'man',
                      label: Text('رجل'),
                      icon: Icon(Icons.man),
                    ),
                    ButtonSegment(
                      value: 'woman',
                      label: Text('امرأة'),
                      icon: Icon(Icons.woman),
                    ),
                  ],
                  selected: {gender},
                  onSelectionChanged: (value) =>
                      setState(() => gender = value.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: question,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'اكتب سؤالك',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: sending || !widget.controller.online
                        ? null
                        : () => _send(topics),
                    icon: sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      widget.controller.online
                          ? 'إرسال السؤال'
                          : 'اتصل بالإنترنت للإرسال',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'أسئلتي وردودها',
          subtitle: 'تظل آخر الردود محفوظة على هذا الجهاز',
        ),
        const SizedBox(height: 12),
        if (widget.controller.inquiries.isEmpty)
          const _EmptyCard(text: 'لم ترسل سؤالًا من هذا الجهاز بعد.')
        else
          ...widget.controller.inquiries.map((raw) {
            final item = Map<String, dynamic>.from(raw as Map);
            final answer = item['answer']?.toString() ?? '';
            final answered = answer.isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['topic_name']?.toString() ?? 'سؤال شرعي',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            answered ? 'تم الرد' : 'بانتظار الرد',
                            style: TextStyle(
                              color: answered
                                  ? const Color(0xFF167451)
                                  : const Color(0xFF8A5B00),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        'الرمز: ${item['public_code'] ?? item['code'] ?? '—'}',
                        textDirection: TextDirection.ltr,
                      ),
                      const SizedBox(height: 10),
                      Text(item['question']?.toString() ?? ''),
                      if (answered) ...[
                        const Divider(height: 28),
                        const Text(
                          'جواب الشيخ',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF123E59),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(answer, style: const TextStyle(height: 1.65)),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        if (publicAnswers.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _SectionTitle(
            title: 'إجابات منشورة',
            subtitle: 'مختارات عامة من أسئلة البرنامج',
          ),
          const SizedBox(height: 12),
          ...publicAnswers.take(8).map((raw) {
            final item = Map<String, dynamic>.from(raw as Map);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                backgroundColor: Colors.white,
                collapsedBackgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: Text(
                  item['question']?.toString() ?? 'سؤال',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(item['topic_name']?.toString() ?? ''),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      item['answer']?.toString() ?? '',
                      style: const TextStyle(height: 1.65),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Future<void> _send(List<dynamic> topics) async {
    final selectedId = topicId;
    if (selectedId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اختر باب السؤال أولًا.')));
      return;
    }
    if (question.text.trim().length < 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اكتب سؤالًا أوضح.')));
      return;
    }
    final selected = topics
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .firstWhere((item) => int.parse(item['id'].toString()) == selectedId);
    setState(() => sending = true);
    final error = await widget.controller.sendInquiry(
      topicId: selectedId,
      topicName: selected['name']?.toString() ?? 'سؤال شرعي',
      gender: gender,
      question: question.text.trim(),
    );
    if (!mounted) return;
    setState(() => sending = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final code =
        widget.controller.inquiries.first['public_code']?.toString() ?? '';
    question.clear();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.mark_email_read_outlined,
          color: Color(0xFF167451),
          size: 48,
        ),
        title: const Text('تم إرسال السؤال بسرية'),
        content: SelectableText(
          'رمز المتابعة: $code\nسيظهر جواب الشيخ هنا بعد الرد.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
  }
}

class _SupportPage extends StatefulWidget {
  const _SupportPage({required this.controller, required this.onLogin});
  final AppController controller;
  final VoidCallback onLogin;

  @override
  State<_SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<_SupportPage> {
  final subject = TextEditingController();
  final message = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.loggedIn) {
      return _PageBody(
        children: [
          const _SectionTitle(
            title: 'الدعم الفني',
            subtitle: 'تابع رد الشيخ أو الداعم داخل التطبيق',
          ),
          const SizedBox(height: 18),
          _LoginRequired(onLogin: widget.onLogin),
        ],
      );
    }
    return _PageBody(
      children: [
        const _SectionTitle(
          title: 'الدعم الفني',
          subtitle:
              'الردود السابقة متاحة دون اتصال؛ الإرسال والتحديث يحتاجان الإنترنت',
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                TextField(
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'عنوان المشكلة'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: message,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'اشرح المشكلة بوضوح',
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: sending || !widget.controller.online
                      ? null
                      : _send,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(
                    widget.controller.online
                        ? 'إرسال إلى الدعم'
                        : 'اتصل بالإنترنت للإرسال',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'طلباتي السابقة',
          subtitle: 'تُعرض آخر نسخة محفوظة على الجهاز',
        ),
        const SizedBox(height: 12),
        if (widget.controller.tickets.isEmpty)
          const _EmptyCard(text: 'لا توجد طلبات دعم سابقة.')
        else
          ...widget.controller.tickets.map((raw) {
            final ticket = Map<String, dynamic>.from(raw as Map);
            final answered = (ticket['reply']?.toString() ?? '').isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ticket['subject']?.toString() ?? 'مشكلة تقنية',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            answered ? 'تم الرد' : 'بانتظار الرد',
                            style: TextStyle(
                              color: answered
                                  ? const Color(0xFF167451)
                                  : const Color(0xFF8A5B00),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(ticket['message']?.toString() ?? ''),
                      if (answered) ...[
                        const Divider(height: 28),
                        const Text(
                          'الرد',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF123E59),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(ticket['reply'].toString()),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _send() async {
    if (message.text.trim().length < 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اكتب وصفًا أوضح للمشكلة.')));
      return;
    }
    setState(() => sending = true);
    final error = await widget.controller.sendSupport(
      subject.text.trim(),
      message.text.trim(),
    );
    if (!mounted) return;
    setState(() => sending = false);
    if (error == null) {
      subject.clear();
      message.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إرسال المشكلة بنجاح.')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

class _ReviewPage extends StatelessWidget {
  const _ReviewPage({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final exam = Map<String, dynamic>.from(data['exam'] as Map? ?? const {});
    final result = Map<String, dynamic>.from(
      data['result'] as Map? ?? const {},
    );
    final questions = List<dynamic>.from(
      data['questions'] as List? ?? const [],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة الإجابات')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _InfoCard(
            icon: Icons.fact_check_outlined,
            title: exam['title']?.toString() ?? 'الامتحان',
            body:
                'النتيجة: ${result['score'] ?? 0} من ${result['maxScore'] ?? 0}',
          ),
          const SizedBox(height: 16),
          ...questions.map((raw) {
            final q = Map<String, dynamic>.from(raw as Map);
            final correct = q['correct'] == true;
            final student = q['studentAnswer'] is Map
                ? Map<String, dynamic>.from(q['studentAnswer'] as Map)
                : const <String, dynamic>{};
            final answer = q['correctAnswer'] is Map
                ? Map<String, dynamic>.from(q['correctAnswer'] as Map)
                : const <String, dynamic>{};
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        correct ? '✓ إجابة صحيحة' : '× إجابة غير صحيحة',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: correct
                              ? const Color(0xFF167451)
                              : const Color(0xFFB3261E),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        q['prompt']?.toString() ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const Divider(height: 26),
                      Text('إجابتك: ${student['label'] ?? 'لم تُجب'}'),
                      const SizedBox(height: 6),
                      Text(
                        'الإجابة الصحيحة: ${answer['label'] ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if ((q['explanation']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('التوضيح: ${q['explanation']}'),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: const Color(0xFF123E59),
          fontWeight: FontWeight.w900,
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE4F1F6),
            child: Icon(icon, color: const Color(0xFF123E59)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF123E59),
                  ),
                ),
                const SizedBox(height: 5),
                Text(body, style: const TextStyle(height: 1.55)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title، $subtitle',
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDCE9EF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF246B89)),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFF8AA2AE),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF617986), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFDCE9EF)),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xFF617986), height: 1.6),
    ),
  );
}

class _LoginRequired extends StatelessWidget {
  const _LoginRequired({required this.onLogin});
  final VoidCallback onLogin;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.lock_person_outlined,
            size: 46,
            color: Color(0xFF246B89),
          ),
          const SizedBox(height: 14),
          const Text(
            'سجّل الدخول بمعرّفك الدائم لعرض هذه الصفحة.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onLogin,
            icon: const Icon(Icons.login),
            label: const Text('دخول الطالب'),
          ),
        ],
      ),
    ),
  );
}
