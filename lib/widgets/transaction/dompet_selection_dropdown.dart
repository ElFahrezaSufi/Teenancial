import 'package:flutter/material.dart';
import '../../models/dompet_model.dart';
import '../common/custom_dropdown_field.dart';

class DompetSelectionDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final List<DompetItem> dompets;
  final String? selectedDompetId;
  final void Function(String?) onChanged;
  final String? Function(String?)? validator;

  const DompetSelectionDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.dompets,
    this.selectedDompetId,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, String> displayMap = {};
    final Set<String> usedLabels = {};

    for (final dompet in dompets) {
      String baseDisplay = '${dompet.nama} (${dompet.jenis.label})';
      String display = baseDisplay;
      int suffix = 2;
      while (usedLabels.contains(display)) {
        display = '$baseDisplay #$suffix';
        suffix++;
      }
      usedLabels.add(display);
      displayMap[dompet.id] = display;
    }

    final items = displayMap.values.toList();
    final value =
        selectedDompetId != null ? displayMap[selectedDompetId] : null;

    return CustomDropdownField(
      label: label,
      hint: hint,
      value: value,
      items: items,
      onChanged: (String? newValue) {
        if (newValue != null) {
          final entry =
              displayMap.entries.firstWhere((e) => e.value == newValue);
          onChanged(entry.key);
        } else {
          onChanged(null);
        }
      },
      validator: (String? val) {
        if (validator != null) {
          return validator!(val);
        }
        if (val == null || val.isEmpty) {
          return 'Pilih sumber dana';
        }
        return null;
      },
    );
  }
}
