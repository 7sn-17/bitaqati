/// Arabic month names, indexed by `DateTime.month - 1`.
///
/// The app has no `intl` dependency: one date is printed in two places, and a
/// whole locale database would be a heavy way to write twelve words.
const List<String> _arabicMonths = <String>[
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// Formats [date] the way an Arabic reader writes it: `28 يناير 2027`.
String formatArabicDate(DateTime date) {
  return '${date.day} ${_arabicMonths[date.month - 1]} ${date.year}';
}
