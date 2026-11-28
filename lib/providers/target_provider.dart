import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/mission_model.dart';
import '../models/target_model.dart';
import '../repositories/target_repository.dart';
import '../utils/currency_formatter.dart';
import '../utils/error_mapper.dart';
import 'mission_provider.dart';

class TargetProvider extends ChangeNotifier {
  final TargetRepository _repository;

  TargetProvider({TargetRepository? repository})
      : _repository = repository ?? TargetRepository();

  String? _uid;
  MissionProvider? _missionProvider;
  List<TargetItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastSavedAt;

  List<TargetItem> get items => List<TargetItem>.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRecentlySaved =>
      _lastSavedAt != null &&
      DateTime.now().difference(_lastSavedAt!).inMinutes < 5;
  bool get hasActiveSavingProgress {
    final item = pinnedItem;
    if (item == null || item.isSettled) return false;
    return item.savedAmount > 0 && item.savedAmount < item.targetAmount;
  }

  TargetItem? get pinnedItem {
    for (final item in _items) {
      if (item.isPinned && !item.isSettled) return item;
    }
    for (final item in _items) {
      if (!item.isSettled) return item;
    }
    return _items.isNotEmpty ? _items.first : null;
  }

  double get totalAllocated => _items
      .where((item) => !item.isSettled)
      .fold(0.0, (sum, item) => sum + item.savedAmount);

  /// Saldo bebas yang bisa dialokasikan.
  ///
  /// Dana target sudah dipindahkan keluar dari dompet saat dialokasikan
  /// (lihat alur transaksi alokasi), jadi tidak dikurangi [totalAllocated]
  /// lagi — kalau dikurangi, saldo akan terpotong dua kali.
  double availableToAllocate(double totalWalletBalance) =>
      totalWalletBalance > 0 ? totalWalletBalance : 0.0;

  void bindDependencies(String? newUid, MissionProvider missionProvider) {
    _missionProvider = missionProvider;
    updateUser(newUid);
  }

  void updateUser(String? newUid) {
    if (_uid == newUid) return;
    _uid = newUid;
    _items = [];
    _errorMessage = null;
    _lastSavedAt = null;

    if (newUid == null) {
      _isLoading = false;
      Future.microtask(notifyListeners);
      return;
    }

    _isLoading = true;
    Future.microtask(() {
      if (_uid == newUid) {
        loadTargets();
      }
    });
  }

  Future<void> loadTargets({bool silent = false}) async {
    final targetUid = _uid;
    if (targetUid == null) {
      _items = [];
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
      var fetched = await _repository.getTargets(targetUid);
      if (_uid != targetUid) return;
      final int firstActiveIndex =
          fetched.indexWhere((item) => !item.isSettled);
      final bool hasActivePinned =
          fetched.any((item) => item.isPinned && !item.isSettled);
      if (firstActiveIndex != -1 && !hasActivePinned) {
        final firstActiveId = fetched[firstActiveIndex].id;
        try {
          await _repository.togglePinTarget(
            uid: targetUid,
            targetId: firstActiveId,
            shouldPin: true,
          );
          if (_uid != targetUid) return;
          fetched = [
            for (final item in fetched)
              item.copyWith(isPinned: item.id == firstActiveId),
          ];
        } catch (e) {
          // Auto-pin bersifat best-effort: kegagalan penulisan (mis. saat offline)
          // tidak boleh menggagalkan pembacaan daftar target pengguna.
          debugPrint('Gagal menyematkan target otomatis: $e');
        }
      }
      _items = fetched;
      _errorMessage = null;
      if (_missionProvider != null && fetched.isNotEmpty) {
        unawaited(
          _missionProvider!.syncOneTimeTargetsCount(fetched.length),
        );
      }
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

  Future<TargetItem> createTarget({
    required String nama,
    required double targetAmount,
    required File imageFile,
    DateTime? deadline,
  }) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    final bool shouldAutoPin =
        !_items.any((item) => item.isPinned && !item.isSettled);
    final created = await _repository.createTarget(
      uid: targetUid,
      nama: nama,
      targetAmount: targetAmount,
      imageFile: imageFile,
      isPinned: shouldAutoPin,
      deadline: deadline,
    );
    if (_missionProvider != null) {
      unawaited(
        _missionProvider!.recordTrigger(MissionTrigger.createTarget),
      );
    }
    await loadTargets(silent: true);
    return created;
  }

  Future<void> updateTarget({
    required String targetId,
    required String nama,
    required double targetAmount,
    File? newImageFile,
    DateTime? deadline,
    bool clearDeadline = false,
  }) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    final trimmedName = nama.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Nama target tidak boleh kosong.');
    }
    if (targetAmount <= 0) {
      throw Exception('Nominal target harus lebih dari Rp 0.');
    }

