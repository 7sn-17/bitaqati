import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

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
      body: 'بطاقاتي يستخدم التكرار المتباعد ليعرض لك البطاقة المناسبة في الوقت المناسب، لا أكثر ولا أقل.',
      icon: CupertinoIcons.clock,
      accent: AppColors.accent,
    ),
    _OnboardingPage(
      title: 'حوّل أي ملف إلى بطاقات',
      body: 'الصق نصاً أو أضف صورة أو ملفاً، وسنحوّله إلى بطاقات مراجعة جاهزة يمكنك تعديلها قبل الحفظ.',
      icon: CupertinoIcons.sparkles,
      accent: AppColors.accentSoft,
    ),
    _OnboardingPage(
      title: 'مكتبة من الطلاب',
      body: 'اكتشف مجموعات جاهزة في الفيزياء والكيمياء والبيولوجيا وتاريخ الطب والانكليزية 1.',
      icon: CupertinoIcons.books,
      accent: Color(0xFFCFE8C0),
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
    context.go('/home');
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
                      color: context.colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'بطاقاتي',
                      style: context.texts.labelLarge?.copyWith(
                        fontFamily: 'ReadexPro',
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!isLast)
                    TextButton(onPressed: _finish, child: const Text('تخطي')),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (int value) => setState(() => _page = value),
                  itemBuilder: (BuildContext context, int index) {
                    return _PageContent(page: _pages[index]);
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (int index = 0; index < _pages.length; index++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: index == _page ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: index == _page
                            ? context.colors.primary
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
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  child: Text(isLast ? 'ابدأ الآن' : 'التالي'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'بالمتابعة أنت توافق على سياسة الخصوصية وشروط الاستخدام',
                textAlign: TextAlign.center,
                style: context.texts.bodySmall?.copyWith(fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _Illustration(page: page),
        const SizedBox(height: 38),
        Text(
          page.title,
          textAlign: TextAlign.center,
          style: context.texts.displaySmall,
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Text(
            page.body,
            textAlign: TextAlign.center,
            style: context.texts.bodyLarge?.copyWith(
              color: context.texts.bodySmall?.color,
              height: 1.8,
            ),
          ),
        ),
      ],
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      width: 300,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            top: 34,
            child: Transform.rotate(
              angle: -0.09,
              child: Container(
                width: 190,
                height: 136,
                decoration: BoxDecoration(
                  color: page.accent.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Positioned(
            top: 42,
            child: Transform.rotate(
              angle: 0.07,
              child: Container(
                width: 196,
                height: 140,
                decoration: BoxDecoration(
                  color: page.accent,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Container(
            width: 206,
            height: 150,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(26),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        page.icon,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      CupertinoIcons.sparkles,
                      size: 16,
                      color: AppColors.accent,
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  height: 8,
                  width: 128,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 8,
                  width: 92,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 8,
                  width: 108,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 24,
            left: 34,
            child: _FloatingBadge(
              icon: CupertinoIcons.checkmark,
              color: AppColors.accent,
              iconColor: AppColors.primary,
            ),
          ),
          Positioned(
            top: 18,
            right: 32,
            child: _FloatingBadge(
              icon: CupertinoIcons.flame,
              color: Colors.white,
              iconColor: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingBadge extends StatelessWidget {
  const _FloatingBadge({
    required this.icon,
    required this.color,
    required this.iconColor,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: 20, color: iconColor),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color accent;
}
