import 'package:flutter/material.dart';

import '../services/inventory_service.dart';
import '../services/user_permissions.dart';

class CategoryManagementScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const CategoryManagementScreen({super.key, required this.user});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final InventoryService _inventory = InventoryService();
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  bool get _isAdministrator =>
      UserPermissions.canManageUsers(widget.user['role']);

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _inventory.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Unable to load categories: $error', isError: true);
    }
  }

  Future<void> _editCategory({Map<String, dynamic>? category}) async {
    if (!_isAdministrator) return;
    final nameController = TextEditingController(
      text: category?['name']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: category?['description']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Add category' : 'Edit category'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Category name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a category name'
                    : null,
              ),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: Text(category == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
    if (shouldSave == true) {
      try {
        await _inventory.saveCategory(
          categoryId: int.tryParse(category?['id']?.toString() ?? ''),
          name: nameController.text,
          description: descriptionController.text,
        );
        await _loadCategories();
        if (mounted) _showMessage('Category saved.');
      } catch (error) {
        _showMessage('Unable to save category: $error', isError: true);
      }
    }
    nameController.dispose();
    descriptionController.dispose();
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    if (!_isAdministrator) return;
    final id = int.tryParse(category['id']?.toString() ?? '');
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Delete "${category['name']}"? Categories assigned to products '
          'cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _inventory.deleteCategory(id);
      await _loadCategories();
      if (mounted) _showMessage('Category deleted.');
    } catch (error) {
      _showMessage('Unable to delete category: $error', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdministrator) {
      return Scaffold(
        appBar: AppBar(title: const Text('Category management')),
        body: const Center(
          child: Text('Only an Administrator can manage categories.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadCategories,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _isAdministrator
          ? FloatingActionButton.extended(
              onPressed: () => _editCategory(),
              icon: const Icon(Icons.add),
              label: const Text('Add category'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
          ? const Center(child: Text('No categories found.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.category_outlined),
                    ),
                    title: Text(category['name']?.toString() ?? ''),
                    subtitle: Text(
                      category['description']?.toString().isNotEmpty == true
                          ? category['description'].toString()
                          : 'No description',
                    ),
                    trailing: _isAdministrator
                        ? PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'edit') {
                                _editCategory(category: category);
                              } else {
                                _deleteCategory(category);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
