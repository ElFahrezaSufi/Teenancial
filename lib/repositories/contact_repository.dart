import '../models/contact_model.dart';
import '../services/firestore_service.dart';

class ContactRepository {
  final FirestoreService _firestoreService;

  ContactRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService.instance;

  Future<List<ContactModel>> getContacts(String uid) async {
    final snapshot = await _firestoreService.contactsCol(uid).get();
    final items = snapshot.docs
        .map((doc) => ContactModel.fromMap(doc.data(), docId: doc.id))
        .toList();
    items.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return items;
  }

  Future<ContactModel> addContact(String uid, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Nama kontak tidak boleh kosong');
    }

    final existing = await getContacts(uid);
    final matchIndex = existing.indexWhere(
      (c) => c.name.toLowerCase() == trimmedName.toLowerCase(),
    );
    if (matchIndex != -1) {
      return existing[matchIndex];
    }

    final newContact = ContactModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: trimmedName,
    );

    await _firestoreService
        .contactsCol(uid)
        .doc(newContact.id)
        .set(newContact.toMap());

    return newContact;
  }

  Future<void> deleteContact(String uid, String contactId) async {
    await _firestoreService.contactsCol(uid).doc(contactId).delete();
  }
}
