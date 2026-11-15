import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/category_catalog.dart';
import '../data/category_icons.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../repositories/category_repository.dart';
import '../theme/app_colors.dart';
import '../utils/error_mapper.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/custom_filter_chip.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/primary_button.dart';

class KategoriScreen extends StatefulWidget {
  final TransactionType initialType;

  const KategoriScreen({
    super.key,
    this.initialType = TransactionType.expense,
  });

  static String typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return 'Pengeluaran';
      case TransactionType.income:
        return 'Pemasukan';
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.debt:
        return 'Hutang';
      case TransactionType.receivable:
        return 'Piutang';
    }
  }

  /// Menampilkan bottom sheet untuk membuat atau mengedit kategori kustom.
  /// Mengembalikan [CategoryModel] yang baru dibuat atau diperbarui, atau `null`
  /// jika dibatalkan.
  static Future<CategoryModel?> showCategoryFormSheet(
    BuildContext context, {
    required TransactionType type,
    CategoryModel? categoryToEdit,
  }) {
    return showModalBottomSheet<CategoryModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CategoryFormSheet(
        type: type,
        categoryToEdit: categoryToEdit,
      ),
    );
  }

  @override
  State<KategoriScreen> createState() => _KategoriScreenState();
}

class _KategoriScreenState extends State<KategoriScreen> {
  late TransactionType _selectedType;

