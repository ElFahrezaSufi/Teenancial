class TargetItem {
  final String nama;
  final double targetAmount;
  final String imageUrl;
  bool isPinned;

  TargetItem({
    required this.nama,
    required this.targetAmount,
    required this.imageUrl,
    this.isPinned = false,
  });
}

class TargetData {
  TargetData._();
  static final TargetData instance = TargetData._();

  final List<TargetItem> items = [];

  void pinItem(TargetItem itemToPin) {
    for (var item in items) {
      item.isPinned = (item == itemToPin);
    }
  }

  TargetItem? get pinnedItem {
    try {
      return items.firstWhere((element) => element.isPinned);
    } catch (e) {
      return null;
    }
  }
}
