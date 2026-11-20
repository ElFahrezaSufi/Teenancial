import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../config/app_constants.dart';
import '../../data/feen_catalog.dart';
import '../../models/dompet_model.dart';
import '../../models/transaction_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/error_mapper.dart';
import '../feen/feen_avatar.dart';

/// Helper murni untuk menentukan kelayakan penampilan sheet onboarding saldo awal.
class InitialBalanceOnboardingHelper {
  const InitialBalanceOnboardingHelper._();

  /// Onboarding saldo awal hanya layak ditawarkan jika:
  /// 1. Profil sudah termuat dan `initialBalanceOnboardingDone == false`,
  /// 2. Belum pernah diselesaikan/dilewati secara lokal untuk UID tersebut,
  /// 3. Belum ada riwayat transaksi apa pun, dan
  /// 4. Hanya memiliki satu dompet bawaan (`d1`) dengan saldo Rp 0.
  static bool shouldShowOnboarding({
    required UserModel? profile,
    required List<DompetItem> dompets,
    required List<TransactionModel> transactions,
    required bool isLocalDismissed,
  }) {
    if (profile == null) return false;
    if (profile.initialBalanceOnboardingDone) return false;
    if (isLocalDismissed) return false;
    if (transactions.isNotEmpty) return false;
    if (dompets.length != 1) return false;

    final onlyWallet = dompets.first;
    return onlyWallet.id == AppConstants.defaultNewWalletId &&
        onlyWallet.jumlah.abs() < 0.0001;
  }
}

/// Data hasil isian pengguna pada sheet onboarding saldo awal.
class InitialBalanceSetupInput {
  final double cashInitialBalance;
  final DompetItem? extraWallet;

  const InitialBalanceSetupInput({
    required this.cashInitialBalance,
    this.extraWallet,
  });
}

/// Bottom sheet opsional bagi pengguna baru untuk mengatur saldo awal Dompet
/// Tunai (`d1`) dan (opsional) menambahkan e-wallet / rekening utama.
class InitialBalanceOnboardingSheet extends StatefulWidget {
  final String displayName;
  final int userLevel;
  final Map<String, String> feenEquipped;
  final Future<void> Function(InitialBalanceSetupInput input) onSave;
  final Future<void> Function() onSkip;

  const InitialBalanceOnboardingSheet({
    super.key,
    required this.displayName,
    this.userLevel = 1,
    this.feenEquipped = const {},
    required this.onSave,
    required this.onSkip,
  });

  @override
  State<InitialBalanceOnboardingSheet> createState() =>
      _InitialBalanceOnboardingSheetState();
}

