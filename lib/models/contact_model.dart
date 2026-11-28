class ContactModel {
  final String id;
  final String name;
  final String? note;

  const ContactModel({
    required this.id,
    required this.name,
    this.note,
  });

  /// Mengambil 1 sampai 2 huruf inisial kapital untuk avatar daftar kontak.
  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }

  Map<String, dynamic> toMap() {
    final trimmedNote = note?.trim();
    return {
      'id': id,
      'name': name.trim(),
      'note': (trimmedNote != null && trimmedNote.isNotEmpty)
          ? trimmedNote
          : null,
    };
  }

  factory ContactModel.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    final rawNote = (map['note'] as String?)?.trim();
    return ContactModel(
      id: docId ?? (map['id'] as String?) ?? '',
      name: ((map['name'] as String?) ?? '').trim(),
      note: (rawNote != null && rawNote.isNotEmpty) ? rawNote : null,
    );
  }

  ContactModel copyWith({
    String? id,
    String? name,
    String? note,
    bool clearNote = false,
  }) {
    return ContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      note: clearNote ? null : (note ?? this.note),
    );
  }
}
