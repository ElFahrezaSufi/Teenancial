import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../data/contact_model.dart';

class ContactSelectionAutocomplete extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final List<ContactModel> contacts;
  final String? Function(String?)? validator;

  const ContactSelectionAutocomplete({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.contacts,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: primaryGreen,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return contacts
                  .map((c) => c.name)
                  .where((name) => name
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase()));
            },
            onSelected: (String selection) {
              controller.text = selection;
            },
            fieldViewBuilder: (context, fieldTextEditingController, fieldFocusNode, onFieldSubmitted) {
              // Ensure the internal controller matches our passed controller
              if (controller.text != fieldTextEditingController.text) {
                fieldTextEditingController.text = controller.text;
              }
              fieldTextEditingController.addListener(() {
                controller.text = fieldTextEditingController.text;
              });

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
                  hintText: hint,
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
                    borderSide: const BorderSide(color: primaryGreen, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryGreen, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryGreen, width: 2),
                  ),
                ),
                validator: validator,
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(12),
                  color: inputBg,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final String option = options.elementAt(index);
                        return InkWell(
                          onTap: () {
                            onSelected(option);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              option,
                              style: const TextStyle(
                                color: primaryGreen,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
