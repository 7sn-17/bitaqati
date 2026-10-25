# أوامر المتابعة

## 1) مزامنة المشروع على جهازك

افتح Termux وشغّل:

```bash
cd ~/cards
git pull origin main
```

إذا ظهرت رسالة أن الفرع محدّث، فلا يوجد شيء جديد.

## 2) تنزيل أحدث APK

الطريقة الأسهل: افتح رابط الإصدار في المتصفح:

<https://github.com/7sn-17/bitaqati/releases/tag/v0.1.1-phase0>

أو من Termux:

```bash
cd ~/cards
gh release download v0.1.1-phase0 \
  -p bitaqati-phase0.apk \
  -O bitaqati-phase0.apk
```

## 3) تثبيت التطبيق

```bash
cd ~/cards
termux-open ./bitaqati-phase0.apk
```

سيطلب أندرويد السماح بتثبيت التطبيقات من هذا المصدر. اسمح مرة واحدة، ثم
أكمل التثبيت.

## 4) فتح المستودع أو الإصدارات

```bash
gh repo view 7sn-17/bitaqati --web
gh release view v0.1.1-phase0 --web
```

## 5) متابعة البناء

```bash
gh run list --limit 5
```

لعرض آخر بناء مباشرة:

```bash
gh run watch
```

إذا فشل بناء، اعرض السبب:

```bash
gh run view --log-failed
```

## 6) تحديث APK بعد أي تعديل جديد

أي دفعة إلى `main` تبني APK جديداً في تبويب Actions. بعد نجاح البناء:

```bash
gh run list --limit 1
gh run download <RUN_ID> -n bitaqati-phase0-apk -D ./dist
```

## 7) إصدار جديد (لاحقاً)

عندما نصل إلى مرحلة جديدة:

```bash
git tag -a v0.2.0-phase1 -m "بطاقاتي — المرحلة 1"
git push origin v0.2.0-phase1
```

سيُنشئ سير `Release APK` إصداراً جديداً تلقائياً.

## روابط مهمة

- المستودع: <https://github.com/7sn-17/bitaqati>
- آخر إصدار: <https://github.com/7sn-17/bitaqati/releases/tag/v0.1.1-phase0>
- Supabase project ref: `mftghnvtdryxzochquee`
- توثيق المرحلة 0: [PHASE_0.md](PHASE_0.md)
- البنية: [ARCHITECTURE.md](ARCHITECTURE.md)
- الإعدادات: [CONFIGURATION.md](CONFIGURATION.md)
