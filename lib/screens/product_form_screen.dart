import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/inventory_service.dart';
import 'barcode_scanner_screen.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  bool get isEditing => product != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  static const Color primaryGreen = Color(0xFF379805);
  static const Color backgroundColor = Color(0xFFF5F7FA);

  final _formKey = GlobalKey<FormState>();

  final InventoryService _inventoryService = InventoryService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _minimumStockController = TextEditingController();

  List<Map<String, dynamic>> _categories = [];

  int? _selectedCategoryId;
  String _selectedItemType = 'Raw Material';
  String _selectedUnit = 'Pieces';

  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _itemTypes = ['Raw Material', 'Finished Product'];

  final List<String> _units = [
    'Pieces',
    'Kilograms',
    'Tonnes',
    'Meters',
    'Litres',
    'Boxes',
    'Bundles',
    'Rolls',
    'Units',
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    if (widget.product != null) {
      final product = widget.product!;

      _nameController.text = product.name;
      _barcodeController.text = product.barcode ?? '';
      _descriptionController.text = product.description;
      _quantityController.text = _formatNumber(product.quantity);
      _minimumStockController.text = _formatNumber(product.minimumStock);

      _selectedCategoryId = product.categoryId;

      if (_itemTypes.contains(product.itemType)) {
        _selectedItemType = product.itemType;
      } else {
        final normalized = product.itemType
            .toLowerCase()
            .replaceAll('_', ' ')
            .trim();

        if (normalized == 'finished product') {
          _selectedItemType = 'Finished Product';
        } else {
          _selectedItemType = 'Raw Material';
        }
      }

      if (_units.contains(product.unit)) {
        _selectedUnit = product.unit;
      } else if (product.unit.isNotEmpty) {
        _selectedUnit = product.unit;
      }
    }

    await _loadCategories();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _inventoryService.getCategories();

      if (!mounted) return;

      setState(() {
        _categories = categories;

        // If editing and the saved category no longer exists,
        // clear the selection.
        if (_selectedCategoryId != null &&
            !_categories.any(
              (category) => _categoryId(category) == _selectedCategoryId,
            )) {
          _selectedCategoryId = null;
        }

        // For a new product, automatically select the first category.
        if (widget.product == null &&
            _selectedCategoryId == null &&
            _categories.isNotEmpty) {
          _selectedCategoryId = _categoryId(_categories.first);
        }
      });
    } catch (e) {
      if (!mounted) return;

      _showSnackBar('Unable to load categories.', isError: true);
    }
  }

  int? _categoryId(Map<String, dynamic> category) {
    final value = category['id'];

    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '');
  }

  String _categoryName(Map<String, dynamic> category) {
    return category['name']?.toString() ?? 'Unnamed Category';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _minimumStockController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
      _showSnackBar('Please select a product category.', isError: true);
      return;
    }

    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;

    final minimumStock =
        double.tryParse(_minimumStockController.text.trim()) ?? 0;

    if (quantity < 0) {
      _showSnackBar('Quantity cannot be negative.', isError: true);
      return;
    }

    if (minimumStock < 0) {
      _showSnackBar('Minimum stock cannot be negative.', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final barcode = _barcodeController.text.trim();
      if (barcode.isNotEmpty) {
        final matchingProduct = await _inventoryService.getProductByBarcode(
          barcode,
        );
        if (matchingProduct != null &&
            matchingProduct.id != widget.product?.id) {
          _showSnackBar(
            'This barcode is already assigned to ${matchingProduct.name}.',
            isError: true,
          );
          return;
        }
      }

      final product = Product(
        id: widget.product?.id ?? 0,
        categoryId: _selectedCategoryId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        unit: _selectedUnit,
        quantity: quantity,
        minimumStock: minimumStock,
        itemType: _selectedItemType,
        barcode: barcode.isEmpty ? null : barcode,
        categoryName: _selectedCategoryName(),
        createdAt: widget.product?.createdAt,
        updatedAt: widget.product?.updatedAt,
      );

      bool success;

      if (widget.isEditing) {
        success = await _inventoryService.updateProduct(product);
      } else {
        await _inventoryService.addProduct(product);
        success = true;
      }

      if (!mounted) return;

      if (success) {
        _showSnackBar(
          widget.isEditing
              ? 'Product updated successfully.'
              : 'Product added successfully.',
        );

        Navigator.pop(context, true);
      } else {
        _showSnackBar(
          widget.isEditing
              ? 'Failed to update product.'
              : 'Failed to add product.',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Something went wrong while saving the product.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _selectedCategoryName() {
    if (_selectedCategoryId == null) {
      return null;
    }

    for (final category in _categories) {
      if (_categoryId(category) == _selectedCategoryId) {
        return _categoryName(category);
      }
    }

    return widget.product?.categoryName;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? Colors.red.shade700 : primaryGreen,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          title: Text(
            widget.isEditing ? 'Edit Product' : 'Add Product',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              )
            : SafeArea(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildBasicInformationCard(),
                        const SizedBox(height: 16),
                        _buildStockInformationCard(),
                        const SizedBox(height: 16),
                        _buildDescriptionCard(),
                        const SizedBox(height: 24),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, primaryGreen.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditing ? 'Update Product' : 'Create New Product',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isEditing
                      ? 'Update the product information below.'
                      : 'Enter the details of the inventory item.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInformationCard() {
    return _buildSectionCard(
      title: 'Basic Information',
      icon: Icons.info_outline,
      children: [
        _buildTextField(
          controller: _nameController,
          label: 'Product Name',
          hint: 'e.g. Steel Sheets',
          icon: Icons.inventory_2_outlined,
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Product name is required';
            }

            if (value.trim().length < 2) {
              return 'Enter a valid product name';
            }

            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildBarcodeField(),
        const SizedBox(height: 16),
        _buildCategoryDropdown(),
        const SizedBox(height: 16),
        _buildItemTypeDropdown(),
        const SizedBox(height: 16),
        _buildUnitDropdown(),
      ],
    );
  }

  Widget _buildBarcodeField() {
    final theme = Theme.of(context);
    return TextFormField(
      controller: _barcodeController,
      enabled: !_isSaving,
      keyboardType: TextInputType.text,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: 'Barcode (Optional)',
        hintText: 'Scan or enter a product barcode',
        prefixIcon: const Icon(Icons.qr_code_2, color: primaryGreen),
        suffixIcon: isBarcodeScannerSupported
            ? IconButton(
                tooltip: 'Scan barcode',
                onPressed: _isSaving ? null : _scanBarcode,
                icon: const Icon(Icons.camera_alt_outlined),
              )
            : null,
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || barcode == null) return;

    setState(() {
      _barcodeController.text = barcode;
    });
  }

  Widget _buildStockInformationCard() {
    return _buildSectionCard(
      title: 'Stock Information',
      icon: Icons.bar_chart_rounded,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _quantityController,
                label: 'Initial Quantity',
                hint: '0',
                icon: Icons.numbers,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }

                  final number = double.tryParse(value.trim());

                  if (number == null) {
                    return 'Invalid number';
                  }

                  if (number < 0) {
                    return 'Cannot be negative';
                  }

                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                controller: _minimumStockController,
                label: 'Minimum Stock',
                hint: '0',
                icon: Icons.warning_amber_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }

                  final number = double.tryParse(value.trim());

                  if (number == null) {
                    return 'Invalid number';
                  }

                  if (number < 0) {
                    return 'Cannot be negative';
                  }

                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Minimum stock is the level at which the system '
                  'will identify the product as low stock.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionCard() {
    return _buildSectionCard(
      title: 'Description',
      icon: Icons.notes_outlined,
      children: [
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          minLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Enter additional information about this product...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            filled: true,
            fillColor: backgroundColor,
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, right: 8, top: 12),
              child: Align(
                alignment: Alignment.topCenter,
                widthFactor: 1,
                heightFactor: 1,
                child: Icon(Icons.description_outlined, color: primaryGreen),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: primaryGreen, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedCategoryId,
      isExpanded: true,
      decoration: _dropdownDecoration(
        label: 'Category',
        icon: Icons.category_outlined,
      ),
      items: _categories
          .map((category) {
            final id = _categoryId(category);

            if (id == null) {
              return null;
            }

            return DropdownMenuItem<int>(
              value: id,
              child: Text(
                _categoryName(category),
                overflow: TextOverflow.ellipsis,
              ),
            );
          })
          .whereType<DropdownMenuItem<int>>()
          .toList(),
      onChanged: _categories.isEmpty
          ? null
          : (value) {
              setState(() {
                _selectedCategoryId = value;
              });
            },
      validator: (value) {
        if (value == null) {
          return 'Please select a category';
        }

        return null;
      },
      hint: const Text('Select category'),
    );
  }

  Widget _buildItemTypeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedItemType,
      isExpanded: true,
      decoration: _dropdownDecoration(
        label: 'Item Type',
        icon: Icons.category_outlined,
      ),
      items: _itemTypes.map((type) {
        final bool isRaw = type == 'Raw Material';

        return DropdownMenuItem<String>(
          value: type,
          child: Row(
            children: [
              Icon(
                isRaw ? Icons.factory_outlined : Icons.inventory_2_outlined,
                size: 19,
                color: primaryGreen,
              ),
              const SizedBox(width: 10),
              Text(type),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _selectedItemType = value;
        });
      },
    );
  }

  Widget _buildUnitDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _units.contains(_selectedUnit) ? _selectedUnit : null,
      isExpanded: true,
      decoration: _dropdownDecoration(
        label: 'Unit of Measurement',
        icon: Icons.straighten_outlined,
      ),
      items: _units.map((unit) {
        return DropdownMenuItem<String>(value: unit, child: Text(unit));
      }).toList(),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _selectedUnit = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a unit';
        }

        return null;
      },
    );
  }

  InputDecoration _dropdownDecoration({
    required String label,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return InputDecoration(
      labelText: label,
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
      ),
      prefixIcon: Icon(icon, color: primaryGreen),
      filled: true,
      fillColor: theme.colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryGreen),
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: primaryGreen, size: 21),
              ),
              const SizedBox(width: 11),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProduct,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryGreen.withValues(alpha: 0.55),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isEditing
                        ? Icons.save_outlined
                        : Icons.add_circle_outline,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    widget.isEditing ? 'Update Product' : 'Save Product',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
