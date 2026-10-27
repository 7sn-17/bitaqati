import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/legal_footer.dart';
import '../legal/privacy_policy_screen.dart';
import '../legal/terms_of_service_screen.dart';
import 'onboarding_scene.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<_OnboardingPage> _pages = <_OnboardingPage>[
    _OnboardingPage(
      title: 'راجع أقل، تذكّر أكثر',
      body: 'بطاقاتي يستخدم التكرار المتباعد ليعرض لك البطاقة المناسبة في '
          'الوقت المناسب، لا أكثر ولا أقل.',
      scene: 0,
      chips: <_ChipSpec>[
        _ChipSpec('٣ بطاقات فقط', Icons.bolt_rounded, 0.08, 0.16),
        _ChipSpec('تذكّر ٩٢٪', Icons.trending_up_rounded, 0.74, 0.72),
      ],
      arrows: true,
    ),
    _OnboardingPage(
      title: 'أنشئ بطاقات بطريقتك',
      body: 'اختر بطاقة أساسية أو ملء فراغ أو تغطية صورة، وأضف التنسيق '
          'والوسوم والتلميحات قبل الحفظ.',
      scene: 1,
      chips: <_ChipSpec>[
        _ChipSpec('ملء فراغ', Icons.data_object, 0.06, 0.7),
        _ChipSpec('صورة', Icons.image_outlined, 0.76, 0.14),
      ],
      arrows: true,
    ),
    _OnboardingPage(
      title: 'مكتبة من المتعلّمين',
      body: 'اكتشف مجموعات جاهزة في العلوم واللغات والتاريخ والمهارات '
          'وأي مجال تريد إتقانه، ثم أضف ما يناسبك إلى مساحتك.',
      scene: 2,
      chips: <_ChipSpec>[
        _ChipSpec('+٤٠٠ مجموعة', Icons.library_books_rounded, 0.72, 0.14),
        _ChipSpec('تقييم ٤.٨', Icons.star_rounded, 0.08, 0.74),
      ],
      arrows: false,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(sharedPreferencesProvider).setBool('onboarding_done', true);
    ref.read(onboardingCompletedProvider.notifier).state = true;
    if (!mounted) {
      return;
    }
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final bool isLast = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.softAccent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'بطاقاتي',
                      style: context.texts.labelLarge?.copyWith(
                        fontFamily: 'ReadexPro',
                        color: context.brandInk,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!isLast)
                    TextButton(
                      onPressed: _finish,
                      child: const Text('تخطي'),
                    ).animate().fadeIn(
                      delay: const Duration(milliseconds: 400),
                    ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (int value) => setState(() => _page = value),
                  itemBuilder: (BuildContext context, int index) {
                    return _PageContent(
                      key: ValueKey<int>(index),
                      page: _pages[index],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (int index = 0; index < _pages.length; index++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: index == _page ? 26 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: index == _page
                            ? context.brandInk
                            : context.colors.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (isLast) {
                      _finish();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  child: Text(isLast ? 'ابدأ الآن' : 'التالي'),
                ),
              )
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 320))
                  .slideY(begin: 0.35, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 8),
              LegalFooterLinks(
                onPrivacy: () =>
                    openLegalPage(context, const PrivacyPolicyScreen()),
                onTerms: () =>
                    openLegalPage(context, const TermsOfServiceScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent({required this.page, super.key});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const SizedBox(height: 18),
          _AnimatedIllustration(page: page),
          const SizedBox(height: 26),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: context.texts.displaySmall,
          )
              .animate()
              .fadeIn(
                delay: const Duration(milliseconds: 180),
                duration: const Duration(milliseconds: 380),
              )
              .slideY(begin: 0.22, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: Text(
              page.body,
              textAlign: TextAlign.center,
              style: context.texts.bodyLarge?.copyWith(
                color: context.texts.bodySmall?.color,
                height: 1.85,
              ),
            ),
          )
              .animate()
              .fadeIn(
                delay: const Duration(milliseconds: 320),
                duration: const Duration(milliseconds: 420),
              )
              .slideY(begin: 0.18, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// The illustration is the hero of each slide: the SVG pops in, the accent
/// blobs breathe behind it, and two chips fly in from the sides while a pair
/// of arrows drifts along the diagonal.
class _AnimatedIllustration extends StatefulWidget {
  const _AnimatedIllustration({required this.page});

  final _OnboardingPage page;

  @override
  State<_AnimatedIllustration> createState() => _AnimatedIllustrationState();
}

class _AnimatedIllustrationState extends State<_AnimatedIllustration>
    with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat(reverse: true);

  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _float.dispose();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          // Breathing halo.
          AnimatedBuilder(
            animation: _float,
            builder: (BuildContext context, Widget? child) {
              final double t = Curves.easeInOut.transform(_float.value);
              return Transform.scale(scale: 0.92 + 0.08 * t, child: child);
            },
            child: Container(
              width: 268,
              height: 268,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    context.softAccent,
                    context.softAccent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          // Orbiting accent dots.
          AnimatedBuilder(
            animation: _orbit,
            builder: (BuildContext context, Widget? child) {
              return SizedBox(
                width: 292,
                height: 292,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    for (int i = 0; i < 3; i++)
                      Transform.translate(
                        offset: Offset(
                          math.cos(_orbit.value * 2 * math.pi + i * 2.1) * 132,
                          math.sin(_orbit.value * 2 * math.pi + i * 2.1) * 132,
                        ),
                        child: Container(
                          width: 7.0 + i * 1.6,
                          height: 7.0 + i * 1.6,
                          decoration: BoxDecoration(
                            color: context.brandInk.withValues(
                              alpha: 0.22 + 0.1 * i,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          // The illustration itself.
          AnimatedBuilder(
            animation: _float,
            builder: (BuildContext context, Widget? child) {
              final double t = Curves.easeInOut.transform(_float.value);
              return Transform.translate(
                offset: Offset(0, -6 + 12 * t),
                child: child,
              );
            },
            child: Container(
              width: 250,
              height: 214,
              decoration: BoxDecoration(
                color: context.cardSurface,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: context.hairline),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: context.isDark ? 0.42 : 0.06,
                    ),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: OnboardingScene(index: widget.page.scene),
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.82, 0.82),
                end: const Offset(1, 1),
                duration: const Duration(milliseconds: 560),
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: const Duration(milliseconds: 320)),
          // Floating chips.
          for (int index = 0; index < widget.page.chips.length; index++)
            _FloatingChip(
              spec: widget.page.chips[index],
              fromLeft: index == 0,
            ),
          if (widget.page.arrows)
            for (int index = 0; index < 2; index++)
              _DriftingArrow(index: index, animation: _orbit),
        ],
      ),
    );
  }
}

class _FloatingChip extends StatelessWidget {
  const _FloatingChip({required this.spec, required this.fromLeft});

  final _ChipSpec spec;
  final bool fromLeft;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(
        spec.alignmentX * 2 - 1,
        spec.alignmentY * 2 - 1,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: context.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.hairline),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDark ? 0.4 : 0.08,
              ),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(spec.icon, size: 14, color: context.brandInk),
            const SizedBox(width: 6),
            Text(
              spec.label,
              style: context.texts.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.ink,
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(
            delay: const Duration(milliseconds: 520),
            duration: const Duration(milliseconds: 380),
          )
          .slideX(
            begin: fromLeft ? -0.8 : 0.8,
            end: 0,
            delay: const Duration(milliseconds: 520),
            duration: const Duration(milliseconds: 460),
            curve: Curves.easeOutBack,
          ),
    );
  }
}

/// Small arrow that travels along the diagonal, hinting at flow between the
/// "source" and the "cards" in the illustration.
class _DriftingArrow extends StatelessWidget {
  const _DriftingArrow({required this.index, required this.animation});

  final int index;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double phase = (animation.value + index * 0.5) % 1;
        final double eased = Curves.easeInOut.transform(phase);
        return Align(
          alignment: Alignment(
            index == 0 ? -0.75 + 0.35 * eased : 0.75 - 0.35 * eased,
            index == 0 ? -0.55 + 0.3 * eased : 0.6 - 0.3 * eased,
          ),
          child: Opacity(
            opacity: (1 - (phase - 0.5).abs() * 2).clamp(0.15, 1.0).toDouble(),
            child: child,
          ),
        );
      },
      child: Icon(
        index == 0 ? Icons.call_made_rounded : Icons.call_received_rounded,
        size: 18,
        color: context.brandInk.withValues(alpha: 0.55),
      ),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.body,
    required this.scene,
    required this.chips,
    required this.arrows,
  });

  final String title;
  final String body;

  /// Which live scene to draw inside the card (0 review, 1 create, 2 library).
  final int scene;
  final List<_ChipSpec> chips;
  final bool arrows;
}

class _ChipSpec {
  const _ChipSpec(this.label, this.icon, this.alignmentX, this.alignmentY);

  final String label;
  final IconData icon;
  final double alignmentX;
  final double alignmentY;
}
