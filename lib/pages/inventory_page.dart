import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart'; // Import backend base URL

class InventoryPage extends StatefulWidget {
  const InventoryPage({Key? key}) : super(key: key);

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> subcategories = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filteredProducts = [];

  bool loading = false;
  String? error;

  String selectedCategoryId = "";
  String selectedSubcategoryId = "";
  String searchTerm = "";

  Map<String, dynamic>? selectedProduct;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() {
      loading = true;
      error = null;
    });
    await _fetchCategories();
    await _fetchProducts();
    setState(() {
      loading = false;
    });
  }

  // Fetch categories
  Future<void> _fetchCategories() async {
    try {
      final res = await http.get(Uri.parse('${getBackendBaseUrl()}/api/categories'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final cats = (data['categories'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        setState(() {
          categories = cats;
        });
      } else {
        setState(() {
          error = 'Failed to load categories.';
          categories = [];
        });
      }
    } catch (_) {
      setState(() {
        error = 'Failed to load categories.';
        categories = [];
      });
    }
  }

  // Fetch subcategories on category selection
  Future<void> _fetchSubcategories(String categoryId) async {
    try {
      final res =
          await http.get(Uri.parse('${getBackendBaseUrl()}/api/subcategories/category/$categoryId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final subs = (data['subcategories'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        setState(() {
          subcategories = subs;
        });
      } else {
        setState(() {
          error = 'Failed to load subcategories.';
          subcategories = [];
        });
      }
    } catch (_) {
      setState(() {
        error = 'Failed to load subcategories.';
        subcategories = [];
      });
    }
  }

  // Fetch all products initially
  Future<void> _fetchProducts() async {
    try {
      final res = await http.get(Uri.parse('${getBackendBaseUrl()}/api/products'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prods = (data['products'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        setState(() {
          products = prods;
        });
        _filterProducts(prods, selectedCategoryId, selectedSubcategoryId, searchTerm);
      } else {
        setState(() {
          error = 'Failed to load inventory. Please try again later.';
          products = [];
          filteredProducts = [];
        });
      }
    } catch (_) {
      setState(() {
        error = 'Failed to load inventory. Please try again later.';
        products = [];
        filteredProducts = [];
      });
    }
  }

  // Filter products based on selected filters and search term
  void _filterProducts(List<Map<String, dynamic>> prods, String categoryId,
      String subcategoryId, String search) {
    final filtered = prods.where((product) {
      final quantity = product['quantity'];
      if (quantity == null || !(quantity is int) || quantity <= 0) return false;

      if (categoryId.isNotEmpty &&
          (product['categoryId']?['_id'] ?? '') != categoryId) return false;
      if (subcategoryId.isNotEmpty &&
          (product['subcategoryId']?['_id'] ?? '') != subcategoryId) return false;

      if (search.trim().isNotEmpty) {
        final name = (product['name'] ?? '').toString().toLowerCase();
        if (!name.contains(search.toLowerCase())) return false;
      }
      return true;
    }).toList();

    setState(() {
      filteredProducts = filtered;
    });
  }

  // Category change handler
  void _onCategoryChanged(String? value) {
    if (value == null) return;
    setState(() {
      selectedCategoryId = value;
      selectedSubcategoryId = "";
      subcategories = [];
      error = null;
    });
    if (value.isNotEmpty) {
      _fetchSubcategories(value);
    }
    _filterProducts(products, value, "", searchTerm);
  }

  // Subcategory change handler
  void _onSubcategoryChanged(String? value) {
    if (value == null) return;
    setState(() {
      selectedSubcategoryId = value;
      error = null;
    });
    _filterProducts(products, selectedCategoryId, value, searchTerm);
  }

  // Search term change handler
  void _onSearchTermChanged(String value) {
    setState(() {
      searchTerm = value;
    });
    _filterProducts(products, selectedCategoryId, selectedSubcategoryId, value);
  }

  // Build UI for product detail modal
  Widget _buildProductDetailModal(
      BuildContext context, Map<String, dynamic> product) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => selectedProduct = null),
          child: Container(
            color: Colors.black54,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxWidth: 400,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => setState(() => selectedProduct = null),
                      icon: const Icon(Icons.close, size: 32, color: Colors.grey),
                      tooltip: "Close",
                    ),
                  ),
                  Text(
                    product['name'] ?? "Unnamed Product",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (product['image'] != null && product['image'].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        product['image'],
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                    )
                  else
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey,
                        size: 80,
                      ),
                    ),
                  const SizedBox(height: 20),
                  _buildDetailRow("Category", product['categoryId']?['categoryName'] ?? "N/A"),
                  _buildDetailRow("Subcategory", product['subcategoryId']?['subcategoryName'] ?? "N/A"),
                  _buildDetailRow("Price", "Rs. ${product['price'] ?? "N/A"}"),
                  _buildDetailRow("Quantity", "${product['quantity'] ?? "N/A"}"),
                  if (product['description'] != null && product['description'].toString().trim().isNotEmpty)
                    _buildDetailRow("Description", product['description']),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => setState(() => selectedProduct = null),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      "Close",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildDetailRow(String label, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RichText(
        text: TextSpan(
          text: "$label: ",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
          children: [
            TextSpan(
              text: content,
              style: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar with title and refresh button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // const Text(
                  //   'Inventory',
                  //   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
                  // ),
                  ElevatedButton.icon(
                    onPressed: loading ? null : _refreshAll,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search input above filters
              TextField(
                decoration: InputDecoration(
                  labelText: "Search products...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: _onSearchTermChanged,
                enabled: !loading,
              ),
              const SizedBox(height: 12),

              // Filters - Category and Subcategory dropdowns
              LayoutBuilder(builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                return Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: isMobile ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: isMobile ? double.infinity : 250,
                      child: DropdownButtonFormField<String>(
                        value: selectedCategoryId.isEmpty ? null : selectedCategoryId,
                        decoration: InputDecoration(
                          labelText: "Category",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: "",
                            child: Text("All Categories"),
                          ),
                          ...categories.map<DropdownMenuItem<String>>((cat) {
                            final text = cat['categoryName'] ?? 'Unnamed';
                            final id = cat['_id'] ?? '';
                            return DropdownMenuItem<String>(value: id, child: Text(text));
                          }).toList(),
                        ],
                        onChanged: loading ? null : _onCategoryChanged,
                      ),
                    ),
                    if (isMobile)
                      const SizedBox(height: 12)
                    else
                      const SizedBox(width: 12),
                    SizedBox(
                      width: isMobile ? double.infinity : 250,
                      child: DropdownButtonFormField<String>(
                        value: selectedSubcategoryId.isEmpty ? null : selectedSubcategoryId,
                        decoration: InputDecoration(
                          labelText: "Subcategory",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: "",
                            child: Text("All Subcategories"),
                          ),
                          ...subcategories.map<DropdownMenuItem<String>>((sub) {
                            final text = sub['subcategoryName'] ?? 'Unnamed';
                            final id = sub['_id'] ?? '';
                            return DropdownMenuItem<String>(value: id, child: Text(text));
                          }).toList(),
                        ],
                        onChanged: (selectedCategoryId.isEmpty || loading)
                            ? null
                            : _onSubcategoryChanged,
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 16),

              // Main content - product grid or loading/error states
              Expanded(
                child: () {
                  if (loading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (error != null) {
                    return Center(
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    );
                  } else if (filteredProducts.isEmpty) {
                    return Center(
                      child: Text(
                        "No products found for the selected filters.",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    );
                  } 

                  return GridView.builder(
                    padding: const EdgeInsets.all(4),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width < 600
                          ? 2
                          : MediaQuery.of(context).size.width < 900
                              ? 3
                              : 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 3 / 4,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      final imageUrl = product['image'] as String?;
                      final name = product['name'] ?? 'Unnamed product';
                      final quantity =
                          (product['quantity'] is int) ? product['quantity'] : 0;
                      final price = product['price']?.toString() ?? 'N/A';
                      final categoryName =
                          product['categoryId']?['categoryName'] ?? 'Uncategorized';
                      final subcategoryName =
                          product['subcategoryId']?['subcategoryName'] ?? 'N/A';

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: (imageUrl != null && imageUrl.isNotEmpty)
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(imageUrl, fit: BoxFit.contain),
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.image_not_supported_outlined,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Quantity: $quantity",
                                style: TextStyle(
                                  color: quantity < 10 ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Price: Rs. $price",
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Category: $categoryName",
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "Subcategory: $subcategoryName",
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              // const SizedBox(height: 8),
                              // ElevatedButton(
                              //   onPressed: () => setState(() => selectedProduct = product),
                              //   style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
                              //   child: const Text(
                              //     "View Details",
                              //     style: TextStyle(fontWeight: FontWeight.bold),
                              //   ),
                              // ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }(),
              ),

              // Product Detail Modal
              if (selectedProduct != null)
                _buildProductDetailModal(context, selectedProduct!),
            ],
          ),
        ),
      ),
    );
  }
}
