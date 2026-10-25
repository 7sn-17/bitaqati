# بطاقاتي — Bitaqati

تطبيق بطاقات تعليمية عربي، يعمل أولاً دون إنترنت، ويستخدم التكرار المتباعد لمساعدتك على تذكّر ما تدرسه.

> **الحالة:** المرحلة 0 — التأسيس. واجهة كاملة قابلة للتصفح + هوية بصرية + مخطط قاعدة البيانات + خط بناء APK.
> محرّك المراجعة المحلي، الاستيراد، والذكاء الاصطناعي تأتي في المراحل التالية.

---

## المواد المعتمدة

| المادة | الاسم بالإنجليزية | اللون |
|---|---|---|
| الفيزياء | Physics | `#0B4C72` |
| الكيمياء | Chemistry | `#054D28` |
| البيولوجيا | Biology | `#163300` |
| تاريخ الطب | History of Medicine | `#7A3E2F` |
| الانكليزية 1 | English 1 | `#4A3F7A` |

هذه الأسماء هي المصدر الوحيد للحقيقة، وهي مطابقة في التطبيق وقاعدة البيانات.

## ما هو موجود الآن

- 4 تبويبات + زر إنشاء مركزي: الرئيسية، مجموعاتي، المكتبة، تقدّمي.
- شريط تنقل سفلي زجاجي بأسلوب iOS مع دعم RTL وsafe-area.
- شاشات: Onboarding، الرئيسية، المجموعات، تفاصيل المجموعة، المراجعة، ملخص الجلسة، المكتبة، تقدّمي، الإعدادات، البحث.
- وضع فاتح وداكن، خطوط Readex Pro وIBM Plex Sans Arabic مضمّنة داخل التطبيق.
- بيانات تجريبية احترافية لكل المواد الخمس.
- مخطط Supabase كامل مع RLS، فهارس، مشغلات، وعرض المكتبة العامة.
- سير عمل GitHub Actions لتوليد مشروع Android وبناء APK.

## التشغيل محلياً

المتطلبات: Flutter stable، Java 17، Android SDK.

```bash
flutter pub get
flutter run
```

بناء APK:

```bash
flutter build apk --debug
# أو
flutter build apk --release
```

## GitHub Actions

- `Build Android APK` يشغّل التحليل ويبني APK إصدار قابل للتثبيت عند كل دفعة إلى `main`.
- يمكن تشغيله يدوياً من تبويب Actions، وتُنزّل الحزمة من قسم Artifacts.

## البنية

```
lib/
├── app.dart                 # MaterialApp.router + RTL + themes
├── main.dart                # SharedPreferences bootstrap
├── core/
│   ├── config/              # build-time configuration
│   ├── router/              # go_router + StatefulShellRoute
│   ├── theme/               # colours + typography
│   ├── providers.dart       # Riverpod state
│   └── widgets/             # shared UI
├── data/                    # models + starter content
└── features/                # one folder per product area
```

طبقة البيانات السحابية في `supabase/migrations/`. التطبيق نفسه لا يحتوي على أي مفتاح سري.

## الخصوصية

- لا تُضمّن مفاتيح `service_role` أو مفاتيح مزوّدي الذكاء الاصطناعي في التطبيق أبداً.
- كل جداول المستخدم محمية بـ Row Level Security.
- المكتبة العامة تعرض فقط المجموعات التي اختار مالكها نشرها.

## الترخيص

خاص — جميع الحقوق محفوظة.
