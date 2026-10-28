import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/arabic_date.dart';
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
/// are the ones in the artboard (radii, the 2px border with the thick bottom
/// lip, the 28px title, the Cairo type scale). Only the *colours* come from
/// the theme, through [PaywallInk]: the design's fixed greens survive as
/// relationships — page, card, ink, muted, action, action depth, soft wash,
/// highlight — so the screen keeps its character in light and dark and in all
/// four palettes, instead of punching a bright hole in a dark app.
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
  void initState() {
    super.initState();
    // The screen reads the entitlement from the local row, which can be days
    // old. Pulling the server's copy on open means a subscription that lapsed
    // overnight shows as lapsed here, and a reader who already paid is not
    // sold the same plan twice.
    ref.read(proServiceProvider).refresh();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// The three ways to pay. Each tile keeps its own tint so the row reads as
  /// three choices rather than one list, but the tints come from the theme.
  List<({String label, String note, PaywallArt art, Color bg})> get _methods =>
      <({String label, String note, PaywallArt art, Color bg})>[
        (
          label: 'نقداً',
          note: 'تنسيق عبر واتساب',
          art: PaywallArt.cash,
          bg: context.pay.yellowSoft,
        ),
        (
          label: 'شام كاش',
          note: 'تحويل إلكتروني',
          art: PaywallArt.wallet,
          bg: context.pay.greenSoft,
        ),
        (
          label: 'عملات رقمية',
          note: 'عبر محفظتك',
          art: PaywallArt.crypto,
          bg: context.pay.chip,
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

  /// The sheet a subscriber opens instead of the plans.
  ///
  /// Nothing here can change the entitlement — a code does that, and a human
  /// does that — so the sheet is honest about it: what you hold, until when,
  /// and the one button that reaches a person.
  Future<void> _manageSubscription(ProStatus pro) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (BuildContext sheet) => _ManageSheet(pro: pro),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProStatus pro = ref.watch(proNowProvider);

    return Scaffold(
      backgroundColor: context.pay.page,
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
                const SizedBox(height: 26),
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
    // A subscriber is not a prospect. Selling the same plan to someone who
    // already paid reads as either a bug or a shakedown, so the whole pricing
    // block — cards, payment methods, call to action, comparison — is replaced
    // by a thank-you screen that answers the only two questions they have:
    // am I still covered, and until when.
    if (pro.active) {
      return <Widget>[
        if (widget.reason != null) ...<Widget>[
          _ReasonStrip(text: widget.reason!),
          const SizedBox(height: 26),
        ],
        _ProWelcome(
          pro: pro,
          onManage: () => _manageSubscription(pro),
          onCode: () {
            HapticFeedback.selectionClick();
            setState(() {
              _tab = 1;
              _feedback = null;
            });
          },
        ),
      ];
    }
    return <Widget>[
      if (widget.reason != null) ...<Widget>[
        _ReasonStrip(text: widget.reason!),
        const SizedBox(height: 26),
      ],
      const _MascotRow(),
      const SizedBox(height: 26),
      _Title(pro: pro),
      const SizedBox(height: 28),
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
            if (plan != ProPlan.values.last) const SizedBox(height: 20),
          ],
        ],
      ),
      const SizedBox(height: 26),
      const _SupportBanner(),
      const SizedBox(height: 26),
      _PaymentMethods(
        methods: _methods,
        selected: _method,
        onSelect: (int index) {
          HapticFeedback.selectionClick();
          setState(() => _method = index);
        },
      ),
      const SizedBox(height: 26),
      const _HowItWorks(),
      const SizedBox(height: 26),
      _CallToAction(plan: _plan, onTap: _continue),
      if (_feedback != null) ...<Widget>[
        const SizedBox(height: 16),
        _Feedback(text: _feedback!, ok: _feedbackOk),
      ],
      const SizedBox(height: 30),
      const _Comparison(),
    ];
  }

  // ------------------------------------------------------------------ code --

  List<Widget> _codeTab(ProStatus pro) {
    return <Widget>[
      const _MascotRow(),
      const SizedBox(height: 26),
      const _Title(pro: null),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        decoration: _toy(fill: context.pay.white, border: context.pay.border),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'أدخل كود التفعيل',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: context.pay.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'الكود يصلك على واتساب بعد تأكيد الدفع. يعمل مرة واحدة، ويضيف مدة الخطة إلى اشتراكك الحالي.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                height: 1.7,
                color: context.pay.muted,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _code,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: context.pay.ink,
              ),
              decoration: InputDecoration(
                hintText: 'BTQ-XXXX-XXXX',
                hintStyle: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: context.pay.muted.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: context.pay.greenSoft,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.pay.border, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.pay.green, width: 2),
                ),
              ),
              onSubmitted: (_) => _activate(),
            ),
            const SizedBox(height: 16),
            _PrimaryButton(
              label: _busy ? 'جارٍ التحقق…' : 'تفعيل الكود',
              icon: _busy ? null : FontAwesomeIcons.unlock,
              onTap: _busy ? null : _activate,
            ),
            if (_feedback != null) ...<Widget>[
              const SizedBox(height: 16),
              _Feedback(text: _feedback!, ok: _feedbackOk),
            ],
          ],
        ),
      ),
      const SizedBox(height: 26),
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

