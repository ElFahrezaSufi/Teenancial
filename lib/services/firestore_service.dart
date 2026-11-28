import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'connectivity_service.dart';

class FirestoreService {
  final FirebaseFirestore? _firestore;
  final ConnectivityService _connectivity;

  FirestoreService({
    FirebaseFirestore? firestore,
    ConnectivityService? connectivity,
  })  : _firestore = firestore,
        _connectivity = connectivity ?? ConnectivityService.instance;

  FirebaseFirestore get db => _firestore ?? FirebaseFirestore.instance;

  static final FirestoreService instance = FirestoreService();

  static const Duration defaultServerTimeout = Duration(seconds: 8);

  /// Memastikan perangkat sedang online sebelum menjalankan operasi tulis atau
  /// transaksi atomik Firestore. Melempar [OfflineException] seketika bila
  /// perangkat diketahui offline agar UI tidak menggantung menunggu ACK server.
  void ensureOnline({String? actionLabel}) {
    if (_connectivity.isOffline) {
      final suffix = (actionLabel != null && actionLabel.trim().isNotEmpty)
          ? actionLabel.trim()
          : 'menyimpan perubahan';
      throw OfflineException(
        'Tidak ada koneksi internet. Hubungkan ke internet untuk $suffix.',
      );
    }
  }

  bool _isTransientNetworkError(FirebaseException e) {
    return e.code == 'unavailable' || e.code == 'deadline-exceeded';
  }

  /// Membaca koleksi/query dengan strategi cache-fallback:
  /// - Jika sudah diketahui offline → langsung baca dari cache lokal (`0 ms`).
  /// - Jika online → baca dari server dengan timeout singkat, dan otomatis
  ///   fallback ke cache lokal apabila server tidak terjangkau / timeout.
  Future<QuerySnapshot<Map<String, dynamic>>> getQuerySnapshot(
    Query<Map<String, dynamic>> query, {
    Duration serverTimeout = defaultServerTimeout,
  }) async {
    if (_connectivity.isOffline) {
      _connectivity.markUsingCachedData();
      return query.get(const GetOptions(source: Source.cache));
    }

    try {
      final snap = await query.get().timeout(serverTimeout);
      if (snap.metadata.isFromCache) {
        _connectivity.markUsingCachedData();
      } else {
        _connectivity.markOnlineFromServer();
      }
      return snap;
    } on TimeoutException {
      _connectivity.markOfflineFromError();
      return query.get(const GetOptions(source: Source.cache));
    } on FirebaseException catch (e) {
      if (_isTransientNetworkError(e)) {
        _connectivity.markOfflineFromError();
        return query.get(const GetOptions(source: Source.cache));
      }
      rethrow;
    }
  }

  /// Membaca satu dokumen dengan strategi cache-fallback. Apabila dokumen belum
  /// pernah di-cache saat perangkat offline, melempar [OfflineException].
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocumentSnapshot(
    DocumentReference<Map<String, dynamic>> docRef, {
    Duration serverTimeout = defaultServerTimeout,
  }) async {
    if (_connectivity.isOffline) {
      _connectivity.markUsingCachedData();
      try {
        return await docRef.get(const GetOptions(source: Source.cache));
      } on FirebaseException {
        throw const OfflineException(
          'Data belum tersedia di cache lokal. Hubungkan ke internet terlebih dahulu.',
        );
      }
    }

    try {
      final snap = await docRef.get().timeout(serverTimeout);
      if (snap.metadata.isFromCache) {
        _connectivity.markUsingCachedData();
      } else {
        _connectivity.markOnlineFromServer();
      }
      return snap;
    } on TimeoutException {
      _connectivity.markOfflineFromError();
      try {
        return await docRef.get(const GetOptions(source: Source.cache));
      } on FirebaseException {
        throw const OfflineException(
          'Koneksi internet terputus dan data belum tersedia di cache lokal.',
        );
      }
    } on FirebaseException catch (e) {
      if (_isTransientNetworkError(e)) {
        _connectivity.markOfflineFromError();
        try {
          return await docRef.get(const GetOptions(source: Source.cache));
        } on FirebaseException {
          throw const OfflineException(
            'Koneksi internet terputus dan data belum tersedia di cache lokal.',
          );
        }
      }
      rethrow;
    }
  }

  WriteBatch batch() => db.batch();

  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    String? actionLabel,
  }) async {
    ensureOnline(actionLabel: actionLabel);
    try {
      return await db.runTransaction(transactionHandler);
    } on FirebaseException catch (e) {
      if (_isTransientNetworkError(e)) {
        _connectivity.markOfflineFromError();
        final suffix = (actionLabel != null && actionLabel.trim().isNotEmpty)
            ? actionLabel.trim()
            : 'menyimpan perubahan';
        throw OfflineException(
          'Koneksi internet terputus. Hubungkan ke internet untuk $suffix.',
        );
      }
      rethrow;
    } on TimeoutException {
      _connectivity.markOfflineFromError();
      final suffix = (actionLabel != null && actionLabel.trim().isNotEmpty)
          ? actionLabel.trim()
          : 'menyimpan perubahan';
      throw OfflineException(
        'Koneksi internet terputus. Hubungkan ke internet untuk $suffix.',
      );
    }
  }

  CollectionReference<Map<String, dynamic>> get usersCol =>
      db.collection(AppConstants.usersCollection);

  DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      usersCol.doc(uid);

  CollectionReference<Map<String, dynamic>> walletsCol(String uid) =>
      userDoc(uid).collection(AppConstants.walletsSubcollection);

  CollectionReference<Map<String, dynamic>> transactionsCol(String uid) =>
      userDoc(uid).collection(AppConstants.transactionsSubcollection);

  CollectionReference<Map<String, dynamic>> contactsCol(String uid) =>
      userDoc(uid).collection(AppConstants.contactsSubcollection);

  CollectionReference<Map<String, dynamic>> targetsCol(String uid) =>
      userDoc(uid).collection(AppConstants.targetsSubcollection);

  CollectionReference<Map<String, dynamic>> categoriesCol(String uid) =>
      userDoc(uid).collection(AppConstants.categoriesSubcollection);

  CollectionReference<Map<String, dynamic>> recurringCol(String uid) =>
      userDoc(uid).collection(AppConstants.recurringSubcollection);

  CollectionReference<Map<String, dynamic>> get belajarLevelsCol =>
      db.collection(AppConstants.belajarLevelsCollection);

  CollectionReference<Map<String, dynamic>> get belajarModulesCol =>
      db.collection(AppConstants.belajarModulesCollection);
}
