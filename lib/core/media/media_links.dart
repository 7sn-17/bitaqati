import '../widgets/card_markup.dart';

/// Every picture and voice note a stored card body points at.
///
/// The markup regexes live in card_markup.dart, which stays the one definition
/// of what a media token looks like. This file only turns them into a list, so
/// the cleanup path can never drift from the renderer: a token the review
/// screen shows is a token the deleter knows about.
List<String> mediaUrlsIn(String text) {
  if (text.isEmpty) {
    return const <String>[];
  }
  final List<String> urls = <String>[];
  for (final RegExpMatch match in kImageRegex.allMatches(text)) {
    final String url = (match.group(2) ?? '').trim();
    if (url.isNotEmpty) {
      urls.add(url);
    }
  }
  for (final RegExpMatch match in kAudioRegex.allMatches(text)) {
    final String url = (match.group(2) ?? '').trim();
    if (url.isNotEmpty) {
      urls.add(url);
    }
  }
  return urls;
}

/// The union of [mediaUrlsIn] over several bodies, without duplicates.
///
/// A card that shows the same diagram on both sides is one file, not two, and
/// asking the server to delete it twice would only produce a failure entry.
List<String> mediaUrlsInAll(Iterable<String> texts) {
  final Set<String> unique = <String>{};
  for (final String text in texts) {
    unique.addAll(mediaUrlsIn(text));
  }
  return unique.toList(growable: false);
}