// These three carry the palette, so they are functions of the context rather
// than constants. Everything else about them is still fixed.
TextStyle _titleStyle(BuildContext context) => TextStyle(
  fontFamily: 'Cairo',
  fontSize: 15.5,
  fontWeight: FontWeight.w800,
  color: context.pay.ink,
  height: 1.4,
);

TextStyle _bodyStyle(BuildContext context) => TextStyle(
  fontFamily: 'Cairo',
  fontSize: 12,
  height: 1.75,
  color: context.pay.ink,
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
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: FaIcon(
                  FontAwesomeIcons.xmark,
                  size: 18,
                  color: context.pay.ink,
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
              color: context.pay.chip,
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
                ? BoxDecoration(
                    color: context.pay.white,
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: context.pay.border,
                        offset: const Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
                  )
                : const BoxDecoration(color: Colors.transparent),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                color: active ? context.pay.ink : context.pay.muted,
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
        color: context.pay.yellowSoft,
        border: Border.all(color: context.pay.yellow, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          FaIcon(FontAwesomeIcons.lock, size: 15, color: context.pay.greenInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                height: 1.6,
                fontWeight: FontWeight.w700,
                color: context.pay.ink,
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
              fill: context.pay.white,
              border: context.pay.border,
              lip: 0,
            ),
            child: Text(
              'مراجعة اليوم أسهل من تراكم الغد. خطوة صغيرة كل يوم تصنع الفرق!',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.7,
                color: context.pay.ink,
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
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 25,
                fontWeight: FontWeight.w800,
                height: 1.4,
                color: context.pay.ink,
              ),
              children: <InlineSpan>[
                const TextSpan(text: 'افتح بطاقتي '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
                    decoration: BoxDecoration(
                      color: context.pay.yellow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Pro',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: context.pay.onYellow,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          pro != null && pro!.active
              ? 'اشتراكك فعّال. تمديده يضيف المدة الجديدة فوق المتبقي.'
              : 'بلا حدود على المجموعات والبطاقات، ومزامنة كاملة.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            height: 1.7,
            color: context.pay.muted,
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
        padding: const EdgeInsets.all(18),
        decoration: _toy(
          fill: selected ? context.pay.selectedFill : context.pay.white,
          border: selected ? context.pay.green : context.pay.border,
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
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? context.pay.selectedInk
                              : context.pay.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.tagline,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          height: 1.5,
                          color: selected
                              ? context.pay.selectedInk.withValues(alpha: 0.72)
                              : context.pay.muted,
                        ),
                      ),
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
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? context.pay.selectedInk
                              : context.pay.ink,
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
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.5,
                          color: selected
                              ? context.pay.selectedInk.withValues(alpha: 0.72)
                              : context.pay.muted,
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
                    color: context.pay.yellow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'الأكثر اختياراً · وفر 50%',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: context.pay.onYellow,
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
        decoration: BoxDecoration(
          color: context.pay.green,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: FaIcon(
          FontAwesomeIcons.check,
          size: 11,
          color: context.pay.onGreen,
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.pay.radioEmpty, width: 2),
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
        color: context.pay.yellowSoft,
        border: Border.all(color: context.pay.yellow, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: FaIcon(
              FontAwesomeIcons.solidHeart,
              size: 22,
              color: context.pay.heart,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  height: 1.8,
                  color: context.pay.ink,
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
        Text('اختر طريقة الدفع', style: _titleStyle(context)),
        const SizedBox(height: 16),
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
              fill: selected ? context.pay.selectedFill : context.pay.white,
              border: selected ? context.pay.green : context.pay.border,
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
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected ? context.pay.selectedInk : context.pay.ink,
                  ),
                ),
                Text(
                  note,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10.5,
                    height: 1.4,
                    color: selected
                        ? context.pay.selectedInk.withValues(alpha: 0.72)
                        : context.pay.muted,
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
                decoration: BoxDecoration(
                  color: context.pay.green,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: FaIcon(
                  FontAwesomeIcons.check,
                  size: 10,
                  color: context.pay.onGreen,
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
        fill: context.pay.white,
        border: context.pay.border,
        lip: 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'كيف تتم العملية؟',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.pay.ink,
            ),
          ),
          const SizedBox(height: 14),
          for (int index = 0; index < _steps.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.pay.yellow,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: context.pay.ink,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_steps[index], style: _bodyStyle(context)),
                ),
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
        const SizedBox(height: 12),
        Text(
          '\$${plan.priceUsd}.00 ${plan.period} · يعادل ${plan.perMonth} شهرياً',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11.5,
            color: context.pay.muted,
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
            color: enabled ? context.pay.green : context.pay.radioEmpty,
            borderRadius: BorderRadius.circular(18),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: enabled ? context.pay.greenDark : context.pay.border,
                offset: const Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                FaIcon(icon, size: 21, color: context.pay.onGreen),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: context.pay.onGreen,
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
        color: ok ? context.pay.greenSoft : context.pay.dangerSoft,
        border: Border.all(
          color: ok ? context.pay.green : context.pay.heart,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11.5,
          height: 1.6,
          fontWeight: FontWeight.w700,
          color: ok ? context.pay.greenInk : context.pay.heart,
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
        fill: context.pay.greenSoft,
        border: context.pay.green,
        lip: 0,
      ),
      child: Row(
        children: <Widget>[
          FaIcon(FontAwesomeIcons.crown, size: 20, color: context.pay.greenInk),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              days == null
                  ? 'أنت مشترك في Pro. شكراً لدعمك.'
                  : 'أنت مشترك في Pro. يتبقى $days يوماً.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.pay.ink,
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
    (feature: 'أيقونة التطبيق', free: 'الافتراضية فقط', pro: '3 أيقونات'),
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
        Text(
          'المجاني مقابل Pro',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: context.pay.ink,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: context.pay.white,
            border: Border.all(color: context.pay.border, width: 2),
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
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: header ? context.pay.muted : context.pay.ink,
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: header ? 12 : 13),
      decoration: BoxDecoration(
        color: header ? context.pay.chip : context.pay.white,
        border: header
            ? null
            : Border(top: BorderSide(color: context.pay.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(flex: 135, child: Text(feature, style: featureStyle)),
          const SizedBox(width: 8),
          // Plain words in both value columns. A padlock on every free cell
          // and a tick on every paid one carried no information the number
          // beside it did not already carry, and two glyphs per row made a
          // ten-row table read as decoration.
          Expanded(
            flex: 100,
            child: Text(
              free,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                height: 1.5,
                color: context.pay.muted,
                fontWeight: header ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 100,
            child: Text(
              pro,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                height: 1.5,
                color: header ? context.pay.muted : context.pay.greenInk,
                fontWeight: header ? FontWeight.w600 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One value in the comparison table: an optional glyph and the text.
///
/// The glyph is part of the cell rather than a legend in the header, so the
/// reader never has to look back up to know which column they are in.

// -------------------------------------------------------------- pro welcome

/// What a subscriber sees instead of the price list.
///
/// The crown is the one gold thing on the screen and it is earned, not
/// advertised: it is drawn in the palette's star colour with a soft halo, so
/// the screen reads as a thank-you card rather than a receipt.
class _ProWelcome extends StatelessWidget {
  const _ProWelcome({
    required this.pro,
    required this.onManage,
    required this.onCode,
  });

  final ProStatus pro;
  final VoidCallback onManage;
  final VoidCallback onCode;

  @override
  Widget build(BuildContext context) {
    final DateTime? until = pro.expiry;
    final int? days = pro.daysLeft;
    return Column(
      children: <Widget>[
        Container(
              width: 118,
              height: 118,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    context.pay.yellow.withValues(alpha: 0.30),
                    context.pay.yellow.withValues(alpha: 0.02),
                  ],
                ),
                border: Border.all(
                  color: context.pay.yellow.withValues(alpha: 0.55),
                  width: 2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: context.pay.yellow.withValues(alpha: 0.30),
                    blurRadius: 38,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: FaIcon(
                FontAwesomeIcons.crown,
                size: 46,
                color: context.pay.yellow,
              ),
            )
            .animate()
            .fadeIn(duration: 380.ms)
            .scale(
              begin: const Offset(0.78, 0.78),
              end: const Offset(1, 1),
              duration: 640.ms,
              curve: Curves.easeOutBack,
            ),
        const SizedBox(height: 22),
        Text(
          'شكراً لدعمك',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.35,
            color: context.pay.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'أنت من مشتركي النسخة الاحترافية. كل الميزات مفتوحة لك، '
          'ومعك يبقى بطاقتي متاحاً لطالب آخر لا يستطيع الدفع.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            height: 1.8,
            color: context.pay.muted,
          ),
        ),
        const SizedBox(height: 26),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: _toy(fill: context.pay.white, border: context.pay.border),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  FaIcon(
                    FontAwesomeIcons.circleCheck,
                    size: 15,
                    color: context.pay.greenInk,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('اشتراكك فعّال', style: _titleStyle(context)),
                  ),
                  if (days != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.pay.selectedFill,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'متبقٍ $days يوماً',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: context.pay.selectedInk,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                until == null
                    ? 'اشتراك دائم، بلا تاريخ انتهاء.'
                    : 'ينتهي في ${formatArabicDate(until)}.',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  height: 1.7,
                  color: context.pay.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'إدارة الاشتراك',
          icon: FontAwesomeIcons.gear,
          onTap: onManage,
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: onCode,
          child: Text(
            'لديك كود تفعيل؟ أضفه هنا',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: context.pay.greenInk,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _SupportBanner(),
      ],
    );
  }
}

// ------------------------------------------------------------------- manage

/// The subscriber's own page: status, expiry, and a person to talk to.
class _ManageSheet extends StatelessWidget {
  const _ManageSheet({required this.pro});

  final ProStatus pro;

  @override
  Widget build(BuildContext context) {
    final DateTime? until = pro.expiry;
    final int? days = pro.daysLeft;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            decoration: BoxDecoration(
              color: context.pay.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: context.pay.border, width: 1.4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.pay.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'إدارة الاشتراك',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: context.pay.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        CupertinoIcons.xmark,
                        size: 20,
                        color: context.pay.muted,
                      ),
                      tooltip: 'إغلاق',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _ManageRow(label: 'الحالة', value: 'فعّال'),
                _ManageRow(
                  label: 'ينتهي في',
                  value: until == null ? 'بلا نهاية' : formatArabicDate(until),
                ),
                if (days != null)
                  _ManageRow(label: 'المتبقي', value: '$days يوماً'),
                const SizedBox(height: 14),
                Text(
                  'الاشتراك يُدار بكود التفعيل. للتمديد أو للإلغاء راسلنا على '
                  'واتساب وسنعالج الطلب يدوياً في اليوم نفسه.',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    height: 1.8,
                    color: context.pay.muted,
                  ),
                ),
                const SizedBox(height: 18),
                _PrimaryButton(
                  label: 'تواصل عبر واتساب',
                  icon: FontAwesomeIcons.whatsapp,
                  onTap: () => _contactSupport(context),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'إغلاق',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.pay.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _contactSupport(BuildContext context) {
    final Uri uri = Uri.parse(
      'https://wa.me/${DeveloperInfoScreen.whatsappNumber.replaceAll('+', '')}'
      '?text=${Uri.encodeComponent('مرحباً! أريد إدارة اشتراكي في بطاقتي Pro.')}',
    );
    HapticFeedback.selectionClick();
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
  }
}

/// One labelled line in the management sheet.
class _ManageRow extends StatelessWidget {
  const _ManageRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12.5,
              color: context.pay.muted,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.pay.ink,
            ),
          ),
        ],
      ),
    );
  }
}
