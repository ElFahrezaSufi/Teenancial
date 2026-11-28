import 'package:flutter/foundation.dart';
import '../models/contact_model.dart';
import '../repositories/contact_repository.dart';
import '../utils/error_mapper.dart';

class ContactProvider extends ChangeNotifier {
  final ContactRepository _repository;

  ContactProvider({ContactRepository? repository})
      : _repository = repository ?? ContactRepository();

  String? _uid;
  List<ContactModel> _contacts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ContactModel> get contacts => List<ContactModel>.unmodifiable(_contacts);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ContactModel? getContactById(String? id) {
    if (id == null) return null;
    for (final c in _contacts) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Mencari kontak berdasarkan nama (case-insensitive & trimmed).
  ContactModel? findByName(String? rawName) {
    final trimmed = rawName?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    for (final c in _contacts) {
      if (c.name.trim().toLowerCase() == lower) {
        return c;
      }
    }
    return null;
  }

  void updateUser(String? newUid) {
    if (_uid == newUid) return;
    _uid = newUid;
    _contacts = [];
    _errorMessage = null;

    if (newUid == null) {
      _isLoading = false;
      Future.microtask(notifyListeners);
      return;
    }

    _isLoading = true;
    Future.microtask(() {
      if (_uid == newUid) {
        loadContacts();
      }
    });
  }

  Future<void> loadContacts({bool silent = false}) async {
    final targetUid = _uid;
    if (targetUid == null) {
      _contacts = [];
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final fetched = await _repository.getContacts(targetUid);
      if (_uid != targetUid) return;
      _contacts = fetched;
      _errorMessage = null;
    } catch (e) {
      if (_uid != targetUid) return;
      _errorMessage = ErrorMapper.message(e);
    } finally {
      if (_uid == targetUid) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<ContactModel> addContact(
    String name, {
    String? note,
    bool rejectDuplicate = false,
  }) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    final created = await _repository.addContact(
      targetUid,
      name,
      note: note,
      rejectDuplicate: rejectDuplicate,
    );
    await loadContacts(silent: true);
    return created;
  }

  Future<ContactModel> updateContact(ContactModel contact) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    final updated = await _repository.updateContact(targetUid, contact);
    await loadContacts(silent: true);
    return updated;
  }

  Future<void> deleteContact(String contactId) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    await _repository.deleteContact(targetUid, contactId);
    await loadContacts(silent: true);
  }
}
