import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// What a free account may do.
///
/// One table, read by the paywall, the guards and the cloud migration alike.
/// A limit that lives in two places drifts; this file is the only place the
/// numbers are written down on the client.
abstract final class FreeLimits {
  /// The floor: no account ever has fewer than this many decks open.
  static const int decks = 20;

  static const int cards = 1000;
  static const int studySessionsPerDeck = 4;
  static const int syncedDecks = 5;
  static const int importCardsPerMonth = 150;
  static const int images = 50;
  static const int audio = 15;
  static const int occlusionCards = 5;
  static const int clozeCards = 20;

  /// How many decks stay open once Pro ends.
  ///
  /// Half the library, rounded up, and never below [decks]. A flat number was
  /// wrong in both directions: someone with twelve decks lost eight of them
  /// for nothing, and someone with four hundred kept twenty and called it a
  /// punishment. Proportional keeps the promise — nobody loses their work,
  /// they lose half their shelf — while the floor keeps a small library whole.
  static int unlockedFor(int total) {
    final int half = (total / 2).ceil();
    return half < decks ? decks : half;
  }
}

/// The three paid plans, priced once so the paywall and the activation code
/// cannot disagree about what a code buys.
enum ProPlan { monthly, quarterly, yearly }

extension ProPlanInfo on ProPlan {
  String get label => switch (this) {
    ProPlan.monthly => 'شهري',
    ProPlan.quarterly => '3 أشهر',
    ProPlan.yearly => 'سنوي',
  };

  String get tagline => switch (this) {
    ProPlan.monthly => 'مرونة كاملة لتجربة قصيرة',
    ProPlan.quarterly => 'يعادل \$1.67 شهرياً · وفر 17%',
    ProPlan.yearly => 'يعادل \$1.00 شهرياً · للطلاب الجادين',
  };

  /// Price in US dollars, whole numbers only: the paywall never shows cents on
  /// the plan cards, and the WhatsApp message has to match what was shown.
  int get priceUsd => switch (this) {
    ProPlan.monthly => 2,
    ProPlan.quarterly => 5,
    ProPlan.yearly => 12,
  };

  /// The crossed-out price, only the yearly plan advertises one.
  int? get compareAtUsd => this == ProPlan.yearly ? 24 : null;

  /// What the plan works out to per month, for the sub-line.
  String get perMonth => switch (this) {
    ProPlan.monthly => '\$2.00',
    ProPlan.quarterly => '\$1.67',
    ProPlan.yearly => '\$1.00',
  };

  String get period => switch (this) {
    ProPlan.monthly => '/ شهر',
    ProPlan.quarterly => '/ 3 أشهر',
    ProPlan.yearly => '/ سنة',
  };

  /// Months added to the subscription when a code for this plan is redeemed.
  int get months => switch (this) {
    ProPlan.monthly => 1,
    ProPlan.quarterly => 3,
    ProPlan.yearly => 12,
  };

  /// The value stored in `activation_codes.plan_type`.
  String get cloudValue => name;

  static ProPlan? fromCloud(String value) {
    for (final ProPlan plan in ProPlan.values) {
      if (plan.cloudValue == value) {
        return plan;
      }
    }
    return null;
  }
}

/// Whether this device is entitled to the paid tier, and until when.
@immutable
class ProStatus {
  const ProStatus({this.isPro = false, this.expiry});

  /// Mirrors `profiles.is_pro`. Kept separate from [expiry] because the cloud
  /// can revoke a subscription before its date.
  final bool isPro;

  /// End of the paid period. Null for an account that never subscribed.
  final DateTime? expiry;

  /// Paid and not yet expired.
  bool get active {
    if (!isPro) {
      return false;
    }
    final DateTime? until = expiry;
    return until == null || until.isAfter(DateTime.now());
  }

  /// True once the account has ever been paid, which is what keeps the paid
  /// palette after a lapse.
  bool get everPro => isPro || expiry != null;

  /// Null means unlimited. [total] is how many decks the library holds right
  /// now, because the free allowance is proportional to it.
  int? deckLimitFor(int total) => active ? null : FreeLimits.unlockedFor(total);

