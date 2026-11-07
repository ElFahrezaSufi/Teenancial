import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class FirestoreService {
  final FirebaseFirestore? _firestore;

  FirestoreService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get db => _firestore ?? FirebaseFirestore.instance;

  static final FirestoreService instance = FirestoreService();

  WriteBatch batch() => db.batch();

  Future<T> runTransaction<T>(TransactionHandler<T> transactionHandler) {
    return db.runTransaction(transactionHandler);
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
}
