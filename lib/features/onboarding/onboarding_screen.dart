import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/i18n/app_strings.dart';
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
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingCompletedProvider.notifier).complete();
  }

  void _next() {
    if (_index == 2) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final List<_OnboardingPageData> pages = <_OnboardingPageData>[
      _OnboardingPageData(
        asset: 'assets/illustrations/onboarding_focus.svg',
        title: strings.onboardingTitle1,
        body: strings.onboardingBody1,
        accent: AppColors.lime,
      ),
      _OnboardingPageData(
        asset: 'assets/illustrations/onboarding_structure.svg',
        title: strings.onboardingTitle2,
        body: strings.onboardingBody2,
        accent: AppColors.lavender,
      ),
      _OnboardingPageData(
        asset: 'assets/illustrations/onboarding_sync.svg',
        title: strings.onboardingTitle3,
        body: strings.onboardingBody3,
        accent: AppColors.sky,
      ),
    ];
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.8),
                  radius: 1.1,
                  colors: <Color>[
                    pages[_index].accent.withValues(
                      alpha: context.isDark ? 0.14 : 0.18,
                    ),
                    context.pageBackground,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: context.colors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.style_rounded,
                              color: context.colors.onPrimary,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            strings.appName,
                            style: context.texts.titleLarge,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _finish,
                            child: Text(strings.skip),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: pages.length,
                        onPageChanged: (int value) =>
                            setState(() => _index = value),
                        itemBuilder: (BuildContext context, int index) {
                          final _OnboardingPageData page = pages[index];
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(26, 8, 26, 10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Flexible(
                                  child: SvgPicture.asset(
                                    page.asset,
                                    height: 310,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  page.title,
                                  style: context.texts.headlineLarge,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  page.body,
                                  style: context.texts.bodyLarge?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
                      child: Column(
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List<Widget>.generate(pages.length, (
                              int index,
                            ) {
                              final bool active = index == _index;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 240),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: active ? 24 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: active
                                      ? context.colors.primary
                                      : context.colors.outlineVariant,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _next,
                              child: Text(
                                _index == pages.length - 1
                                    ? strings.getStarted
                                    : strings.next,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.asset,
    required this.title,
    required this.body,
    required this.accent,
  });

  final String asset;
  final String title;
  final String body;
  final Color accent;
}
