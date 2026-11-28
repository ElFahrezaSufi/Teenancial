import 'package:material_ui/material_ui.dart';
import '../../models/user_model.dart';
import '../../theme/app_colors.dart';
import '../../utils/error_mapper.dart';
import 'feen_avatar.dart';

/// Bottom sheet cepat untuk mengatur personalisasi Tanya Feen
/// (Status Pendidikan / Pekerjaan dan Gaya Bahasa Feen).
class FeenPersonalizationSheet extends StatefulWidget {
  final String? initialOccupation;
  final FeenTone initialTone;
  final int userLevel;
  final Map<String, String> feenEquipped;
  final Future<void> Function(String? occupationStatus, FeenTone tone) onSave;

  const FeenPersonalizationSheet({
    super.key,
    required this.initialOccupation,
    required this.initialTone,
    required this.userLevel,
    required this.feenEquipped,
    required this.onSave,
  });

  @override
  State<FeenPersonalizationSheet> createState() =>
      _FeenPersonalizationSheetState();
}

class _FeenPersonalizationSheetState extends State<FeenPersonalizationSheet> {
  String? _selectedOccupation;
  late FeenTone _selectedTone;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedOccupation = widget.initialOccupation;
    _selectedTone = widget.initialTone;
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await widget.onSave(_selectedOccupation, _selectedTone);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = ErrorMapper.message(e);
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Container(
      margin: const EdgeInsets.only(top: 2),
      decoration: const BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 1.5, left: 1.5, right: 1.5),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: appBarBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.5)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: primaryGreen.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      FeenAvatar(
                        level: widget.userLevel,
                        equipped: widget.feenEquipped,
                        size: 42,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personalisasi Feen',
                              style: TextStyle(
                                color: primaryGreen,
                                fontSize: 17,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Biar contoh dan gaya bicara Feen makin cocok denganmu.',
                              style: TextStyle(
                                color: primaryGreen,
                                fontSize: 12,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Status Pendidikan / Pekerjaan (Opsional)',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 13,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildOccupationChip(null, 'Belum diisi'),
                      for (final option in UserModel.occupationOptions)
                        _buildOccupationChip(option, option),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Gaya Bahasa Feen',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 13,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final tone in FeenTone.values) ...[
                    _buildToneOption(tone),
                    const SizedBox(height: 8),
                  ],
                  if (_errorText != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        _errorText!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Simpan Preferensi',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Inter',
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

  Widget _buildOccupationChip(String? value, String label) {
    final isSelected = _selectedOccupation == value;
    return GestureDetector(
      onTap: _isSaving ? null : () => setState(() => _selectedOccupation = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : scaffoldBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: primaryGreen,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : primaryGreen,
            fontSize: 12,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildToneOption(FeenTone tone) {
    final isSelected = _selectedTone == tone;
    return Material(
      color: isSelected ? cardBg : scaffoldBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _isSaving ? null : () => setState(() => _selectedTone = tone),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? primaryGreen
                  : primaryGreen.withValues(alpha: 0.25),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tone.label,
                      style: const TextStyle(
                        color: primaryGreen,
                        fontSize: 13,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tone.description,
                      style: TextStyle(
                        color: primaryGreen.withValues(alpha: 0.72),
                        fontSize: 11,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? primaryGreen
                    : primaryGreen.withValues(alpha: 0.35),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
