/// Who may see a deck. Mirrors the cloud `deck_privacy` enum.
enum DeckPrivacy { private, unlisted, public }

extension DeckPrivacyLabels on DeckPrivacy {
  String get cloudValue => name;

  String get labelAr {
    switch (this) {
      case DeckPrivacy.private:
        return 'خاصة';
      case DeckPrivacy.unlisted:
        return 'بالرمز فقط';
      case DeckPrivacy.public:
        return 'مكتبة عامة';
    }
  }

  String get descriptionAr {
    switch (this) {
      case DeckPrivacy.private:
        return 'لا يمكن لأحد غيرك رؤيتها.';
      case DeckPrivacy.unlisted:
        return 'تُفتح فقط لمن يملك رمز المشاركة.';
      case DeckPrivacy.public:
        return 'تظهر في المكتبة العامة ويمكن لأي متعلّم إضافتها.';
    }
  }

  String get shortLabelAr {
    switch (this) {
      case DeckPrivacy.private:
        return 'خاصة';
      case DeckPrivacy.unlisted:
        return 'رمز';
      case DeckPrivacy.public:
        return 'عامة';
    }
  }
}

DeckPrivacy deckPrivacyFromCloud(String? value) {
  switch (value) {
    case 'unlisted':
      return DeckPrivacy.unlisted;
    case 'public':
      return DeckPrivacy.public;
    default:
      return DeckPrivacy.private;
  }
}
