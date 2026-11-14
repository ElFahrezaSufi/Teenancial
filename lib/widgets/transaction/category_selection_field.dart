import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/app_routes.dart';
import '../../data/category_catalog.dart';
import '../../models/transaction_model.dart';
import '../../providers/category_provider.dart';
import '../../screens/kategori_screen.dart';
import '../../theme/app_colors.dart';
import '../common/custom_dropdown_field.dart';

/// Field pemilih kategori transaksi yang mendukung kategori bawaan sekaligus
/// kategori kustom, lengkap dengan tombol pintasan "+ Kategori Baru" dan
/// "Kelola" tepat di atas/bawah dropdown.
class CategorySelectionField extends StatelessWidget {
  final TransactionType type;
  final String? selectedCategoryId;
  final ValueChanged<String?> onChanged;
  final String label;
  final String hint;

  const CategorySelectionField({
    super.key,
    required this.type,
    required this.selectedCategoryId,
    required this.onChanged,
    this.label = 'Kategori',
    this.hint = 'Pilih Kategori',
  });

  List<CategoryModel> _resolveCategories(CategoryProvider? provider) {
    final base = provider != null
        ? provider.categoriesFor(type)
        : CategoryCatalog.getByType(type);

    if (selectedCategoryId != null &&
        selectedCategoryId!.isNotEmpty &&
        !base.any((c) => c.id == selectedCategoryId)) {
      final fallback = provider != null
          ? provider.resolve(selectedCategoryId!, fallbackType: type)
          : CategoryCatalog.getById(selectedCategoryId!, fallbackType: type);
      if (!base.any((c) => c.id == fallback.id)) {
        return [...base, fallback];
      }
    }
    return base;
  }

  Future<void> _handleAddNewCategory(BuildContext context) async {
    final created = await KategoriScreen.showCategoryFormSheet(
      context,
      type: type,
    );
    if (created != null) {
      onChanged(created.id);
    }
  }

  Future<void> _handleManageCategories(
    BuildContext context,
    CategoryProvider? provider,
  ) async {
    await context.push(AppRoutes.kategori, extra: type);
    if (selectedCategoryId != null && provider != null) {
      final currentList = provider.categoriesFor(type);
      if (!currentList.any((c) => c.id == selectedCategoryId)) {
        onChanged(CategoryCatalog.defaultCategoryIdForType(type));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider?>(context);
    final categories = _resolveCategories(categoryProvider);
    final dropdownItems = categories.map((c) => c.name).toList();

    String? selectedName;
    if (selectedCategoryId != null && categories.isNotEmpty) {
      final matches = categories.where((c) => c.id == selectedCategoryId);
      if (matches.isNotEmpty) {
        selectedName = matches.first.name;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomDropdownField(
          label: label,
          hint: hint,
          value: selectedName,
          items: dropdownItems,
          onChanged: (value) {
            if (value == null) return;
            final match = categories.where((c) => c.name == value);
            if (match.isNotEmpty) {
              onChanged(match.first.id);
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Kategori tidak boleh kosong';
            }
            return null;
          },
        ),
        if (categoryProvider != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14, left: 2, right: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => _handleAddNewCategory(context),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 15,
                        color: orangeText,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Kategori Baru',
                        style: TextStyle(
                          color: orangeText,
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      _handleManageCategories(context, categoryProvider),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 14,
                        color: primaryGreen,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Kelola Kategori',
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
              ],
            ),
          ),
      ],
    );
  }
}
