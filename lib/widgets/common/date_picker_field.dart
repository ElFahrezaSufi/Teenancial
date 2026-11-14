import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_helper.dart';
import 'custom_text_field.dart';

/// Field pemilih tanggal seragam berbasis [CustomTextField] dan [showDatePicker].
class DatePickerField extends StatefulWidget {
  final String label;
  final String hint;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool clearable;
  final String? Function(DateTime?)? validator;

  const DatePickerField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.clearable = false,
    this.validator,
  });

  @override
  State<DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.value));
  }

  @override
  void didUpdateWidget(covariant DatePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = _formatValue(widget.value);
    if (_controller.text != newText) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatValue(DateTime? date) {
    if (date == null) return '';
    return DateHelper.formatLong(date);
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final today = DateHelper.dateOnly(now);

    final effectiveFirst = widget.firstDate != null
        ? DateHelper.dateOnly(widget.firstDate!)
        : DateTime(2020);
    final effectiveLast = widget.lastDate != null
        ? DateHelper.dateOnly(widget.lastDate!)
        : DateTime(now.year + 10, 12, 31);

    DateTime initial = widget.value != null
        ? DateHelper.dateOnly(widget.value!)
        : today;
    if (initial.isBefore(effectiveFirst)) {
      initial = effectiveFirst;
    } else if (initial.isAfter(effectiveLast)) {
      initial = effectiveLast;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: effectiveFirst,
      lastDate: effectiveLast,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryGreen,
              onPrimary: Colors.white,
              onSurface: primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      widget.onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showClear = widget.clearable && widget.value != null;

    return CustomTextField(
      label: widget.label,
      hint: widget.hint,
      controller: _controller,
      readOnly: true,
      onTap: _selectDate,
      validator: widget.validator != null
          ? (_) => widget.validator!(widget.value)
          : null,
      suffixIcon: showClear
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Hapus tanggal',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: primaryGreen,
                    size: 20,
                  ),
                  onPressed: () => widget.onChanged(null),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.calendar_today, color: primaryGreen),
                ),
              ],
            )
          : const Icon(Icons.calendar_today, color: primaryGreen),
    );
  }
}
