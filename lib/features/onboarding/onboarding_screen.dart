import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
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
      asset: 'assets/onboarding/review_less.svg',
    ),
    _OnboardingPage(
      title: 'حوّل أي ملف إلى بطاقات',
      body: 'الصق نصاً أو أضف صورة أو ملفاً، وسنحوّله إلى بطاقات مراجعة جاهزة يمكنك تعديلها قبل الحفظ.',
      asset: 'assets/onboarding/file_to_cards.svg',
    ),
    _OnboardingPage(
      title: 'مكتبة من الطلاب',
      body: 'اكتشف مجموعات جاهزة في الفيزياء والكيمياء والبيولوجيا وتاريخ الطب والانكليزية 1.',
      asset: 'assets/onboarding/student_library.svg',
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
    return Center(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SvgPicture.asset(
              page.asset,
              width: 300,
              height: 244,
              semanticsLabel: page.title,
            ),
            const SizedBox(height: 30),
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
        ),
      ),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.body,
    required this.asset,
  });

  final String title;
  final String body;
  final String asset;
}
