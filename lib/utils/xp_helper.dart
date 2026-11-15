class XpHelper {
  XpHelper._();

  static const int baseXpPerLevel = 500;
  static const int extraXpPerLevel = 250;

  static int xpNeededForNext(int level) {
    final l = level < 1 ? 1 : level;
    return baseXpPerLevel + (l - 1) * extraXpPerLevel;
  }

  static int totalXpForLevel(int level) {
    if (level <= 1) return 0;
    final n = level - 1;
    return n * baseXpPerLevel + (extraXpPerLevel * n * (n - 1)) ~/ 2;
  }

  static int levelFromXp(int xp) {
    var level = 1;
    var remaining = xp < 0 ? 0 : xp;
    while (remaining >= xpNeededForNext(level)) {
      remaining -= xpNeededForNext(level);
      level++;
    }
    return level;
  }

  static int xpIntoLevel(int xp) {
    final safeXp = xp < 0 ? 0 : xp;
    return safeXp - totalXpForLevel(levelFromXp(safeXp));
  }
}

class XpGainResult {
  final int oldLevel;
  final int newLevel;

  const XpGainResult({required this.oldLevel, required this.newLevel});

  bool get leveledUp => newLevel > oldLevel;
}
