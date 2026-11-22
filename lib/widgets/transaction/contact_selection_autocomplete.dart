import 'package:material_ui/material_ui.dart';
import '../../models/contact_model.dart';
import '../../theme/app_colors.dart';

/// Status tampilan opsi "Simpan ke daftar kontak" berdasarkan teks yang diisi.
enum ContactSaveControlState {
  /// Input nama masih kosong -> area aksi bawah disembunyikan.
  hidden,

  /// Input nama cocok (case-insensitive) dengan kontak yang sudah tersimpan ->
  /// tampilkan indikator status non-interaktif agar tidak redundan.
  alreadySaved,

  /// Input nama baru yang belum ada di daftar -> tampilkan checkbox simpan.
  showCheckbox,
}

class ContactSelectionAutocomplete extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final List<ContactModel> contacts;
  final String? Function(String?)? validator;
  final bool showSaveToListOption;
  final bool saveToListValue;
  final ValueChanged<bool>? onSaveToListChanged;
  final VoidCallback? onManageContacts;
  final OptionsViewOpenDirection optionsViewOpenDirection;

  const ContactSelectionAutocomplete({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.contacts,
    this.validator,
    this.showSaveToListOption = false,
    this.saveToListValue = false,
    this.onSaveToListChanged,
    this.onManageContacts,
    this.optionsViewOpenDirection = OptionsViewOpenDirection.down,
  });

  /// Mencari kontak yang namanya cocok persis (trimmed & case-insensitive).
  static ContactModel? findMatchingContact(
    String rawText,
    Iterable<ContactModel> contacts,
  ) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    for (final c in contacts) {
      if (c.name.trim().toLowerCase() == lower) {
        return c;
      }
    }
    return null;
  }

  /// Menentukan state 3-kondisi untuk kontrol simpan kontak.
  static ContactSaveControlState resolveSaveControlState({
    required String rawText,
    required Iterable<ContactModel> contacts,
  }) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      return ContactSaveControlState.hidden;
    }
    if (findMatchingContact(trimmed, contacts) != null) {
      return ContactSaveControlState.alreadySaved;
    }
    return ContactSaveControlState.showCheckbox;
  }

  @override
  State<ContactSelectionAutocomplete> createState() =>
      _ContactSelectionAutocompleteState();
}

