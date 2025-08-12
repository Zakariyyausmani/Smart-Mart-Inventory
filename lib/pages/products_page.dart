import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../api_config.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({Key? key}) : super(key: key);

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class Product {
  final String id;
  final String name;
  final String image;
  final String barcode;
  final String categoryId;
  final String subcategoryId;
  final String categoryName;
  final String subcategoryName;
  final double price;
  final int quantity;
  final String saleTax;
  final String gst;
  final String withholdingTax;

  Product({
    required this.id,
    required this.name,
    required this.image,
    required this.barcode,
    required this.categoryId,
    required this.subcategoryId,
    required this.categoryName,
    required this.subcategoryName,
    required this.price,
    required this.quantity,
    required this.saleTax,
    required this.gst,
    required this.withholdingTax,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['_id'],
        name: json['name'] ?? '',
        image: json['image'] ?? '',
        barcode: json['barcode'] ?? '',
        categoryId: json['categoryId']?['_id'] ?? '',
        subcategoryId: json['subcategoryId']?['_id'] ?? '',
        categoryName: json['categoryId']?['categoryName'] ?? '',
        subcategoryName: json['subcategoryId']?['subcategoryName'] ?? '',
        price: (json['price'] != null)
            ? (json['price'] is int
                ? (json['price'] as int).toDouble()
                : json['price'])
            : 0.0,
        quantity: json['quantity'] ?? 0,
        saleTax: json['saleTax']?.toString() ?? '',
        gst: json['gst']?.toString() ?? '',
        withholdingTax: json['withholdingTax']?.toString() ?? '',
      );
}

class Category {
  final String id;
  final String name;

  Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['_id'],
        name: json['categoryName'],
      );
}

class Subcategory {
  final String id;
  final String name;

  Subcategory({required this.id, required this.name});

  factory Subcategory.fromJson(Map<String, dynamic> json) => Subcategory(
        id: json['_id'],
        name: json['subcategoryName'],
      );
}

class _ProductsPageState extends State<ProductsPage> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _searchTerm = '';
  bool _loading = false;

  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await fetchCategories();
    await fetchProducts();
  }

  Future<void> fetchProducts() async {
    setState(() => _loading = true);
    try {
      final baseUrl = getBackendBaseUrl();
      final response = await http.get(Uri.parse('$baseUrl/api/products'));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List productsJson = jsonData['products'] ?? [];
        _products =
            productsJson.map<Product>((e) => Product.fromJson(e)).toList();
        _applyFilter();
      } else {
        _showToast('Failed to fetch products: ${response.statusCode}');
      }
    } catch (_) {
      _showToast('Failed to fetch products');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> fetchCategories() async {
    try {
      final baseUrl = getBackendBaseUrl();
      final response = await http.get(Uri.parse('$baseUrl/api/categories'));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List categoriesJson = jsonData['categories'] ?? [];
        _categories =
            categoriesJson.map<Category>((e) => Category.fromJson(e)).toList();
        setState(() {});
      } else {
        _showToast('Failed to fetch categories: ${response.statusCode}');
      }
    } catch (_) {
      _showToast('Failed to fetch categories');
    }
  }

  void _applyFilter() {
    if (_searchTerm.isEmpty) {
      setState(() {
        _filteredProducts = List.from(_products);
      });
    } else {
      setState(() {
        _filteredProducts = _products
            .where((p) =>
                p.name.toLowerCase().contains(_searchTerm.toLowerCase().trim()))
            .toList();
      });
    }
  }

  void _showToast(String msg) =>
      Fluttertoast.showToast(msg: msg, toastLength: Toast.LENGTH_SHORT);

  Future<void> _navigateToEditProduct(Product product) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EditProductPage(product: product, categories: _categories),
      ),
    );
    // Automatically reload and stay on page after edit
    if (result == true) {
      await _loadInitialData();
    }
  }

  void _confirmDeleteProduct(BuildContext context, String productId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteProduct(productId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(String productId) async {
    setState(() => _loading = true);
    try {
      final baseUrl = getBackendBaseUrl();
      final res =
          await http.delete(Uri.parse('$baseUrl/api/products/$productId'));
      if (res.statusCode == 200) {
        _showToast('Product deleted');
        await _loadInitialData();
      } else {
        _showToast('Failed to delete product');
      }
    } catch (_) {
      _showToast('Failed to delete product');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _navigateToAddProduct() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddProductPage(categories: _categories),
      ),
    );
    // Reload list automatically on return from Add page
    if (result == true) {
      await _loadInitialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Refresh button at top, before search
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 900
              ? 4
              : (constraints.maxWidth > 600 ? 3 : 2);
          return Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                   

                  onPressed: _loadInitialData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search products',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    _searchTerm = val;
                    _applyFilter();
                  },
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredProducts.isEmpty
                        ? const Center(child: Text('No products found'))
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.7,
                            ),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (ctx, index) {
                              final p = _filteredProducts[index];
                              return Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(12)),
                                        child: p.image.isNotEmpty
                                            ? Image.network(
                                                p.image,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                  Icons.image,
                                                  size: 40,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Price: Rs ${p.price.toStringAsFixed(2)}',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                          Text(
                                            'Qty: ${p.quantity}',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              IconButton(
                                                tooltip: 'Edit',
                                                icon: const Icon(Icons.edit),
                                                onPressed: () =>
                                                    _navigateToEditProduct(p),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete',
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () =>
                                                    _confirmDeleteProduct(
                                                        context, p.id),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        }),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
        onPressed: _navigateToAddProduct,
      ),
    );
  }
}

