import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Splits "a, b، c" into clean tags. Accepts Latin and Arabic commas.
List<String> parseTags(String raw) {
  return raw
      .split(RegExp(r'[,،\n]'))
      .map((String tag) => tag.trim())
      .where((String tag) => tag.isNotEmpty)
      .toList(growable: false);
}

/// Fill used by inputs inside editor sheets. Darker than the sheet itself so
/// fields stay visible in both themes.
Color editorFieldFill(BuildContext context) {
  return context.isDark ? AppColors.darkCanvas : AppColors.surface;
}

InputDecoration editorDecoration(
  BuildContext context, {
  required String hint,
  bool multiline = false,
  String? errorText,
}) {
  final BorderRadius radius = BorderRadius.circular(multiline ? 22 : 999);
  return InputDecoration(
    hintText: hint,
    errorText: errorText,
    counterText: '',
    filled: true,
    fillColor: editorFieldFill(context),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: context.colors.primary, width: 1.2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
    ),
  );
}

class EditorLabel extends StatelessWidget {
  const EditorLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7, top: 14),
      child: Text(text, style: context.texts.labelLarge),
    );
  }
}

/// Rounded sheet with a grab handle, a title row and a close button.
class EditorSheetFrame extends StatelessWidget {
  const EditorSheetFrame({
    required this.title,
    required this.child,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Color surface = context.isDark
        ? AppColors.darkSurfaceHigh
        : Colors.white;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(30),
              border: context.isDark
                  ? Border.all(color: context.colors.outlineVariant, width: 0.8)
                  : null,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.colors.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: context.texts.headlineSmall,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(CupertinoIcons.xmark),
                        tooltip: 'إغلاق',
                      ),
                    ],
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: context.texts.bodySmall),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
