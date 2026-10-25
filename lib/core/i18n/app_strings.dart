import 'package:flutter/material.dart';

class AppStrings {
  const AppStrings(this.locale);
  final Locale locale;
  bool get isArabic => locale.languageCode == 'ar';
  String _t(String ar, String en) => isArabic ? ar : en;

  static AppStrings of(BuildContext context) => Localizations.of<AppStrings>(context, AppStrings) ?? const AppStrings(Locale('ar'));

  String get appName => _t('بطاقاتي', 'Bitaqati');
  String get front => _t('الوجه', 'Front');
  String get back => _t('الظهر', 'Back');
  String get frontHint => _t('السؤال', 'Question');
  String get backHint => _t('الإجابة', 'Answer');
  String get hint => _t('تلميح', 'Hint');
  String get notes => _t('ملاحظات', 'Notes');
  String get tagline => _t('مساحة هادئة للحفظ', 'A calm place');
  String get continueLabel => _t('متابعة', 'Continue');
  String get getStarted => _t('ابدأ الآن', 'Get started');
  String get skip => _t('تخطي', 'Skip');
  String get next => _t('التالي', 'Next');
  String get done => _t('تم', 'Done');
  String get cancel => _t('إلغاء', 'Cancel');
  String get save => _t('حفظ', 'Save');
  String get delete => _t('حذف', 'Delete');
  String get edit => _t('تعديل', 'Edit');
  String get add => _t('إضافة', 'Add');
  String get create => _t('إنشاء', 'Create');
  String get search => _t('بحث', 'Search');
  String get settings => _t('الإعدادات', 'Settings');
  String get profile => _t('حسابي', 'Profile');
  String get home => _t('الرئيسية', 'Home');
  String get library => _t('المكتبة', 'Library');
  String get progress => _t('تقدمي', 'Progress');
  String get review => _t('مراجعة', 'Review');
  String get decks => _t('المجلدات', 'Decks');
  String get deck => _t('مجلد', 'Deck');
  String get due => _t('مستحقة', 'Due');
  String get newCards => _t('جديدة', 'New');
  String get learning => _t('قيد التعلم', 'Learning');
  String get reviewState => _t('مراجعة', 'Review');
  String get mastered => _t('متقنة', 'Mastered');
  String get suspended => _t('موقوفة', 'Suspended');
  String get retention => _t('الاسترجاع', 'Retention');
  String get reviews => _t('المراجعات', 'Reviews');
  String get streak => _t('السلسلة', 'Streak');
  String get days => _t('أيام', 'days');
  String get today => _t('اليوم', 'Today');
  String get study => _t('ادرس', 'Study');
  String get reviewNow => _t('راجع الآن', 'Review now');
  String get addCard => _t('بطاقة جديدة', 'New card');
  String get studyTitle => _t('جلسة مراجعة', 'Review session');
  String get showAnswer => _t('أظهر الإجابة', 'Show answer');
  String get again => _t('أعد', 'Again');
  String get hard => _t('صعب', 'Hard');
  String get good => _t('جيد', 'Good');
  String get easy => _t('سهل', 'Easy');
  String get answer => _t('الإجابة', 'Answer');
  String get question => _t('السؤال', 'Question');
  String get settingsTitle => _t('الإعدادات', 'Settings');
  String get appearance => _t('المظهر', 'Appearance');
  String get language => _t('اللغة', 'Language');
  String get arabic => _t('العربية', 'Arabic');
  String get english => _t('الإنجليزية', 'English');
  String get theme => _t('السمة', 'Theme');
  String get system => _t('النظام', 'System');
  String get light => _t('فاتح', 'Light');
  String get dark => _t('داكن', 'Dark');
  String get account => _t('الحساب', 'Account');
  String get signIn => _t('تسجيل الدخول', 'Sign in');
  String get signOut => _t('تسجيل الخروج', 'Sign out');
  String get guest => _t('زائر', 'Guest');
  String get continueWithGoogle => _t('المتابعة باستخدام Google', 'Continue with Google');
  String get continueAsGuest => _t('المتابعة كضيف', 'Continue as guest');
  
  String get all => _t('الكل', 'All');
  String get folders => _t('المجلدات', 'Folders');
  String get noResults => _t('لا توجد نتائج', 'No results');
  String get libraryTitle => _t('مكتبة المحتوى', 'Content library');
}

class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ar' || locale.languageCode == 'en';
  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);
  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}

extension AppStringsContext on BuildContext {
  AppStrings get strings => AppStrings.of(this);
}