class _ContactSelectionAutocompleteState
    extends State<ContactSelectionAutocomplete> {
  TextEditingController? _autocompleteController;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onExternalControllerChanged);
  }

  @override
  void didUpdateWidget(covariant ContactSelectionAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onExternalControllerChanged);
      widget.controller.addListener(_onExternalControllerChanged);
      _onExternalControllerChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalControllerChanged);
    _autocompleteController?.removeListener(_onAutocompleteControllerChanged);
    super.dispose();
  }

  void _onExternalControllerChanged() {
    if (_isSyncing) return;
    final fieldController = _autocompleteController;
    if (fieldController != null &&
        fieldController.text != widget.controller.text) {
      _isSyncing = true;
      fieldController.value = fieldController.value.copyWith(
        text: widget.controller.text,
        selection: TextSelection.collapsed(
          offset: widget.controller.text.length,
        ),
        composing: TextRange.empty,
      );
      _isSyncing = false;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _onAutocompleteControllerChanged() {
    if (_isSyncing) return;
    final fieldController = _autocompleteController;
    if (fieldController == null) return;
    if (widget.controller.text != fieldController.text) {
      _isSyncing = true;
      widget.controller.text = fieldController.text;
      _isSyncing = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _bindFieldController(TextEditingController fieldController) {
    if (identical(_autocompleteController, fieldController)) {
      return;
    }
    _autocompleteController?.removeListener(_onAutocompleteControllerChanged);
    _autocompleteController = fieldController;
    fieldController.addListener(_onAutocompleteControllerChanged);
    if (fieldController.text != widget.controller.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(_autocompleteController, fieldController)) {
          return;
        }
        if (fieldController.text != widget.controller.text) {
          _isSyncing = true;
          fieldController.value = fieldController.value.copyWith(
            text: widget.controller.text,
            selection: TextSelection.collapsed(
              offset: widget.controller.text.length,
            ),
            composing: TextRange.empty,
          );
          _isSyncing = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final saveState = widget.showSaveToListOption
        ? ContactSelectionAutocomplete.resolveSaveControlState(
            rawText: widget.controller.text,
            contacts: widget.contacts,
          )
        : ContactSaveControlState.hidden;

    return Padding(
      padding: EdgeInsets.only(
        bottom: widget.showSaveToListOption ? 20.0 : 16.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.onManageContacts != null)
                GestureDetector(
                  key: const Key('contact_manage_shortcut'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onManageContacts,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.contacts_outlined,
                          size: 14,
                          color: primaryGreen,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Kelola Kontak',
                          style: TextStyle(
                            color: primaryGreen,
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return Autocomplete<ContactModel>(
                initialValue: widget.controller.value,
                optionsViewOpenDirection: widget.optionsViewOpenDirection,
                displayStringForOption: (contact) => contact.name,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final query = textEditingValue.text.trim().toLowerCase();
                  if (widget.contacts.isEmpty || query.isEmpty) {
                    return const Iterable<ContactModel>.empty();
                  }
                  return widget.contacts.where((c) {
                    final matchName = c.name.toLowerCase().contains(query);
                    final matchNote =
                        (c.note ?? '').toLowerCase().contains(query);
                    return matchName || matchNote;
                  });
                },
                onSelected: (ContactModel selection) {
                  widget.controller.text = selection.name;
                  if (mounted) setState(() {});
                },
                fieldViewBuilder: (
                  context,
                  fieldTextEditingController,
                  fieldFocusNode,
                  onFieldSubmitted,
                ) {
                  _bindFieldController(fieldTextEditingController);

                  return TextFormField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 15,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: TextStyle(
                        color: primaryGreen.withValues(alpha: 0.5),
                        fontSize: 15,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: inputBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: primaryGreen, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: primaryGreen, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: primaryGreen, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.redAccent, width: 2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.redAccent, width: 2),
                      ),
                    ),
                    validator: widget.validator,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  final bool isOpenUp = widget.optionsViewOpenDirection ==
                      OptionsViewOpenDirection.up;
                  return Align(
                    alignment:
                        isOpenUp ? Alignment.bottomLeft : Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: isOpenUp ? 0 : 6,
                        bottom: isOpenUp ? 6 : 0,
                      ),
                      child: Material(
                        key: const Key('contact_autocomplete_options'),
                        elevation: 4.0,
                        color: inputBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: primaryGreen.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: 200,
                            maxWidth: constraints.maxWidth,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final contact = options.elementAt(index);
                              final hasNote = contact.note != null &&
                                  contact.note!.trim().isNotEmpty;
                              return InkWell(
                                onTap: () => onSelected(contact),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: const TextStyle(
                                          color: primaryGreen,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      if (hasNote) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          contact.note!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: primaryGreen.withValues(
                                              alpha: 0.68,
                                            ),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 11.5,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (widget.showSaveToListOption)
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              alignment: Alignment.topLeft,
              child: switch (saveState) {
                ContactSaveControlState.hidden => const SizedBox.shrink(),
                ContactSaveControlState.alreadySaved => Padding(
                    key: const Key('contact_already_saved_indicator'),
                    padding: const EdgeInsets.only(top: 10, left: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: primaryGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tersimpan di daftar kontak',
                            style: TextStyle(
                              color: primaryGreen.withValues(alpha: 0.85),
                              fontSize: 12.5,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ContactSaveControlState.showCheckbox => GestureDetector(
                    key: const Key('contact_save_checkbox'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onSaveToListChanged
                        ?.call(!widget.saveToListValue),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Icon(
                            widget.saveToListValue
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: primaryGreen,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Simpan ke daftar kontak',
                            style: TextStyle(
                              color: primaryGreen,
                              fontSize: 13,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              },
            ),
        ],
      ),
    );
  }
}
