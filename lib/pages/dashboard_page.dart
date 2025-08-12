import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api_config.dart'; // Adjust this import path as per your structure

// Dashboard data model for easy parsing
class DashboardData {
  final int totalOrders;
  final int ordersToday;
  final int activeUsers;
  final int inventoryItems;
  final List<Map<String, dynamic>> recentOrders;
  final List<Map<String, dynamic>> lowStockItems;

  DashboardData({
    required this.totalOrders,
    required this.ordersToday,
    required this.activeUsers,
    required this.inventoryItems,
    required this.recentOrders,
    required this.lowStockItems,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      totalOrders: json['totalOrders'] ?? 0,
      ordersToday: json['ordersToday'] ?? 0,
      activeUsers: json['activeUsers'] ?? 0,
      inventoryItems: json['inventoryItems'] ?? 0,
      recentOrders: (json['recentOrders'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      lowStockItems: (json['lowStockItems'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<DashboardData>? _dashboardFuture;
  String userName = '';
  bool _isLoadingUserName = true;

  @override
  void initState() {
    super.initState();
    _loadUserNameFromToken();
    _dashboardFuture = fetchDashboardData();
  }

  // JWT parsing helper to extract username
  Map<String, dynamic>? _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final Map<String, dynamic> payloadMap = json.decode(decoded);
      return payloadMap;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadUserNameFromToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null && token.isNotEmpty) {
      final payload = _parseJwt(token);
      if (payload != null) {
        setState(() {
          userName = (payload['name'] ?? payload['username'] ?? '').toString();
          _isLoadingUserName = false;
        });
        return;
      }
    }
    setState(() {
      userName = '';
      _isLoadingUserName = false;
    });
  }

  Future<DashboardData> fetchDashboardData() async {
    final apiUrl = '${getBackendBaseUrl()}/api/admin/dashboard';
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    debugPrint('Fetching dashboard from: $apiUrl');
    debugPrint('Using token: $token');

    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    debugPrint('Dashboard response status: ${response.statusCode}');
    debugPrint('Dashboard response body: ${response.body}');

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);

      // Optional: Handle API-level custom errors
      if (jsonData['message'] != null &&
          jsonData['message'] == 'User not found') {
        throw Exception('User not found. Please log in again.');
      }

      return DashboardData.fromJson(jsonData);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized access. Please log in again.');
    } else {
      throw Exception(
          'Failed to load dashboard data (HTTP ${response.statusCode})');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    if (_isLoadingUserName) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // appBar: AppBar(title: const Text('Dashboard')),
      body: FutureBuilder<DashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No dashboard data available.'));
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Dashboard',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (userName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 24),
                    child: Text('Welcome, $userName',
                        style: theme.textTheme.titleMedium),
                  ),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: isMobile ? screenWidth - 40 : 200,
                      child: infoCard(Icons.shopping_cart, 'Total Orders',
                          data.totalOrders.toString(), Colors.blueAccent),
                    ),
                    SizedBox(
                      width: isMobile ? screenWidth - 40 : 200,
                      child: infoCard(Icons.today, 'Orders Today',
                          data.ordersToday.toString(), Colors.green),
                    ),
                    SizedBox(
                      width: isMobile ? screenWidth - 40 : 200,
                      child: infoCard(Icons.person, 'Active Users',
                          data.activeUsers.toString(), Colors.orange),
                    ),
                    SizedBox(
                      width: isMobile ? screenWidth - 40 : 200,
                      child: infoCard(Icons.inventory, 'Inventory Items',
                          data.inventoryItems.toString(), Colors.purple),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                isMobile
                    ? Column(
                        children: [
                          dashboardCard(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Recent Orders',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(height: 12),
                                buildRecentOrdersList(data.recentOrders),
                              ],
                            ),
                          ),
                          dashboardCard(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.warning_amber,
                                        color: Colors.amber, size: 22),
                                    SizedBox(width: 6),
                                    Text('Low Stock',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                buildLowStockList(data.lowStockItems),
                              ],
                            ),
                          ),
                          dashboardCard(buildPlaceholder()),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: dashboardCard(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Recent Orders',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  const SizedBox(height: 12),
                                  buildRecentOrdersList(data.recentOrders),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: dashboardCard(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.warning_amber,
                                          color: Colors.amber, size: 22),
                                      SizedBox(width: 6),
                                      Text('Low Stock',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  buildLowStockList(data.lowStockItems),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(child: dashboardCard(buildPlaceholder())),
                        ],
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  // UI Helper Widgets (reuse your already provided implementations):

  Widget dashboardCard(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      child: child,
    );
  }

  Widget infoCard(IconData icon, String title, String value, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 22)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String formatPrice(dynamic price) {
    if (price == null) return 'RS 0.00';
    try {
      final numPrice = (price is num) ? price : num.parse(price.toString());
      return 'RS ${numPrice.toStringAsFixed(2)}';
    } catch (_) {
      return 'RS 0.00';
    }
  }

  String formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Widget buildRecentOrdersList(List<Map<String, dynamic>> recentOrders) {
    if (recentOrders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No recent orders found.',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: recentOrders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final order = recentOrders[index];
          final orderId = order['_id'] != null
              ? 'Order #${order['_id'].toString().substring(order['_id'].toString().length - 4)}'
              : 'Order #${index + 1}';
          final userName = order['userName'] ?? 'Unknown Customer';
          final totalPrice = formatPrice(order['totalPrice']);
          final date = formatDate(order['date']?.toString());
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(orderId,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    Text(userName,
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(totalPrice,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(date,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildLowStockList(List<Map<String, dynamic>> lowStockItems) {
    if (lowStockItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('All stock levels normal.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return SizedBox(
      height: 300,
      child: ListView.separated(
        itemCount: lowStockItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, idx) {
          final item = lowStockItems[idx];
          final name = item['name'] ?? 'Item #${idx + 1}';
          final category = item['category'] ?? '';
          final quantity = item['quantity']?.toString() ?? '0';
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(category,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                Text('Stock: $quantity',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.store, size: 36, color: Colors.blue),
        SizedBox(height: 8),
        Text('Retail Insights',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        SizedBox(height: 6),
        Text(
          'Add more widgets or stats relevant to retail here.',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
