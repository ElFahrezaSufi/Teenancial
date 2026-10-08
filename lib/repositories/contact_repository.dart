import 'package:flutter/foundation.dart';
import '../data/contact_model.dart';

class ContactRepository extends ChangeNotifier {
  ContactRepository._();
  static final ContactRepository instance = ContactRepository._();

  final List<ContactModel> _contacts = [
    ContactModel(id: 'c1', name: 'Budi'),
    ContactModel(id: 'c2', name: 'Siti'),
  ];

  Future<List<ContactModel>> getContacts() async {
    // Simulasi loading ringan
    await Future.delayed(const Duration(milliseconds: 300));
    return List<ContactModel>.from(_contacts);
  }

  Future<ContactModel> addContact(String name) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Cek apakah nama sudah ada (case-insensitive)
    final existingIndex = _contacts.indexWhere((c) => c.name.toLowerCase() == name.toLowerCase());
    if (existingIndex != -1) {
      return _contacts[existingIndex];
    }

    final newContact = ContactModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );
    _contacts.add(newContact);
    notifyListeners();
    return newContact;
  }
}