class AddProductPage extends StatefulWidget {
  final List<Category> categories;

  const AddProductPage({Key? key, required this.categories}) : super(key: key);

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  String? _categoryId;
  String? _subcategoryId;
  List<Subcategory> _subcategories = [];

  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _saleTaxController = TextEditingController();
  final _gstController = TextEditingController();
  final _withholdingTaxController = TextEditingController();

  File? _imageFile;
  final _picker = ImagePicker();

  bool _loading = false;

  Future<void> _fetchSubcategories(String? categoryId) async {
    if (categoryId == null || categoryId.isEmpty) {
      setState(() {
        _subcategories = [];
        _subcategoryId = null;
      });
      return;
    }
    try {
      final baseUrl = getBackendBaseUrl();
      final response = await http
          .get(Uri.parse('$baseUrl/api/subcategories/category/$categoryId'));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List subcategoriesJson = jsonData['subcategories'] ?? [];
        _subcategories = (subcategoriesJson as List)
            .map((e) => Subcategory.fromJson(e))
            .toList();
        setState(() {
          _subcategoryId = null;
        });
      } else {
        Fluttertoast.showToast(msg: 'Failed to fetch subcategories');
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Failed to fetch subcategories');
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _submitAdd() async {
    if (_categoryId == null) {
      Fluttertoast.showToast(msg: 'Category is required');
      return;
    }
    if (_subcategoryId == null) {
      Fluttertoast.showToast(msg: 'Subcategory is required');
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'Name is required');
      return;
    }
    if (_priceController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'Price is required');
      return;
    }
    if (_quantityController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'Quantity is required');
      return;
    }
    if (_imageFile == null) {
      Fluttertoast.showToast(msg: 'Product image required');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final baseUrl = getBackendBaseUrl();
      var uri = Uri.parse('$baseUrl/api/products');
      var request = http.MultipartRequest('POST', uri);

      request.fields['categoryId'] = _categoryId!;
      request.fields['subcategoryId'] = _subcategoryId!;
      request.fields['name'] = _nameController.text.trim();
      request.fields['barcode'] = _barcodeController.text.trim();
      request.fields['price'] = _priceController.text.trim();
      request.fields['quantity'] = _quantityController.text.trim();
      request.fields['saleTax'] = _saleTaxController.text.trim().isEmpty
          ? '0'
          : _saleTaxController.text.trim();
      request.fields['gst'] =
          _gstController.text.trim().isEmpty ? '0' : _gstController.text.trim();
      request.fields['withholdingTax'] =
          _withholdingTaxController.text.trim().isEmpty
              ? '0'
              : _withholdingTaxController.text.trim();

      request.files
          .add(await http.MultipartFile.fromPath('image', _imageFile!.path));

      var resp = await request.send();
      final respBody = await resp.stream.bytesToString();

      if (resp.statusCode == 200) {
        Fluttertoast.showToast(msg: 'Product added successfully');
        Navigator.of(context).pop(true); // Notify caller to reload
      } else {
        final jsonResp = jsonDecode(respBody);
        Fluttertoast.showToast(
            msg: jsonResp['message'] ?? 'Failed to add product');
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Failed to add product');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _saleTaxController.dispose();
    _gstController.dispose();
    _withholdingTaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text('Add Product'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Category'),
                  value: _categoryId,
                  items: widget.categories
                      .map((cat) => DropdownMenuItem(
                          value: cat.id, child: Text(cat.name)))
                      .toList(),
                  onChanged: (val) async {
                    setState(() {
                      _categoryId = val;
                      _subcategoryId = null;
                      _subcategories = [];
                    });
                    await _fetchSubcategories(val);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Subcategory'),
                  value: _subcategoryId,
                  items: _subcategories
                      .map((sub) => DropdownMenuItem(
                          value: sub.id, child: Text(sub.name)))
                      .toList(),
                  onChanged: (val) => setState(() => _subcategoryId = val),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _barcodeController,
                  decoration: const InputDecoration(labelText: 'Barcode'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _saleTaxController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Sales Tax (%)'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _gstController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'GST (%)'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _withholdingTaxController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Withholding Tax (%)'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Pick Image'),
                    ),
                    const SizedBox(width: 12),
                    if (_imageFile != null)
                      Image.file(_imageFile!,
                          width: 60, height: 60, fit: BoxFit.cover),
                  ],
                ),
                const SizedBox(height: 20),
                _loading
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: const CircularProgressIndicator(),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitAdd,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text('Add Product',
                                style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EditProductPage extends StatefulWidget {
  final Product product;
  final List<Category> categories;

  const EditProductPage(
      {Key? key, required this.product, required this.categories})
      : super(key: key);

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  String? _categoryId;
  String? _subcategoryId;
  List<Subcategory> _subcategories = [];

  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _saleTaxController;
  late TextEditingController _gstController;
  late TextEditingController _withholdingTaxController;

  File? _imageFile;
  String? _imagePreviewUrl;

  final _picker = ImagePicker();
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _categoryId = widget.product.categoryId;
    _subcategoryId = widget.product.subcategoryId;
    _nameController = TextEditingController(text: widget.product.name);
    _barcodeController = TextEditingController(text: widget.product.barcode);
    _priceController =
        TextEditingController(text: widget.product.price.toString());
    _quantityController =
        TextEditingController(text: widget.product.quantity.toString());
    _saleTaxController = TextEditingController(text: widget.product.saleTax);
    _gstController = TextEditingController(text: widget.product.gst);
    _withholdingTaxController =
        TextEditingController(text: widget.product.withholdingTax);
    _imagePreviewUrl = widget.product.image;

    _fetchSubcategories(_categoryId);
  }

  Future<void> _fetchSubcategories(String? categoryId) async {
    if (categoryId == null || categoryId.isEmpty) {
      setState(() {
        _subcategories = [];
        _subcategoryId = null;
      });
      return;
    }
    try {
      final baseUrl = getBackendBaseUrl();
      final response = await http
          .get(Uri.parse('$baseUrl/api/subcategories/category/$categoryId'));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List subcategoriesJson = jsonData['subcategories'] ?? [];
        _subcategories = (subcategoriesJson as List)
            .map((e) => Subcategory.fromJson(e))
            .toList();
        if (!_subcategories.any((sub) => sub.id == _subcategoryId)) {
          _subcategoryId = null;
        }
        setState(() {});
      } else {
        Fluttertoast.showToast(msg: 'Failed to fetch subcategories');
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Failed to fetch subcategories');
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
        _imagePreviewUrl = null;
      });
    }
  }

  Future<void> _submitEdit() async {
    if (_categoryId == null) {
      Fluttertoast.showToast(msg: 'Category is required');
      return;
    }
    if (_subcategoryId == null) {
      Fluttertoast.showToast(msg: 'Subcategory is required');
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'Name is required');
      return;
    }
    if (_priceController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'Price is required');
      return;
    }
    if (_quantityController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'Quantity is required');
      return;
    }

    setState(() => _loading = true);

    try {
      final baseUrl = getBackendBaseUrl();
      var uri = Uri.parse('$baseUrl/api/products/${widget.product.id}');
      var request = http.MultipartRequest('PUT', uri);

      request.fields['categoryId'] = _categoryId!;
      request.fields['subcategoryId'] = _subcategoryId!;
      request.fields['name'] = _nameController.text.trim();
      request.fields['barcode'] = _barcodeController.text.trim();
      request.fields['price'] = _priceController.text.trim();
      request.fields['quantity'] = _quantityController.text.trim();
      request.fields['saleTax'] = _saleTaxController.text.trim().isEmpty
          ? '0'
          : _saleTaxController.text.trim();
      request.fields['gst'] =
          _gstController.text.trim().isEmpty ? '0' : _gstController.text.trim();
      request.fields['withholdingTax'] =
          _withholdingTaxController.text.trim().isEmpty
              ? '0'
              : _withholdingTaxController.text.trim();

      if (_imageFile != null) {
        request.files
            .add(await http.MultipartFile.fromPath('image', _imageFile!.path));
      }

      var resp = await request.send();
      final respBody = await resp.stream.bytesToString();

      if (resp.statusCode == 200) {
        Fluttertoast.showToast(msg: 'Product updated successfully');
        Navigator.of(context).pop(true);
      } else {
        final jsonResp = jsonDecode(respBody);
        Fluttertoast.showToast(
            msg: jsonResp['message'] ?? 'Failed to update product');
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Failed to update product');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _saleTaxController.dispose();
    _gstController.dispose();
    _withholdingTaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Category'),
                  value: _categoryId,
                  items: widget.categories
                      .map((cat) => DropdownMenuItem(
                          value: cat.id, child: Text(cat.name)))
                      .toList(),
                  onChanged: (val) async {
                    setState(() {
                      _categoryId = val;
                      _subcategoryId = null;
                      _subcategories = [];
                    });
                    await _fetchSubcategories(val);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Subcategory'),
                  value: _subcategoryId,
                  items: _subcategories
                      .map((sub) => DropdownMenuItem(
                          value: sub.id, child: Text(sub.name)))
                      .toList(),
                  onChanged: (val) => setState(() => _subcategoryId = val),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _barcodeController,
                  decoration: const InputDecoration(labelText: 'Barcode'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _saleTaxController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Sales Tax (%)'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _gstController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'GST (%)'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _withholdingTaxController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Withholding Tax (%)'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Pick Image'),
                    ),
                    const SizedBox(width: 12),
                    if (_imageFile != null)
                      Image.file(_imageFile!,
                          width: 60, height: 60, fit: BoxFit.cover)
                    else if (_imagePreviewUrl != null &&
                        _imagePreviewUrl!.isNotEmpty)
                      Image.network(_imagePreviewUrl!,
                          width: 60, height: 60, fit: BoxFit.cover),
                  ],
                ),
                const SizedBox(height: 20),
                _loading
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: const CircularProgressIndicator(),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitEdit,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text('Save Changes',
                                style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