  static const List<TransactionType> _tabOrder = [
    TransactionType.expense,
    TransactionType.income,
    TransactionType.transfer,
    TransactionType.debt,
    TransactionType.receivable,
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<CategoryProvider?>(context, listen: false);
      if (provider != null &&
          provider.customCategories.isEmpty &&
          !provider.isLoading) {
        provider.loadCategories();
      }
    });
  }

  Future<void> _handleAddOrEdit({CategoryModel? categoryToEdit}) async {
    final result = await KategoriScreen.showCategoryFormSheet(
      context,
      type: _selectedType,
      categoryToEdit: categoryToEdit,
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            categoryToEdit != null
                ? 'Kategori "${result.name}" berhasil diperbarui!'
                : 'Kategori "${result.name}" berhasil ditambahkan!',
          ),
          backgroundColor: primaryGreen,
        ),
      );
    }
  }

  Future<void> _handleDelete(CategoryModel category) async {
    final categoryProvider = context.read<CategoryProvider>();
    int usageCount = 0;
    try {
      usageCount = await categoryProvider.countUsages(category.id);
    } catch (_) {
      usageCount = 0;
    }
    if (!mounted) return;

    final fallbackCat = CategoryCatalog.getById(
      CategoryCatalog.defaultCategoryIdForType(category.type),
      fallbackType: category.type,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: primaryGreen, width: 1.5),
        ),
        title: const Text(
          'Hapus Kategori Kustom?',
          style: TextStyle(
            color: primaryGreen,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        content: Text(
          usageCount > 0
              ? 'Kategori "${category.name}" sedang dipakai oleh $usageCount transaksi atau jadwal berulang.\n\nJika dihapus, seluruhnya akan otomatis dipindahkan ke kategori bawaan "${fallbackCat.name}".'
              : 'Apakah kamu yakin ingin menghapus kategori "${category.name}"?',
          style: const TextStyle(
            color: primaryGreen,
            fontFamily: 'Inter',
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: primaryGreen,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: const Text(
              'Hapus',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final reassigned = await categoryProvider.deleteCategory(
        categoryId: category.id,
        type: category.type,
      );
      if (!mounted) return;
      if (reassigned > 0) {
        final txProvider =
            Provider.of<TransactionProvider?>(context, listen: false);
        await txProvider?.loadTransactions(silent: true);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reassigned > 0
                ? 'Kategori "${category.name}" dihapus ($reassigned data dipindahkan ke "${fallbackCat.name}").'
                : 'Kategori "${category.name}" berhasil dihapus.',
          ),
          backgroundColor: primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorMapper.message(e)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider?>(context);
    final customList =
        categoryProvider?.customCategoriesFor(_selectedType) ?? const [];
    final builtInList = CategoryCatalog.getByType(_selectedType);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: const CustomAppBar(title: 'Kelola Kategori'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/images/bg_curve.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                  child: Row(
                    children: _tabOrder.map((type) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CustomFilterChip(
                          label: KategoriScreen.typeLabel(type),
                          selected: _selectedType == type,
                          onTap: () => setState(() => _selectedType = type),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: primaryGreen,
                    backgroundColor: scaffoldBg,
                    onRefresh: () async {
                      await categoryProvider?.loadCategories(silent: true);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Kategori Kustom (${customList.length}/${CategoryRepository.maxCustomPerType})',
                                style: const TextStyle(
                                  color: primaryGreen,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _handleAddOrEdit(),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 16,
                                      color: orangeText,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tambah Kategori',
                                      style: TextStyle(
                                        color: orangeText,
                                        fontSize: 13,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (customList.isEmpty)
                            CustomCard(
                              backgroundColor: cardBg,
                              borderRadius: 16,
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.category_outlined,
                                    size: 36,
                                    color: primaryGreen.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Belum ada kategori kustom untuk ${KategoriScreen.typeLabel(_selectedType)}.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: primaryGreen,
                                      fontSize: 13,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () => _handleAddOrEdit(),
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: primaryGreen,
                                    ),
                                    label: const Text(
                                      'Buat Kategori Baru',
                                      style: TextStyle(
                                        color: primaryGreen,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: primaryGreen,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...customList.map(
                              (cat) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _CategoryTile(
                                  category: cat,
                                  onEdit: () =>
                                      _handleAddOrEdit(categoryToEdit: cat),
                                  onDelete: () => _handleDelete(cat),
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          const Text(
                            'Kategori Bawaan',
                            style: TextStyle(
                              color: primaryGreen,
                              fontSize: 14,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...builtInList.map(
                            (cat) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CategoryTile(category: cat),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CategoryTile({
    required this.category,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = category.color;

    return CustomCard(
      backgroundColor: cardBg,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Icon(category.icon, color: badgeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category.isCustom ? 'Kategori Kustom' : 'Kategori Bawaan',
                  style: TextStyle(
                    color: primaryGreen.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!category.isCustom)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: lightGreen.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: primaryGreen,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Bawaan',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 11,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: primaryGreen, size: 20),
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit?.call();
                } else if (value == 'delete') {
                  onDelete?.call();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, color: primaryGreen),
                      SizedBox(width: 8),
                      Text('Edit', style: TextStyle(color: primaryGreen)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Hapus', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryFormSheet extends StatefulWidget {
  final TransactionType type;
  final CategoryModel? categoryToEdit;

  const _CategoryFormSheet({
    required this.type,
    this.categoryToEdit,
  });

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedIconKey;
  late int _selectedColorValue;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEdit => widget.categoryToEdit != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.categoryToEdit;
    _nameController = TextEditingController(text: editing?.name ?? '');
    _selectedIconKey = editing?.iconKey ?? CategoryIcons.selectableKeys.first;
    _selectedColorValue = editing?.colorValue ?? CategoryIcons.palette.first;
    _nameController.addListener(() {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final categoryProvider = context.read<CategoryProvider>();
      final CategoryModel saved;
      if (_isEdit) {
        saved = await categoryProvider.updateCategory(
          categoryId: widget.categoryToEdit!.id,
          name: _nameController.text,
          type: widget.type,
          iconKey: _selectedIconKey,
          colorValue: _selectedColorValue,
        );
      } else {
        saved = await categoryProvider.addCategory(
          name: _nameController.text,
          type: widget.type,
          iconKey: _selectedIconKey,
          colorValue: _selectedColorValue,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorMapper.message(e);
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final previewColor = Color(_selectedColorValue);
    final previewName = _nameController.text.trim().isEmpty
        ? 'Pratinjau Kategori'
        : _nameController.text.trim();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: primaryGreen.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _isEdit ? 'Edit Kategori Kustom' : 'Tambah Kategori Baru',
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 18,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Jenis Transaksi: ${KategoriScreen.typeLabel(widget.type)}',
                  style: TextStyle(
                    color: primaryGreen.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CustomCard(
                          backgroundColor: cardBg,
                          borderRadius: 16,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: previewColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: previewColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  CategoryIcons.iconForKey(_selectedIconKey),
                                  color: previewColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  previewName,
                                  style: const TextStyle(
                                    color: primaryGreen,
                                    fontSize: 15,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'Nama Kategori',
                          hint: 'Contoh: Kopi & Camilan',
                          controller: _nameController,
                          validator: (val) {
                            final trimmed = (val ?? '').trim();
                            if (trimmed.isEmpty) {
                              return 'Nama kategori tidak boleh kosong';
                            }
                            if (trimmed.length >
                                CategoryRepository.maxNameLength) {
                              return 'Maksimal ${CategoryRepository.maxNameLength} karakter';
                            }
                            return null;
                          },
                        ),
                        if (_errorMessage != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
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
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Text(
                          'Pilih Warna',
                          style: TextStyle(
                            color: primaryGreen,
                            fontSize: 13,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: CategoryIcons.palette.map((colorVal) {
                            final selected = _selectedColorValue == colorVal;
                            return GestureDetector(
                              onTap: () => setState(
                                () => _selectedColorValue = colorVal,
                              ),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Color(colorVal),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected
                                        ? darkGreen
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Pilih Ikon',
                          style: TextStyle(
                            color: primaryGreen,
                            fontSize: 13,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: CategoryIcons.selectableKeys.map((key) {
                            final selected = _selectedIconKey == key;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedIconKey = key),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? previewColor.withValues(alpha: 0.2)
                                      : cardBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected
                                        ? previewColor
                                        : primaryGreen.withValues(alpha: 0.35),
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Icon(
                                  CategoryIcons.iconForKey(key),
                                  color: selected ? previewColor : primaryGreen,
                                  size: 20,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                PrimaryButton(
                  label: _isSaving ? 'Menyimpan...' : 'Simpan Kategori',
                  onPressed: _isSaving ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
