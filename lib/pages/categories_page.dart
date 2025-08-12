import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, File, SocketException;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../api_config.dart'; // Import your backend API base URL function here

extension StringCasingExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({Key? key}) : super(key: key);

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  // Data
  List<Map<String, dynamic>> categories = [];
  Map<String, int> subcategoryCounts = {};
  Map<String, int> productCounts = {};
  List<Map<String, dynamic>> subcategories = [];
  List<Map<String, dynamic>> products = [];

  // Loading flags
  bool loadingCategories = false;
  bool loadingSubcategories = false;
  bool loadingProducts = false;

  // Navigation selection
  Map<String, dynamic>? selectedCategory;
  Map<String, dynamic>? selectedSubcategory;

  // Search term
  String searchTerm = '';

  // Form controllers and state
  final TextEditingController _entityNameController = TextEditingController();
  XFile? entityImageFile;
  bool entityEditMode = false;
  String entityType = "category";
  String? entityId;

  // Delete confirmation
  Map<String, dynamic>? itemToDelete;
  String deleteItemType = "";

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  @override
  void dispose() {
    _entityNameController.dispose();
    super.dispose();
  }

  void showSnackBar(String message, [bool isError = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> loadCategories() async {
    setState(() => loadingCategories = true);
    try {
      final res =
          await http.get(Uri.parse('${getBackendBaseUrl()}/api/categories'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final cats = (data['categories'] as List).cast<Map<String, dynamic>>();
        setState(() {
          categories = cats;
        });
        await loadSubcategoryCounts(cats);
      } else {
        showSnackBar('Error loading categories', true);
      }
    } catch (e) {
      showSnackBar('Error loading categories', true);
    }
    setState(() => loadingCategories = false);
  }

  Future<void> loadSubcategoryCounts(List<Map<String, dynamic>> cats) async {
    final counts = <String, int>{};
    await Future.wait(cats.map((cat) async {
      try {
        final res = await http.get(Uri.parse(
            '${getBackendBaseUrl()}/api/subcategories/category/${cat['_id']}'));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          counts[cat['_id']] = (data['subcategories'] as List).length;
        } else {
          counts[cat['_id']] = 0;
        }
      } catch (_) {
        counts[cat['_id']] = 0;
      }
    }));
    setState(() => subcategoryCounts = counts);
  }

  Future<void> loadSubcategories(Map<String, dynamic> cat) async {
    setState(() {
      selectedCategory = cat;
      selectedSubcategory = null;
      loadingSubcategories = true;
      subcategories = [];
      products = [];
    });

    try {
      final res = await http.get(Uri.parse(
          '${getBackendBaseUrl()}/api/subcategories/category/${cat['_id']}'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final subs =
            (data['subcategories'] as List).cast<Map<String, dynamic>>();
        setState(() => subcategories = subs);
        await loadProductCounts(subs);
      } else {
        showSnackBar('Failed to load subcategories', true);
      }
    } catch (_) {
      showSnackBar('Failed to load subcategories', true);
    }
    setState(() => loadingSubcategories = false);
  }

  Future<void> loadProductCounts(List<Map<String, dynamic>> subs) async {
    final counts = <String, int>{};
    await Future.wait(subs.map((sub) async {
      try {
        final res = await http.get(Uri.parse(
            '${getBackendBaseUrl()}/api/products/subcategory/${sub['_id']}'));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          counts[sub['_id']] = (data['products'] as List).length;
        } else {
          counts[sub['_id']] = 0;
        }
      } catch (_) {
        counts[sub['_id']] = 0;
      }
    }));
    setState(() => productCounts = counts);
  }

  Future<void> loadProducts(Map<String, dynamic> subcat) async {
    setState(() {
      selectedSubcategory = subcat;
      loadingProducts = true;
      products = [];
    });

    try {
      final res = await http.get(Uri.parse(
          '${getBackendBaseUrl()}/api/products/subcategory/${subcat['_id']}'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() =>
            products = (data['products'] as List).cast<Map<String, dynamic>>());
      } else {
        showSnackBar('Failed to load products', true);
      }
    } catch (_) {
      showSnackBar('Failed to load products', true);
    }
    setState(() => loadingProducts = false);
  }

  // Modal for add/edit
  void openEntityModal(String type, [Map<String, dynamic>? entity]) {
    setState(() {
      entityType = type;
      entityEditMode = entity != null;
      entityId = entity?['_id'];
      if (type == "category") {
        _entityNameController.text = entity?['categoryName'] ?? '';
      } else {
        _entityNameController.text = entity?['subcategoryName'] ?? '';
      }
      entityImageFile = null;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => entityFormDialog(),
    ).then((_) {
      _entityNameController.clear();
      entityImageFile = null;
    });
  }

  Future<void> handleEntitySubmit() async {
    final trimmedName = _entityNameController.text.trim();
    if (trimmedName.isEmpty) {
      showSnackBar('${entityType.capitalize()} name is required', true);
      return;
    }

    final uri = entityEditMode
        ? Uri.parse(
            '${getBackendBaseUrl()}/api/${entityType == "category" ? "category" : "subcategory"}/$entityId')
        : Uri.parse(entityType == "category"
            ? '${getBackendBaseUrl()}/api/category'
            : '${getBackendBaseUrl()}/api/category/${selectedCategory?['_id'] ?? ""}/subcategories');

    final request = entityEditMode
        ? http.MultipartRequest('PUT', uri)
        : http.MultipartRequest('POST', uri);

    if (entityType == "category") {
      request.fields['categoryName'] = trimmedName;
    } else {
      request.fields['name'] = trimmedName;
    }

    if (entityImageFile != null) {
      request.files.add(
          await http.MultipartFile.fromPath('image', entityImageFile!.path));
    }

    try {
      final streamedResponse = await request.send();
      final res = await http.Response.fromStream(streamedResponse);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        showSnackBar(
            '${entityType.capitalize()} ${entityEditMode ? "updated" : "added"} successfully!');
        Navigator.of(context).maybePop();

        if (entityType == "category") {
          await loadCategories();
        } else if (entityType == "subcategory" && selectedCategory != null) {
          await loadSubcategories(selectedCategory!);
        }
      } else {
        showSnackBar('Failed to save $entityType', true);
      }
    } catch (e) {
      showSnackBar('Failed to save $entityType', true);
    }
  }

  void openDeleteConfirm(Map<String, dynamic> item, String type) {
    setState(() {
      itemToDelete = item;
      deleteItemType = type;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => deleteConfirmDialog(),
    ).then((_) {
      itemToDelete = null;
      deleteItemType = "";
    });
  }

  Future<void> handleDelete() async {
    if (itemToDelete == null) return;

    try {
      if (deleteItemType == "category") {
        if ((subcategoryCounts[itemToDelete!['_id']] ?? 0) > 0) {
          showSnackBar(
              "Cannot delete category with existing subcategories", true);
          Navigator.of(context).maybePop();
          return;
        }

        final res = await http.delete(
          Uri.parse(
              '${getBackendBaseUrl()}/api/category/${itemToDelete!['_id']}'),
        );

        if (res.statusCode == 200) {
          showSnackBar("Category deleted");
          selectedCategory = null;
          selectedSubcategory = null;
          subcategories = [];
          products = [];
          await loadCategories();
        } else {
          showSnackBar("Delete failed", true);
        }
      } else if (deleteItemType == "subcategory") {
        final resProd = await http.get(
          Uri.parse(
              '${getBackendBaseUrl()}/api/products/subcategory/${itemToDelete!['_id']}'),
        );

        if (resProd.statusCode == 200) {
          final data = json.decode(resProd.body);
          if ((data['products'] ?? []).isNotEmpty) {
            showSnackBar(
                "Cannot delete subcategory with existing products", true);
            Navigator.of(context).maybePop();
            return;
          }
        } else {
          showSnackBar("Delete failed", true);
          Navigator.of(context).maybePop();
          return;
        }

        final delRes = await http.delete(
          Uri.parse(
              '${getBackendBaseUrl()}/api/subcategory/${itemToDelete!['_id']}'),
        );

        if (delRes.statusCode == 200) {
          showSnackBar("Subcategory deleted");
          if (selectedCategory != null)
            await loadSubcategories(selectedCategory!);
          selectedSubcategory = null;
          products = [];
        } else {
          showSnackBar("Delete failed", true);
        }
      }
    } catch (_) {
      showSnackBar("Delete failed", true);
    }
    Navigator.of(context).maybePop();
  }

  Widget entityFormDialog() {
    return AlertDialog(
      title:
          Text('${entityEditMode ? "Edit" : "Add"} ${entityType.capitalize()}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                  labelText: entityType == "category"
                      ? "Category Name"
                      : "Subcategory Name"),
              controller: _entityNameController,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                entityImageFile != null
                    ? Image.file(File(entityImageFile!.path),
                        width: 80, height: 80, fit: BoxFit.cover)
                    : const Icon(Icons.image_not_supported,
                        size: 80, color: Colors.grey),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: pickImage,
                  child: const Text("Select Image"),
                ),
              ],
            )
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: handleEntitySubmit,
          child: const Text("Save"),
        ),
      ],
    );
  }

  Widget deleteConfirmDialog() {
    final itemName =
        itemToDelete?['categoryName'] ?? itemToDelete?['subcategoryName'] ?? "";
    return AlertDialog(
      title: Text("Delete ${deleteItemType.capitalize()}"),
      content: Text("Are you sure you want to delete \"$itemName\"?"),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          child: const Text("Cancel"),
        ),
        ElevatedButton(onPressed: handleDelete, child: const Text("Delete")),
      ],
    );
  }

  Future<void> pickImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          entityImageFile = image;
        });
      }
    } catch (e) {
      showSnackBar("Failed to pick image", true);
    }
  }

  void backToCategories() {
    setState(() {
      selectedCategory = null;
      selectedSubcategory = null;
      subcategories = [];
      products = [];
      searchTerm = '';
    });
  }

  void backToSubcategories() {
    setState(() {
      selectedSubcategory = null;
      products = [];
      searchTerm = '';
    });
  }

  List<Map<String, dynamic>> get filteredCategories {
    return categories
        .where((cat) {
          final name = (cat['categoryName'] ?? '').toLowerCase();
          return name.contains(searchTerm.toLowerCase());
        })
        .cast<Map<String, dynamic>>()
        .toList();
  }

  List<Map<String, dynamic>> get filteredSubcategories {
    return subcategories
        .where((sub) {
          final name = (sub['subcategoryName'] ?? '').toLowerCase();
          return name.contains(searchTerm.toLowerCase());
        })
        .cast<Map<String, dynamic>>()
        .toList();
  }

  List<Map<String, dynamic>> get filteredProducts {
    return products
        .where((prod) {
          final name = (prod['name'] ?? '').toLowerCase();
          return name.contains(searchTerm.toLowerCase());
        })
        .cast<Map<String, dynamic>>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedCategory == null && selectedSubcategory == null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchAddRow(
                        searchPlaceholder: "Search categories...",
                        onAddPressed: () => openEntityModal("category")),
                    const SizedBox(height: 8),
                    Expanded(
                      child: loadingCategories
                          ? const Center(child: CircularProgressIndicator())
                          : _buildEntityList(
                              items: filteredCategories,
                              titleKey: "categoryName",
                              badgeText: (item) =>
                                  "${subcategoryCounts[item['_id']] ?? 0} subcategories",
                              onTap: loadSubcategories,
                              onEdit: (item) =>
                                  openEntityModal("category", item),
                              onDelete: (item) =>
                                  openDeleteConfirm(item, "category"),
                              disableDelete: (item) =>
                                  (subcategoryCounts[item['_id']] ?? 0) > 0,
                            ),
                    ),
                  ],
                ),
              )
            else if (selectedCategory != null && selectedSubcategory == null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBackTitleAdd(
                      backText: "Back to Categories",
                      title:
                          "${selectedCategory!['categoryName']} Subcategories",
                      onBack: backToCategories,
                      onAdd: () => openEntityModal("subcategory"),
                    ),
                    const SizedBox(height: 8),
                    _buildSearchBar(
                        searchPlaceholder: "Search subcategories..."),
                    const SizedBox(height: 8),
                    Expanded(
                      child: loadingSubcategories
                          ? const Center(child: CircularProgressIndicator())
                          : _buildEntityList(
                              items: filteredSubcategories,
                              titleKey: "subcategoryName",
                              onTap: loadProducts,
                              onEdit: (item) =>
                                  openEntityModal("subcategory", item),
                              onDelete: (item) =>
                                  openDeleteConfirm(item, "subcategory"),
                              disableDelete: (item) =>
                                  (productCounts[item['_id']] ?? 0) > 0,
                            ),
                    ),
                  ],
                ),
              )
            else if (selectedSubcategory != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBackTitle(
                      backText: "Back to Subcategories",
                      title: selectedSubcategory!['subcategoryName'],
                      onBack: backToSubcategories,
                    ),
                    const SizedBox(height: 8),
                    _buildSearchBar(searchPlaceholder: "Search products..."),
                    const SizedBox(height: 8),
                    Expanded(
                      child: loadingProducts
                          ? const Center(child: CircularProgressIndicator())
                          : _buildProductsGrid(filteredProducts),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAddRow(
          {required String searchPlaceholder,
          required VoidCallback onAddPressed}) =>
      Row(
        children: [
          Expanded(
              child: _buildSearchBar(searchPlaceholder: searchPlaceholder)),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text("Add"),
            onPressed: onAddPressed,
          ),
        ],
      );

  Widget _buildSearchBar({required String searchPlaceholder}) => TextField(
        decoration: InputDecoration(
          labelText: searchPlaceholder,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onChanged: (val) => setState(() => searchTerm = val),
      );

  Widget _buildBackTitleAdd({
    required String backText,
    required String title,
    VoidCallback? onBack,
    VoidCallback? onAdd,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          label: Text(backText),
        ),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 130),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text("Add Subcategory"),
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              textStyle: const TextStyle(fontSize: 14),
              minimumSize: const Size(130, 36),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackTitle({
    required String backText,
    required String title,
    VoidCallback? onBack,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          label: Text(backText),
        ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 112),
      ],
    );
  }

  Widget _buildEntityList({
    required List<Map<String, dynamic>> items,
    required String titleKey,
    String Function(Map<String, dynamic>)? badgeText,
    required void Function(Map<String, dynamic>) onTap,
    required void Function(Map<String, dynamic>) onEdit,
    required void Function(Map<String, dynamic>) onDelete,
    bool Function(Map<String, dynamic>)? disableDelete,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No ${entityType == "category" ? "categories" : "subcategories"} found.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final title = item[titleKey] ?? "";
        final badge = badgeText?.call(item);
        final disableDel = disableDelete?.call(item) ?? false;

        return ListTile(
          title: Text(title, overflow: TextOverflow.ellipsis),
          subtitle: badge != null ? Text(badge) : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => onEdit(item),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: Icon(
                  Icons.delete,
                  color: disableDel ? Colors.grey : Colors.red,
                ),
                onPressed: disableDel ? null : () => onDelete(item),
                tooltip: disableDel ? 'Cannot delete (in use)' : 'Delete',
              ),
            ],
          ),
          onTap: () => onTap(item),
        );
      },
    );
  }

  Widget _buildProductsGrid(List<Map<String, dynamic>> prods) {
    if (prods.isEmpty) {
      return Center(
          child: Text('No products found.',
              style: TextStyle(color: Colors.grey[600])));
    }
    return GridView.builder(
      itemCount: prods.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width < 600 ? 1 : 4,
        childAspectRatio: 3 / 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final prod = prods[index];

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if ((prod['image'] ?? '').isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      prod['image'],
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 100,
                    color: Colors.grey[300],
                    child:
                        const Icon(Icons.image, size: 48, color: Colors.grey),
                  ),
                const SizedBox(height: 8),
                Text(
                  prod['name'] ?? 'Unnamed Product',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Price: Rs. ${prod['price'] ?? '-'}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                Text(
                  'Quantity: ${prod['quantity'] ?? '-'}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
