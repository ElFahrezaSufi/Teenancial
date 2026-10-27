class ContactModel {
  final String id;
  final String name;

  ContactModel({
    required this.id,
    required this.name,
  });

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