  int? get cardLimit => active ? null : FreeLimits.cards;

  /// Whole days left, or null when the subscription never expires.
  int? get daysLeft {
    final DateTime? until = expiry;
    if (!active || until == null) {
      return null;
    }
    return math.max(0, until.difference(DateTime.now()).inDays);
  }

  static ProStatus fromRow({required bool isPro, required DateTime? expiry}) {
    return ProStatus(isPro: isPro, expiry: expiry);
  }
}

/// The other ceilings a free account can hit, with the wording for each.
///
/// Grouped here rather than in the paywall so the comparison table, the
/// dialogs and the guards all quote the same numbers: a limit that appears in
/// two places eventually appears with two different values.
enum QuotaKind {
  cards,
  occlusion,
  cloze,
  images,
  audio,
  importCards,
  studySessions,
}

extension QuotaKindInfo on QuotaKind {
  /// The free allowance for this ceiling.
  int get limit => switch (this) {
    QuotaKind.cards => FreeLimits.cards,
    QuotaKind.occlusion => FreeLimits.occlusionCards,
    QuotaKind.cloze => FreeLimits.clozeCards,
    QuotaKind.images => FreeLimits.images,
    QuotaKind.audio => FreeLimits.audio,
    QuotaKind.importCards => FreeLimits.importCardsPerMonth,
    QuotaKind.studySessions => FreeLimits.studySessionsPerDeck,
  };

  /// Headline of the prompt.
  String get title => switch (this) {
    QuotaKind.cards => 'وصلت إلى $limit بطاقة',
    QuotaKind.occlusion => 'حد بطاقات التغطية',
    QuotaKind.cloze => 'حد بطاقات ملء الفراغات',
    QuotaKind.images => 'حد الصور',
    QuotaKind.audio => 'حد المقاطع الصوتية',
    QuotaKind.importCards => 'حد الاستيراد الشهري',
    QuotaKind.studySessions => 'جلسات هذه المجموعة انتهت',
  };

  /// The sentence under the headline: what ran out and what Pro changes.
  String get message => switch (this) {
    QuotaKind.cards =>
      'الخطة المجانية تتسع لـ$limit بطاقة. بطاقاتك كلها محفوظة، '
          'وPro يرفع الحد بلا نهاية.',
    QuotaKind.occlusion =>
      'بطاقات التغطية البصرية محدودة بـ$limit في الخطة المجانية. '
          'Pro يفتحها بلا حد.',
    QuotaKind.cloze =>
      'بطاقات ملء الفراغات محدودة بـ$limit في الخطة المجانية. '
          'Pro يفتحها بلا حد.',
    QuotaKind.images =>
      'الخطة المجانية تسمح بـ$limit صورة. الصور المضافة تبقى كما هي، '
          'وPro يرفع الحد.',
    QuotaKind.audio =>
      'الخطة المجانية تسمح بـ$limit مقطعاً صوتياً. Pro يرفع الحد بلا نهاية.',
    QuotaKind.importCards =>
      'استوردت $limit بطاقة هذا الشهر. الحد يتجدد أول كل شهر، '
          'وPro يستورد بلا حد.',
    QuotaKind.studySessions =>
      'الخطة المجانية تسمح بـ$limit جلسات مراجعة لكل مجموعة في اليوم. '
          'Pro يفتح المراجعة بلا حد.',
  };

  /// What the paywall says it is for.
  String get reason => switch (this) {
    QuotaKind.cards => 'وصلت إلى حد البطاقات في الخطة المجانية.',
    QuotaKind.occlusion => 'بطاقات التغطية البصرية متاحة بلا حد مع Pro.',
    QuotaKind.cloze => 'بطاقات ملء الفراغات متاحة بلا حد مع Pro.',
    QuotaKind.images => 'الصور بلا حد مع Pro.',
    QuotaKind.audio => 'المقاطع الصوتية بلا حد مع Pro.',
    QuotaKind.importCards => 'الاستيراد الذكي بلا حد مع Pro.',
    QuotaKind.studySessions => 'جلسات المراجعة بلا حد مع Pro.',
  };
}
