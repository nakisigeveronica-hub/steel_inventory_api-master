import 'package:flutter/material.dart';

import '../models/supplier.dart';
import '../services/inventory_service.dart';

class SupplierFormScreen extends StatefulWidget {
  final Supplier? supplier;

  const SupplierFormScreen({super.key, this.supplier});

  bool get isEditing => supplier != null;

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  static const Color primaryGreen = Color(0xFF379805);

  static const Color backgroundColor = Color(0xFFF5F7FA);

  final InventoryService inventoryService = InventoryService();

  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();

  final contactPersonController = TextEditingController();

  final phoneController = TextEditingController();

  final emailController = TextEditingController();

  final addressController = TextEditingController();

  bool saving = false;

  @override
  void initState() {
    super.initState();

    if (widget.supplier != null) {
      nameController.text = widget.supplier!.name;

      contactPersonController.text = widget.supplier!.contactPerson;

      phoneController.text = widget.supplier!.phone;

      emailController.text = widget.supplier!.email;

      addressController.text = widget.supplier!.address;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    contactPersonController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();

    super.dispose();
  }

  // ============================================================
  // SHOW MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : null,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // SAVE SUPPLIER
  // ============================================================

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      saving = true;
    });

    try {
      final supplier = Supplier(
        id: widget.supplier?.id ?? 0,
        name: nameController.text.trim(),
        contactPerson: contactPersonController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim(),
        address: addressController.text.trim(),
        createdAt: widget.supplier?.createdAt,
        updatedAt: widget.supplier?.updatedAt,
      );

      bool success;

      if (widget.isEditing) {
        success = await inventoryService.updateSupplier(supplier);
      } else {
        success = await inventoryService.addSupplier(supplier);
      }

      if (!mounted) return;

      if (success) {
        _showMessage(
          widget.isEditing
              ? 'Supplier updated successfully.'
              : 'Supplier added successfully.',
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        Navigator.pop(context, true);
      } else {
        setState(() {
          saving = false;
        });

        _showMessage(
          widget.isEditing
              ? 'Unable to update supplier.'
              : 'Unable to add supplier.',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      _showMessage(
        'An error occurred while saving the supplier.',
        isError: true,
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final editing = widget.isEditing;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,

        title: Text(
          editing ? 'Edit Supplier' : 'Add Supplier',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        actions: [
          if (saving)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryGreen,
                  ),
                ),
              ),
            ),
        ],
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
            children: [
              // ==================================================
              // HEADER
              // ==================================================

              _buildHeader(editing),

              const SizedBox(height: 24),

              // ==================================================
              // BASIC INFORMATION
              // ==================================================
              _sectionTitle('Supplier Information'),

              const SizedBox(height: 10),

              _buildFormCard(
                children: [
                  _buildTextField(
                    controller: nameController,
                    label: 'Supplier Name',
                    hint: 'Enter supplier company name',
                    icon: Icons.business_rounded,
                    requiredField: true,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Supplier name is required';
                      }

                      if (value.trim().length < 2) {
                        return 'Enter a valid supplier name';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: contactPersonController,
                    label: 'Contact Person',
                    hint: 'Enter contact person name',
                    icon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ==================================================
              // CONTACT DETAILS
              // ==================================================
              _sectionTitle('Contact Details'),

              const SizedBox(height: 10),

              _buildFormCard(
                children: [
                  _buildTextField(
                    controller: phoneController,
                    label: 'Phone Number',
                    hint: '+256 700 000 000',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Phone number is required';
                      }

                      final phone = value.trim();

                      if (phone.length < 7) {
                        return 'Enter a valid phone number';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: emailController,
                    label: 'Email Address',
                    hint: 'supplier@example.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final email = value?.trim() ?? '';

                      if (email.isEmpty) {
                        return null;
                      }

                      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                      if (!emailRegex.hasMatch(email)) {
                        return 'Enter a valid email address';
                      }

                      return null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ==================================================
              // ADDRESS
              // ==================================================
              _sectionTitle('Location'),

              const SizedBox(height: 10),

              _buildFormCard(
                children: [
                  _buildTextField(
                    controller: addressController,
                    label: 'Supplier Address',
                    hint: 'Enter supplier physical address',
                    icon: Icons.location_on_outlined,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ==================================================
              // SAVE BUTTON
              // ==================================================
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: saving ? null : _saveSupplier,
                  icon: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          editing
                              ? Icons.save_rounded
                              : Icons.add_business_rounded,
                        ),
                  label: Text(
                    saving
                        ? 'Saving...'
                        : editing
                        ? 'Update Supplier'
                        : 'Add Supplier',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primaryGreen.withValues(
                      alpha: 0.55,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // CANCEL
              // ==================================================
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // INFORMATION
              // ==================================================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primaryGreen.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: primaryGreen,
                      size: 20,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'Supplier information is stored '
                        'locally on this device and can '
                        'be used for stock receiving and '
                        'supplier communication.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(bool editing) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, primaryGreen.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              editing ? Icons.edit_note_rounded : Icons.local_shipping_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editing ? 'Update Supplier' : 'New Supplier',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  editing
                      ? 'Update supplier contact information'
                      : 'Add a supplier to your inventory',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
    final theme = Theme.of(context);

    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  // ============================================================
  // FORM CARD
  // ============================================================

  Widget _buildFormCard({required List<Widget> children}) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    bool requiredField = false,
  }) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4, right: 4),
          child: Icon(icon, color: primaryGreen),
        ),
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
}
