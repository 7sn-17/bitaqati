import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/pro_providers.dart';
import '../../domain/freemium.dart';
import '../settings/developer_info_screen.dart';
import 'paywall_art.dart';

/// Opens the paywall.
///
/// [reason] is the sentence shown in the yellow strip at the top: the screen
/// is reached from five different dead ends, and a paywall that explains which
/// limit was just hit converts far better than one that only lists features.
Future<void> openPaywall(BuildContext context, {String? reason, int tab = 0}) {
  return context.push(
    '/paywall',
    extra: <String, Object?>{'reason': reason, 'tab': tab},
  );
}

/// The subscription screen.
///
/// This is a faithful implementation of the approved design: the values below
/// are the ones in the artboard (colours, radii, the 2px border with the thick
/// bottom lip, the 28px title, the Cairo type scale). It is deliberately
/// independent of [ThemePalette]: a paywall is a brand surface, and repainting
/// it Ocean blue would break the artwork it is built around.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({this.reason, this.initialTab = 0, super.key});

  /// Why the paywall opened, shown as a nudge above the title.
  final String? reason;

  /// 0 opens the plans, 1 opens the activation-code tab.
  final int initialTab;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  ProPlan _plan = ProPlan.yearly;
  int _method = 1;
  late int _tab = widget.initialTab == 1 ? 1 : 0;
  bool _busy = false;
  final TextEditingController _code = TextEditingController();
  String? _feedback;
  bool _feedbackOk = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  static const List<({String label, String note, PaywallArt art, Color bg})>
  _methods = <({String label, String note, PaywallArt art, Color bg})>[
    (
      label: 'نقداً',
      note: 'تنسيق عبر واتساب',
      art: PaywallArt.cash,
      bg: Color(0xFFFFF1C2),
    ),
    (
      label: 'شام كاش',
      note: 'تحويل إلكتروني',
      art: PaywallArt.wallet,
      bg: Color(0xFFDFF3E3),
    ),
    (
      label: 'عملات رقمية',
      note: 'عبر محفظتك',
      art: PaywallArt.crypto,
      bg: Color(0xFFDCEBFF),
    ),
  ];

  Future<void> _continue() async {
    final String method = _methods[_method].label;
    final String text =
        'مرحباً! أريد الاشتراك في بطاقتي Pro.\n'
        'الخطة: ${_plan.label} (\$${_plan.priceUsd}).\n'
        'طريقة الدفع: $method.\n'
        'أرجو إرسال كود التفعيل.';
    final Uri uri = Uri.parse(
      'https://wa.me/${DeveloperInfoScreen.whatsappNumber.replaceAll('+', '')}'
      '?text=${Uri.encodeComponent(text)}',
    );
    HapticFeedback.mediumImpact();
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      setState(() {
        _feedback =
            'تعذّر فتح واتساب. راسلنا على ${DeveloperInfoScreen.whatsappNumber}.';
        _feedbackOk = false;
      });
    }
  }

  Future<void> _activate() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _feedback = null;
    });
    final ActivationResult result = await ref
        .read(proServiceProvider)
        .activate(_code.text);
    if (!mounted) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _busy = false;
      _feedback = result.message;
      _feedbackOk = result.ok;
    });
    if (result.ok) {
      _code.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProStatus pro = ref.watch(proNowProvider);

    return Scaffold(
      backgroundColor: PaywallInk.page,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: <Widget>[
                _Header(
                  tab: _tab,
                  onTab: (int value) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _tab = value;
                      _feedback = null;
                    });
                  },
                  onClose: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 22),
                if (_tab == 0) ..._subscribeTab(pro) else ..._codeTab(pro),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- subscribe --

  List<Widget> _subscribeTab(ProStatus pro) {
    return <Widget>[
      if (widget.reason != null) ...<Widget>[
        _ReasonStrip(text: widget.reason!),
        const SizedBox(height: 22),
      ],
      const _MascotRow(),
      const SizedBox(height: 22),
      _Title(pro: pro),
      const SizedBox(height: 24),
      Column(
        children: <Widget>[
          for (final ProPlan plan in ProPlan.values) ...<Widget>[
            _PlanCard(
              plan: plan,
              selected: plan == _plan,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _plan = plan);
              },
            ),
            if (plan != ProPlan.values.last) const SizedBox(height: 18),
          ],
        ],
      ),
      const SizedBox(height: 22),
      const _SupportBanner(),
      const SizedBox(height: 22),
      _PaymentMethods(
        methods: _methods,
        selected: _method,
        onSelect: (int index) {
          HapticFeedback.selectionClick();
          setState(() => _method = index);
        },
      ),
      const SizedBox(height: 22),
      const _HowItWorks(),
      const SizedBox(height: 22),
      _CallToAction(plan: _plan, onTap: _continue),
      if (_feedback != null) ...<Widget>[
        const SizedBox(height: 14),
        _Feedback(text: _feedback!, ok: _feedbackOk),
      ],
      const SizedBox(height: 26),
      const _Comparison(),
    ];
  }

  // ------------------------------------------------------------------ code --

  List<Widget> _codeTab(ProStatus pro) {
    return <Widget>[
      const _MascotRow(),
      const SizedBox(height: 22),
      const _Title(pro: null),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: _toy(fill: PaywallInk.white, border: PaywallInk.border),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'أدخل كود التفعيل',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: PaywallInk.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'الكود يصلك على واتساب بعد تأكيد الدفع. يعمل مرة واحدة، ويضيف مدة الخطة إلى اشتراكك الحالي.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                height: 1.7,
                color: PaywallInk.muted,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: PaywallInk.ink,
              ),
              decoration: InputDecoration(
                hintText: 'BTQ-XXXX-XXXX',
                hintStyle: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: PaywallInk.muted.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: PaywallInk.greenSoft,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: PaywallInk.border,
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: PaywallInk.green,
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (_) => _activate(),
            ),
            const SizedBox(height: 14),
            _PrimaryButton(
              label: _busy ? 'جارٍ التحقق…' : 'تفعيل الكود',
              icon: _busy ? null : FontAwesomeIcons.unlock,
              onTap: _busy ? null : _activate,
            ),
            if (_feedback != null) ...<Widget>[
              const SizedBox(height: 14),
              _Feedback(text: _feedback!, ok: _feedbackOk),
            ],
          ],
        ),
      ),
      const SizedBox(height: 22),
      if (pro.active) _ActiveBadge(pro: pro),
      const _HowItWorks(),
    ];
  }
}