    final index = _items.indexWhere((t) => t.id == targetId);
    if (index == -1) {
      throw Exception('Target menabung tidak ditemukan');
    }
    final existing = _items[index];
    if (existing.isSettled) {
      throw Exception('Target yang sudah selesai tidak dapat diubah.');
    }
    if (targetAmount + 0.0001 < existing.savedAmount) {
      throw Exception(
        'Nominal target tidak boleh di bawah dana terkumpul (${Formatters.rupiah(existing.savedAmount)}). Tarik sebagian dana terlebih dahulu.',
      );
    }

    await _repository.updateTarget(
      uid: targetUid,
      targetId: targetId,
      nama: trimmedName,
      targetAmount: targetAmount,
      newImageFile: newImageFile,
      deadline: deadline,
      clearDeadline: clearDeadline,
    );
    await loadTargets(silent: true);
  }

  /// Menambah/menarik dana target. Bila [walletId] diberikan, perpindahan dana
  /// antara dompet, target, dan transaksi riwayat dijalankan secara atomik via
  /// `TargetRepository.allocateFundsWithWallet`.
  Future<void> allocateTargetFunds({
    required String targetId,
    required double amountDelta,
    String? walletId,
    double? maxWithdrawable,
  }) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    if (amountDelta == 0) return;

    final index = _items.indexWhere((t) => t.id == targetId);
    if (index == -1) {
      throw Exception('Target menabung tidak ditemukan');
    }
    final target = _items[index];
    if (target.isSettled) {
      throw Exception('Target ini sudah diselesaikan.');
    }

    if (amountDelta > 0) {
      final remainingNeeded = (target.targetAmount - target.savedAmount)
          .clamp(0.0, double.infinity);
      if (amountDelta > remainingNeeded + 0.0001) {
        throw Exception('Nominal melebihi sisa target yang dibutuhkan.');
      }
    } else {
      final double withdrawLimit = maxWithdrawable != null
          ? (maxWithdrawable < target.savedAmount
              ? maxWithdrawable
              : target.savedAmount)
          : target.savedAmount;
      if (amountDelta.abs() > withdrawLimit + 0.0001) {
        throw Exception(
          'Nominal penarikan melebihi dana yang dapat ditarik dari target ini.',
        );
      }
    }

    if (walletId != null && walletId.trim().isNotEmpty) {
      await _repository.allocateFundsWithWallet(
        uid: targetUid,
        targetId: targetId,
        walletId: walletId.trim(),
        amountDelta: amountDelta,
        maxWithdrawable: maxWithdrawable,
      );
    } else {
      final double newSavedAmount =
          (target.savedAmount + amountDelta).clamp(0.0, target.targetAmount);
      await _repository.updateSavedAmount(
        uid: targetUid,
        targetId: targetId,
        savedAmount: newSavedAmount,
      );
    }

    if (amountDelta > 0) {
      _lastSavedAt = DateTime.now();
      if (_missionProvider != null) {
        unawaited(
          _missionProvider!.recordTrigger(MissionTrigger.saveTarget),
        );
      }
    }
    await loadTargets(silent: true);
  }

  /// Menandai target selesai (dana sudah dipakai untuk membeli barang).
  /// Bila [walletId] diberikan, transaksi pengeluaran (`skipWalletEffect: true`)
  /// dan penandaan `isSettled: true` dijalankan atomik dalam satu transaksi.
  Future<void> settleTarget(
    String targetId, {
    String? walletId,
    String categoryId = 'c6',
  }) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }

    final index = _items.indexWhere((t) => t.id == targetId);
    if (index == -1) {
      throw Exception('Target menabung tidak ditemukan');
    }
    final target = _items[index];
    if (target.isSettled) {
      throw Exception('Target ini sudah diselesaikan sebelumnya.');
    }

    if (walletId != null) {
      if (!target.isAchieved || target.savedAmount <= 0) {
        throw Exception('Target belum mencapai 100% untuk diselesaikan.');
      }
      await _repository.settleTargetWithExpense(
        uid: targetUid,
        targetId: targetId,
        walletId: walletId,
        categoryId: categoryId,
      );
    } else {
      await _repository.markSettled(
        uid: targetUid,
        targetId: targetId,
        isSettled: true,
      );
    }
    await loadTargets(silent: true);
  }

  Future<void> togglePin(TargetItem item) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    if (item.isPinned || item.isSettled) return;
    await _repository.togglePinTarget(
      uid: targetUid,
      targetId: item.id,
      shouldPin: true,
    );
    await loadTargets(silent: true);
  }

  Future<void> deleteTarget(
    String targetId, {
    double? walletBackedAmount,
  }) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }

    final index = _items.indexWhere((t) => t.id == targetId);
    if (index != -1) {
      final target = _items[index];
      if (!target.isSettled) {
        final double guardedFunds = walletBackedAmount ?? target.savedAmount;
        if (guardedFunds > 0.0001) {
          throw Exception(
            'Tarik seluruh dana tabungan (${Formatters.rupiah(guardedFunds)}) '
            'kembali ke dompet terlebih dahulu sebelum menghapus target ini.',
          );
        }
      }
    }

    await _repository.deleteTarget(targetUid, targetId);
    await loadTargets(silent: true);
  }
}