class _InitialBalanceOnboardingSheetState
    extends State<InitialBalanceOnboardingSheet> {
  final TextEditingController _cashBalanceCtrl = TextEditingController();
  final TextEditingController _extraNameCtrl = TextEditingController();
  final TextEditingController _extraBalanceCtrl = TextEditingController();

  bool _addExtraWallet = false;
  JenisDompet _extraWalletType = JenisDompet.accounts;
  bool _isSubmitting = false;
  String? _inlineError;

  @override
  void dispose() {
    _cashBalanceCtrl.dispose();
    _extraNameCtrl.dispose();
    _extraBalanceCtrl.dispose();
    super.dispose();
  }

  String get _firstName {
    final trimmed = widget.displayName.trim();
    if (trimmed.isEmpty) return 'Teman';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  double _parseRupiah(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0.0;
    return double.tryParse(digits) ?? 0.0;
  }

  Future<void> _handleSave() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    final cashAmount = _parseRupiah(_cashBalanceCtrl.text);
    DompetItem? extraWallet;

    if (_addExtraWallet) {
      final extraName = _extraNameCtrl.text.trim();
      if (extraName.isEmpty) {
        setState(() {
          _inlineError = 'Nama dompet tambahan wajib diisi (mis. Dana, GoPay, BCA).';
        });
        return;
      }
      extraWallet = DompetItem(
        id: '',
        jenis: _extraWalletType,
        nama: extraName,
        jumlah: _parseRupiah(_extraBalanceCtrl.text),
      );
    }

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    try {
      await widget.onSave(
        InitialBalanceSetupInput(
          cashInitialBalance: cashAmount,
          extraWallet: extraWallet,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inlineError = ErrorMapper.message(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleSkip() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    try {
      await widget.onSkip();
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inlineError = ErrorMapper.message(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        color: primaryGreen,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      hintStyle: TextStyle(
        color: primaryGreen.withValues(alpha: 0.45),
        fontFamily: 'Inter',
        fontSize: 14,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryGreen, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: primaryGreen.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryGreen, width: 1.8),
      ),
    );
  }

  Widget _buildWalletTypeChip(JenisDompet jenis) {
    final bool selected = _extraWalletType == jenis;
    return Expanded(
      child: GestureDetector(
        onTap: _isSubmitting
            ? null
            : () => setState(() => _extraWalletType = jenis),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primaryGreen,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              jenis.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : primaryGreen,
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: false,
      child: Container(
        decoration: const BoxDecoration(
          color: scaffoldBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: primaryGreen.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header dengan maskot Feen
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FeenAvatar(
                        level: widget.userLevel,
                        pose: FeenPose.levelup,
                        equipped: widget.feenEquipped,
                        size: 62,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Atur Saldo Awalmu, $_firstName!',
                              style: const TextStyle(
                                color: primaryGreen,
                                fontSize: 17,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Masukkan uang yang sudah kamu pegang sekarang supaya siap mencatat pengeluaran. Belum ada saldo? Kamu bebas langsung mulai dari Rp 0.',
                              style: TextStyle(
                                color: primaryGreen.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Catatan akuntansi
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryGreen.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: orangeText,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Saldo awal tidak dihitung sebagai pemasukan baru di Laporan Keuangan.',
                            style: TextStyle(
                              color: primaryGreen,
                              fontSize: 11.5,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bagian 1: Dompet Tunai (d1)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: primaryGreen.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              color: primaryGreen,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Saldo Awal Dompet Tunai',
                              style: TextStyle(
                                color: primaryGreen,
                                fontSize: 13.5,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const Key('onboarding_cash_balance_field'),
                          controller: _cashBalanceCtrl,
                          enabled: !_isSubmitting,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            CurrencyInputFormatter(),
                          ],
                          onChanged: (_) {
                            if (_inlineError != null) {
                              setState(() => _inlineError = null);
                            }
                          },
                          style: const TextStyle(
                            color: primaryGreen,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          decoration: _fieldDecoration(
                            hintText: '0',
                            prefixText: 'Rp ',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Biarkan 0 jika belum memiliki uang tunai.',
                          style: TextStyle(
                            color: primaryGreen.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bagian 2: Opsional tambah e-wallet / rekening utama
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: primaryGreen.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Sekalian tambah e-wallet / rekening utama?',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontSize: 13,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Switch(
                              key: const Key('onboarding_extra_wallet_switch'),
                              value: _addExtraWallet,
                              activeTrackColor: primaryGreen,
                              onChanged: _isSubmitting
                                  ? null
                                  : (val) => setState(() {
                                        _addExtraWallet = val;
                                        _inlineError = null;
                                      }),
                            ),
                          ],
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: _addExtraWallet
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    bottom: 8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          _buildWalletTypeChip(
                                            JenisDompet.accounts,
                                          ),
                                          const SizedBox(width: 8),
                                          _buildWalletTypeChip(
                                            JenisDompet.card,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      TextField(
                                        key: const Key(
                                          'onboarding_extra_name_field',
                                        ),
                                        controller: _extraNameCtrl,
                                        enabled: !_isSubmitting,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        onChanged: (_) {
                                          if (_inlineError != null) {
                                            setState(() => _inlineError = null);
                                          }
                                        },
                                        style: const TextStyle(
                                          color: primaryGreen,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        decoration: _fieldDecoration(
                                          hintText: 'Nama dompet (mis. Dana, GoPay, BCA)',
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextField(
                                        key: const Key(
                                          'onboarding_extra_balance_field',
                                        ),
                                        controller: _extraBalanceCtrl,
                                        enabled: !_isSubmitting,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          CurrencyInputFormatter(),
                                        ],
                                        style: const TextStyle(
                                          color: primaryGreen,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                        decoration: _fieldDecoration(
                                          hintText: '0',
                                          prefixText: 'Rp ',
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),

                  if (_inlineError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _inlineError!,
                              style: const TextStyle(
                                color: Color(0xFFB71C1C),
                                fontSize: 12,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Tombol Utama: Simpan Saldo Awal
                  ElevatedButton(
                    key: const Key('onboarding_save_button'),
                    onPressed: _isSubmitting ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Simpan Saldo Awal',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),

                  // Tombol Sekunder: Mulai dari Rp 0 / Lewati
                  OutlinedButton(
                    key: const Key('onboarding_skip_button'),
                    onPressed: _isSubmitting ? null : _handleSkip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryGreen,
                      backgroundColor: inputBg,
                      side: const BorderSide(color: primaryGreen, width: 1.3),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: const Text(
                      'Mulai dari Rp 0 / Lewati',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
