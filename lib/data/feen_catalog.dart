library;

enum FeenSlot {
  neck('Leher'),
  face('Wajah'),
  head('Kepala'),
  frame('Bingkai Profil');

  final String label;
  const FeenSlot(this.label);
}

enum FeenTier {
  rookie('Rookie'),
  saver('Saver'),
  pro('Pro');

  final String label;
  const FeenTier(this.label);
}

enum FeenPose { normal, saving, learning, levelup, alert }

FeenTier tierForLevel(int level) {
  if (level >= 30) return FeenTier.pro;
  if (level >= 15) return FeenTier.saver;
  return FeenTier.rookie;
}

class FeenAccessory {
  final String id;
  final String name;
  final FeenSlot slot;
  final int unlockLevel;
  final double frameScale;
  final double frameOffsetY;

  const FeenAccessory({
    required this.id,
    required this.name,
    required this.slot,
    required this.unlockLevel,
    this.frameScale = 1.52,
    this.frameOffsetY = 0.0,
  });

  String get asset => slot == FeenSlot.frame
      ? 'assets/images/$id.png'
      : 'assets/feen/accessories/${slot.name}/$id.png';
}

const List<FeenAccessory> feenCatalog = [
  FeenAccessory(
      id: 'beanie', name: 'Topi Beanie', slot: FeenSlot.head, unlockLevel: 2),
  FeenAccessory(
      id: 'Cap', name: 'Topi Baseball', slot: FeenSlot.head, unlockLevel: 3),
  FeenAccessory(
      id: 'crown', name: 'Mahkota', slot: FeenSlot.head, unlockLevel: 10),
  FeenAccessory(
      id: 'glasses', name: 'Kacamata', slot: FeenSlot.face, unlockLevel: 4),
  FeenAccessory(
      id: 'headphones',
      name: 'Headphones',
      slot: FeenSlot.face,
      unlockLevel: 15),
  FeenAccessory(id: 'scarf', name: 'Syal', slot: FeenSlot.neck, unlockLevel: 5),
  FeenAccessory(
      id: 'bowtie',
      name: 'Dasi Kupu-kupu',
      slot: FeenSlot.neck,
      unlockLevel: 8),
  FeenAccessory(
      id: 'frame_matcha',
      name: 'Matcha Swirl',
      slot: FeenSlot.frame,
      unlockLevel: 5),
  FeenAccessory(
      id: 'frame_cloud',
      name: 'Dreamy Cloud',
      slot: FeenSlot.frame,
      unlockLevel: 11,
      frameScale: 1.54,
      frameOffsetY: 0.028),
  FeenAccessory(
      id: 'frame_explorer',
      name: 'Smart Explorer',
      slot: FeenSlot.frame,
      unlockLevel: 16),
  FeenAccessory(
      id: 'frame_botanical',
      name: 'Botanical Wreath',
      slot: FeenSlot.frame,
      unlockLevel: 22),
  FeenAccessory(
      id: 'frame_gold',
      name: 'Prosperity Gold',
      slot: FeenSlot.frame,
      unlockLevel: 30),
];

FeenAccessory? feenById(String? id) {
  if (id == null) return null;
  for (final a in feenCatalog) {
    if (a.id == id) return a;
  }
  return null;
}

List<FeenAccessory> feenBySlot(FeenSlot slot) =>
    feenCatalog.where((a) => a.slot == slot).toList();

List<FeenAccessory> feenUnlockedBetween(int oldLevel, int newLevel) {
  return feenCatalog
      .where((a) => a.unlockLevel > oldLevel && a.unlockLevel <= newLevel)
      .toList();
}