// ---------------------------------------------------------------- decorations

BoxDecoration _toy({
  required Color fill,
  required Color border,
  double radius = 20,
  double lip = 5,
}) {
  return paywallToyBox(fill: fill, border: border, radius: radius, lip: lip);
}

const TextStyle _titleStyle = TextStyle(
  fontFamily: 'Cairo',
  fontSize: 17,
  fontWeight: FontWeight.w800,
  color: PaywallInk.ink,
  height: 1.4,
);

const TextStyle _bodyStyle = TextStyle(
  fontFamily: 'Cairo',
  fontSize: 13,
  height: 1.75,
  color: PaywallInk.ink,
);

const TextStyle _noteStyle = TextStyle(
  fontFamily: 'Cairo',
  fontSize: 11.5,
  height: 1.5,
  color: PaywallInk.muted,
);

// -------------------------------------------------------------------- header

class _Header extends StatelessWidget {
  const _Header({
    required this.tab,
    required this.onTab,
    required this.onClose,
  });

  final int tab;
  final ValueChanged<int> onTab;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Semantics(
          button: true,
          label: 'إغلاق',
          child: InkResponse(
            onTap: onClose,
            radius: 24,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: FaIcon(
                  FontAwesomeIcons.xmark,
                  size: 18,
                  color: PaywallInk.ink,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: PaywallInk.chip,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                _Segment(
                  label: 'اشتراك',
                  active: tab == 0,
                  onTap: () => onTab(0),
                ),
                const SizedBox(width: 4),
                _Segment(
                  label: 'لدي كود تفعيل',
                  active: tab == 1,
                  onTap: () => onTab(1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: active
                ? const BoxDecoration(
                    color: PaywallInk.white,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: PaywallInk.border,
                        offset: Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
                  )
                : const BoxDecoration(color: Colors.transparent),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                color: active ? PaywallInk.ink : PaywallInk.muted,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- reason strip

class _ReasonStrip extends StatelessWidget {
  const _ReasonStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PaywallInk.yellowSoft,
        border: Border.all(color: PaywallInk.yellow, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          const FaIcon(
            FontAwesomeIcons.lock,
            size: 15,
            color: PaywallInk.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                height: 1.6,
                fontWeight: FontWeight.w700,
                color: PaywallInk.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- mascot

class _MascotRow extends StatelessWidget {
  const _MascotRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const SizedBox(
          width: 104,
          height: 104,
          child: CustomPaint(painter: MascotPainter()),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: _toy(
              fill: PaywallInk.white,
              border: PaywallInk.border,
              lip: 0,
            ),
            child: const Text(
              'مراجعة اليوم أسهل من تراكم الغد. خطوة صغيرة كل يوم تصنع الفرق!',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.7,
                color: PaywallInk.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- title

class _Title extends StatelessWidget {
  const _Title({required this.pro});

  final ProStatus? pro;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Directionality(
          textDirection: TextDirection.rtl,
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.4,
                color: PaywallInk.ink,
              ),
              children: <InlineSpan>[
                const TextSpan(text: 'افتح بطاقتي '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
                    decoration: BoxDecoration(
                      color: PaywallInk.yellow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Pro',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: PaywallInk.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          pro != null && pro!.active
              ? 'اشتراكك فعّال. تمديده يضيف المدة الجديدة فوق المتبقي.'
              : 'بلا حدود على المجموعات والبطاقات، ومزامنة كاملة.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            height: 1.7,
            color: PaywallInk.muted,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- plans

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final ProPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int? compareAt = plan.compareAtUsd;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: _toy(
          fill: selected ? PaywallInk.greenSoft : PaywallInk.white,
          border: selected ? PaywallInk.green : PaywallInk.border,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Row(
              children: <Widget>[
                _Radio(selected: selected),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        plan.label,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: PaywallInk.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(plan.tagline, style: _noteStyle),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '\$${plan.priceUsd}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: PaywallInk.ink,
                          height: 1.1,
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(text: plan.period),
                            if (compareAt != null)
                              TextSpan(
                                text: '  \$$compareAt',
                                style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: PaywallInk.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (plan == ProPlan.yearly)
              PositionedDirectional(
                top: -13,
                start: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: PaywallInk.yellow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'الأكثر اختياراً · وفر 50%',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: PaywallInk.ink,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: PaywallInk.green,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const FaIcon(
          FontAwesomeIcons.check,
          size: 11,
          color: PaywallInk.white,
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: PaywallInk.radioEmpty, width: 2),
      ),
    );
  }
}

// ---------------------------------------------------------------- support bar

class _SupportBanner extends StatelessWidget {
  const _SupportBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaywallInk.yellowSoft,
        border: Border.all(color: PaywallInk.yellow, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: FaIcon(
              FontAwesomeIcons.solidHeart,
              size: 22,
              color: PaywallInk.heart,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  height: 1.8,
                  color: PaywallInk.ink,
                ),
                children: <InlineSpan>[
                  TextSpan(
                    text: 'اشتراكك يدعم بطاقتي\n',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: 'هو ما يُبقي التطبيق مستمراً ويموّل الميزات الجديدة. شكراً لأنك جزء من هذه الرحلة.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ payment method

class _PaymentMethods extends StatelessWidget {
  const _PaymentMethods({
    required this.methods,
    required this.selected,
    required this.onSelect,
  });

  final List<({String label, String note, PaywallArt art, Color bg})> methods;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('اختر طريقة الدفع', style: _titleStyle),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int index = 0; index < methods.length; index++) ...<Widget>[
              Expanded(
                child: _MethodTile(
                  label: methods[index].label,
                  note: methods[index].note,
                  art: methods[index].art,
                  artBackground: methods[index].bg,
                  selected: index == selected,
                  onTap: () => onSelect(index),
                ),
              ),
              if (index != methods.length - 1) const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.label,
    required this.note,
    required this.art,
    required this.artBackground,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String note;
  final PaywallArt art;
  final Color artBackground;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
            decoration: _toy(
              fill: selected ? PaywallInk.greenSoft : PaywallInk.white,
              border: selected ? PaywallInk.green : PaywallInk.border,
              radius: 18,
              lip: 4,
            ),
            child: Column(
              children: <Widget>[
                Container(
                  width: 84,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: artBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SizedBox(
                    width: 72,
                    height: 48,
                    child: FittedBox(
                      child: SizedBox(
                        width: 96,
                        height: 64,
                        child: CustomPaint(painter: PaymentArtPainter(art)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: PaywallInk.ink,
                  ),
                ),
                Text(
                  note,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    height: 1.4,
                    color: PaywallInk.muted,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            PositionedDirectional(
              top: -9,
              end: -6,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: PaywallInk.green,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const FaIcon(
                  FontAwesomeIcons.check,
                  size: 10,
                  color: PaywallInk.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- how it works

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const List<String> _steps = <String>[
    'اختر الخطة وطريقة الدفع، ثم اضغط متابعة',
    'يفتح واتساب برسالة جاهزة، ندفع ونتفق على التفاصيل',
    'يصلك كود التفعيل، تدخله في تبويب «لدي كود» وتبدأ',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _toy(
        fill: PaywallInk.white,
        border: PaywallInk.border,
        lip: 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'كيف تتم العملية؟',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: PaywallInk.ink,
            ),
          ),
          const SizedBox(height: 12),
          for (int index = 0; index < _steps.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: PaywallInk.yellow,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: PaywallInk.ink,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_steps[index], style: _bodyStyle)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------- cta

class _CallToAction extends StatelessWidget {
  const _CallToAction({required this.plan, required this.onTap});

  final ProPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _PrimaryButton(
          label: 'متابعة عبر واتساب',
          icon: FontAwesomeIcons.whatsapp,
          onTap: onTap,
        ),
        const SizedBox(height: 10),
        Text(
          '\$${plan.priceUsd}.00 ${plan.period} · يعادل ${plan.perMonth} شهرياً',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            color: PaywallInk.muted,
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  // FaIconData, not IconData: font_awesome_flutter 11 ships its own icon type,
  // and every icon on this screen comes from that set.
  final FaIconData? icon;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: enabled ? PaywallInk.green : PaywallInk.radioEmpty,
            borderRadius: BorderRadius.circular(18),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: enabled ? PaywallInk.greenDark : PaywallInk.border,
                offset: const Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                FaIcon(icon, size: 21, color: PaywallInk.white),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: PaywallInk.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ feedback

class _Feedback extends StatelessWidget {
  const _Feedback({required this.text, required this.ok});

  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ok ? PaywallInk.greenSoft : const Color(0xFFFFEDED),
        border: Border.all(
          color: ok ? PaywallInk.green : const Color(0xFFE5484D),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12.5,
          height: 1.6,
          fontWeight: FontWeight.w700,
          color: ok ? PaywallInk.greenDark : const Color(0xFFA11B20),
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.pro});

  final ProStatus pro;

  @override
  Widget build(BuildContext context) {
    final int? days = pro.daysLeft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _toy(
        fill: PaywallInk.greenSoft,
        border: PaywallInk.green,
        lip: 0,
      ),
      child: Row(
        children: <Widget>[
          const FaIcon(
            FontAwesomeIcons.crown,
            size: 20,
            color: PaywallInk.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              days == null
                  ? 'أنت مشترك في Pro. شكراً لدعمك.'
                  : 'أنت مشترك في Pro. يتبقى $days يوماً.',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: PaywallInk.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- comparison

class _Comparison extends StatelessWidget {
  const _Comparison();

  static const List<({String feature, String free, String pro})>
  _rows = <({String feature, String free, String pro})>[
    (feature: 'المجموعات', free: '20 مجموعة', pro: 'غير محدود ∞'),
    (feature: 'البطاقات', free: '1000 بطاقة', pro: 'غير محدود ∞'),
    (
      feature: 'أوضاع الدراسة (Test, Write, Match)',
      free: '4 مرات لكل مجموعة',
      pro: 'غير محدود ∞',
    ),
    (
      feature: 'المزامنة السحابية',
      free: 'أحدث 5 مجموعات فقط',
      pro: 'جميع المجموعات',
    ),
    (
      feature: 'الثيمات',
      free: 'الثيم الافتراضي فقط (الغابة)',
      pro: 'المحيط، الغروب، الكلاسيك',
    ),
    (
      feature: 'التحليلات المتقدمة',
      free: 'غير متوفرة',
      pro: 'خريطة حرارية وتوقعات المراجعة',
    ),
    (feature: 'الاستيراد الذكي', free: '150 بطاقة شهرياً', pro: 'غير محدود ∞'),
    (feature: 'الوسائط', free: '50 صورة و 15 صوت', pro: 'غير محدود ∞'),
    (feature: 'تغطية الصور (Occlusion)', free: '5 بطاقات', pro: 'غير محدود ∞'),
    (feature: 'ملء الفراغات (Cloze)', free: '20 بطاقة', pro: 'غير محدود ∞'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'المجاني مقابل Pro',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: PaywallInk.ink,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: PaywallInk.white,
            border: Border.all(color: PaywallInk.border, width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              const _FeatureRow(
                feature: 'الميزة',
                free: 'المجاني',
                pro: 'Pro',
                header: true,
              ),
              for (final ({String feature, String free, String pro}) row
                  in _rows)
                _FeatureRow(
                  feature: row.feature,
                  free: row.free,
                  pro: row.pro,
                  header: false,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.feature,
    required this.free,
    required this.pro,
    required this.header,
  });

  final String feature;
  final String free;
  final String pro;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final TextStyle featureStyle = TextStyle(
      fontFamily: 'Cairo',
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: header ? PaywallInk.muted : PaywallInk.ink,
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: header ? 12 : 13),
      decoration: BoxDecoration(
        color: header ? PaywallInk.chip : PaywallInk.white,
        border: header
            ? null
            : const Border(top: BorderSide(color: PaywallInk.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(flex: 135, child: Text(feature, style: featureStyle)),
          const SizedBox(width: 8),
          Expanded(
            flex: 100,
            child: Text(
              free,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                height: 1.5,
                color: PaywallInk.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 100,
            child: Text(
              pro,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: PaywallInk.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
