import 'dart:math';

/// Apple-Arcade-style random display names. Used to pre-fill the name field when the connected
/// wallet gives us no label (no .skr / Seed Vault name), so the field is never blank. The user
/// only edits it if they want to.
const _adjectives = [
  'Swift', 'Cosmic', 'Lucky', 'Golden', 'Turbo', 'Neon', 'Mighty', 'Clever', 'Rapid', 'Bold',
  'Sly', 'Brave', 'Sunny', 'Wild', 'Nova', 'Zesty', 'Prime', 'Vivid', 'Snappy', 'Royal',
];

const _nouns = [
  'Falcon', 'Otter', 'Comet', 'Tiger', 'Panda', 'Fox', 'Yeti', 'Orca', 'Lynx', 'Raven',
  'Wolf', 'Hawk', 'Bison', 'Gecko', 'Puma', 'Koala', 'Heron', 'Ibis', 'Moose', 'Shark',
];

/// A deterministic-ish suggestion seeded off the wallet address so the same wallet keeps the same
/// suggested name between sessions (feels stable), plus a 2-digit tag for uniqueness.
String suggestName(String seed) {
  var h = 0;
  for (var i = 0; i < seed.length; i++) {
    h = (h * 31 + seed.codeUnitAt(i)) & 0x7fffffff;
  }
  final adj = _adjectives[h % _adjectives.length];
  final noun = _nouns[(h ~/ _adjectives.length) % _nouns.length];
  final tag = h % 90 + 10; // 10..99
  return '$adj$noun$tag';
}

/// Fully random suggestion (no seed) for a "shuffle" affordance.
String randomName() {
  final r = Random.secure();
  return '${_adjectives[r.nextInt(_adjectives.length)]}${_nouns[r.nextInt(_nouns.length)]}${r.nextInt(90) + 10}';
}
