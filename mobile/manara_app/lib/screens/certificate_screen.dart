import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class CertificateScreen extends StatefulWidget {
  const CertificateScreen({super.key, required this.certificate});

  final Map<String, dynamic> certificate;

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  static const _filesChannel = MethodChannel('com.manara.manara_app/files');

  final GlobalKey _certificateKey = GlobalKey();
  bool _saving = false;

  String _text(String key, [String fallback = '—']) {
    final value = widget.certificate[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  Future<void> _saveCertificate() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _certificateKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw StateError('تعذر تجهيز صورة الشهادة.');
      }

      final image = await boundary.toImage(pixelRatio: 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('تعذر تحويل الشهادة إلى صورة.');
      }

      final code = _safeFilePart(_text('certificateCode', 'certificate'));
      final student = _safeFilePart(_text('studentName', 'student'));
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      final location = await _filesChannel.invokeMethod<String>(
        'saveCertificate',
        <String, Object>{
          'bytes': Uint8List.fromList(bytes),
          'fileName': 'Manara-$student-$code.png',
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            location == null || location.isEmpty
                ? 'تم حفظ الشهادة في صور الجهاز.'
                : 'تم حفظ الشهادة في صور الجهاز بنجاح.',
          ),
          action: SnackBarAction(label: 'حسنًا', onPressed: () {}),
        ),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showError(error.message ?? 'تعذر حفظ الشهادة على الجهاز.');
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _safeFilePart(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return cleaned.isEmpty ? 'certificate' : cleaned;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شهادة التفوق'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _saveCertificate,
            tooltip: 'حفظ الشهادة كصورة',
            icon: _saving
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: RepaintBoundary(
                      key: _certificateKey,
                      child: _CertificateCanvas(
                        certificate: widget.certificate,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFDCE9EF))),
              ),
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveCertificate,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.image_outlined),
                label: Text(
                  _saving ? 'جارٍ تجهيز الشهادة…' : 'حفظ الشهادة في الصور',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificateCanvas extends StatelessWidget {
  const _CertificateCanvas({required this.certificate});

  final Map<String, dynamic> certificate;

  static const _navy = Color(0xFF1C4D5A);
  static const _gold = Color(0xFF9B7B37);
  static const _paleGold = Color(0xFFF4E8C8);
  static const _ivory = Color(0xFFFFFEFA);

  String _text(String key, [String fallback = '—']) {
    final value = certificate[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String get _score {
    final score = _text('score');
    final maxScore = _text('maxScore');
    return '$score من $maxScore';
  }

  String get _percentage {
    final raw = _text('percentage', '0').replaceAll('%', '');
    return '$raw٪';
  }

  String get _rank {
    final rank = _text('rank');
    final participants = _text('participants', '');
    if (rank == '—') return rank;
    return participants.isEmpty || participants == '0'
        ? rank
        : '$rank من $participants';
  }

  String get _issueDate {
    final raw = _text('issuedAt', _text('issuedDate', ''));
    if (raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}/$month/$day';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        width: 1120,
        height: 790,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _ivory,
            border: Border.all(color: _gold, width: 10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: _CertificateDecoration()),
              Positioned(
                left: 455,
                top: 205,
                child: Opacity(
                  opacity: 0.045,
                  child: Image.asset(
                    'assets/images/manara-icon.png',
                    width: 210,
                    height: 210,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(54, 40, 54, 34),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    Container(height: 2, color: _gold),
                    const SizedBox(height: 16),
                    const Text(
                      'شهادة تفوق وتميّز علمي',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 42,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'تتشرف إدارة برنامج القراءة الفردية بمنح هذه الشهادة إلى الطالب',
                      style: TextStyle(
                        color: Color(0xFF52636A),
                        fontSize: 21,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _text('studentName'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 43,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'لاجتيازه بنجاح الامتحان النهائي: «${_text('examTitle')}»',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 23,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricBox(label: 'الدرجة', value: _score),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricBox(
                            label: 'النسبة',
                            value: _percentage,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricBox(
                            label: 'التقدير',
                            value: _text('grade'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricBox(label: 'الترتيب', value: _rank),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'تقديرًا لاجتهاده وتميّزه، مع أطيب الأمنيات له بدوام التوفيق والارتقاء في مدارج العلم والعمل.',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF52636A),
                        fontSize: 19,
                        height: 1.45,
                      ),
                    ),
                    const Spacer(),
                    _buildFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/manara-icon.png',
          width: 92,
          height: 92,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text('programTitle', 'برنامج القراءة الفردية'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'العلم النافع يرفع صاحبه ويهدي عمله',
                style: TextStyle(
                  color: _gold,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: _paleGold.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'رمز الشهادة',
                style: TextStyle(color: Color(0xFF70664E), fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                _text('certificateCode'),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final sheikhName = _text('sheikhName', 'شيخ البرنامج');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _Signature(title: 'المشرف العلمي', value: sheikhName),
        const Spacer(),
        const Icon(Icons.workspace_premium_rounded, color: _gold, size: 52),
        const SizedBox(width: 12),
        const Text(
          'برنامج القراءة الفردية\nإدارة البرنامج',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _navy,
            height: 1.35,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        _Signature(title: 'تاريخ الإصدار', value: _issueDate),
      ],
    );
  }
}

class _CertificateDecoration extends StatelessWidget {
  const _CertificateDecoration();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CertificateDecorationPainter());
  }
}

class _CertificateDecorationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const navy = Color(0xFF1C4D5A);
    const gold = Color(0xFF9B7B37);
    final navyPaint = Paint()..color = navy.withValues(alpha: 0.07);
    final goldPaint = Paint()..color = gold.withValues(alpha: 0.12);
    final borderPaint = Paint()
      ..color = navy.withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(
      Rect.fromLTWH(22, 22, size.width - 44, size.height - 44),
      borderPaint,
    );
    canvas.drawCircle(Offset(size.width - 20, 18), 150, navyPaint);
    canvas.drawCircle(Offset(18, size.height - 16), 175, goldPaint);

    final accent = Paint()
      ..color = gold.withValues(alpha: 0.38)
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(32, 58), const Offset(160, 58), accent);
    canvas.drawLine(
      Offset(size.width - 160, size.height - 58),
      Offset(size.width - 32, size.height - 58),
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF4E8C8).withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFF9B7B37).withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF70664E),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1C4D5A),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Signature extends StatelessWidget {
  const _Signature({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 245,
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF70664E), fontSize: 14),
          ),
          const SizedBox(height: 7),
          Container(height: 1, color: const Color(0xFF9B7B37)),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1C4D5A),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
