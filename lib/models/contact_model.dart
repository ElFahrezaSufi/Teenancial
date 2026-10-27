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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}
