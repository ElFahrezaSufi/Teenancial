class ContactModel {
  final String id;
  final String name;

  const ContactModel({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory ContactModel.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    return ContactModel(
      id: docId ?? (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
    );
  }

  ContactModel copyWith({
    String? id,
    String? name,
  }) {
    return ContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}
