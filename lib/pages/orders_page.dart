import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../api_config.dart'; // Import your backend base URL here

class OrdersPage extends StatefulWidget {
  const OrdersPage({Key? key}) : super(key: key);

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> topOrders = [];
  int page = 1;
  int totalPages = 1;
  bool loadingOrders = false;
  bool loadingTopOrders = false;
  String? error;

  final int limitPerPage = 5;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    // Refresh both top orders and paginated orders
    await Future.wait([_fetchTopOrders(), _fetchOrders(1)]);
  }

  Future<void> _fetchOrders(int pageNum) async {
    setState(() {
      loadingOrders = true;
      error = null;
    });

    try {
      final res = await http.get(Uri.parse(
          '${getBackendBaseUrl()}/api/orders/paginated?page=$pageNum&limit=$limitPerPage'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final fetchedOrders =
            (data['orders'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
                [];
        final fetchedTotalPages = data['totalPages'] ?? 1;

        setState(() {
          orders = fetchedOrders;
          totalPages = fetchedTotalPages;
          page = pageNum;
        });
      } else {
        setState(() {
          error = 'Failed to load orders';
          orders = [];
          totalPages = 1;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error fetching orders';
        orders = [];
        totalPages = 1;
      });
    }

    setState(() {
      loadingOrders = false;
    });
  }

  Future<void> _fetchTopOrders() async {
    setState(() {
      loadingTopOrders = true;
    });

    try {
      final res =
          await http.get(Uri.parse('${getBackendBaseUrl()}/api/orders/top'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final fetchedTopOrders = (data['topOrders'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        setState(() {
          topOrders = fetchedTopOrders;
        });
      } else {
        setState(() {
          topOrders = [];
        });
      }
    } catch (_) {
      // Silent fail for top orders
      setState(() {
        topOrders = [];
      });
    }

    setState(() {
      loadingTopOrders = false;
    });
  }

  String _formattedDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat.yMd().add_jm().format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatPrice(dynamic price) {
    try {
      if (price == null) return "0.00";
      if (price is double) return price.toStringAsFixed(2);
      if (price is int) return price.toStringAsFixed(2);
      if (price is num) return price.toDouble().toStringAsFixed(2);
      return double.parse(price.toString()).toStringAsFixed(2);
    } catch (_) {
      return price.toString();
    }
  }

  Widget _buildTopOrdersList() {
    if (loadingTopOrders) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (topOrders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            "No top orders available.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Top Orders",
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topOrders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = topOrders[index];
            return InkWell(
              onTap: () {
                // Optional: implement detail navigation
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.grey.shade50],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 2)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(order['userName'] ?? "Unknown User",
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.indigo)),
                        Text(order['userPhone'] ?? "",
                            style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w400)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        Text("Total: RS ${_formatPrice(order['totalPrice'])}",
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text("Items: ${order['items']?.length ?? 0}",
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          _formattedDate(order['date'] ?? ''),
                          style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                              fontWeight: FontWeight.w400),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOrderHistoryList() {
    if (loadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }
    if (orders.isEmpty) {
      return const Center(
          child: Text("No order history found.",
              style: TextStyle(color: Colors.grey)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Order History",
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            return InkWell(
              onTap: () {
                // Optional: implement detail navigation
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(order['userName'] ?? "Unknown User",
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.indigo)),
                        Text(order['userPhone'] ?? "",
                            style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w400)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        Text("Total: RS ${_formatPrice(order['totalPrice'])}",
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text("Items: ${order['items']?.length ?? 0}",
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          "Payment: ${order['paymentMethod'] ?? 'N/A'}",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _formattedDate(order['date'] ?? ''),
                          style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                              fontWeight: FontWeight.w400),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildPaginationControls(),
      ],
    );
  }

  Widget _buildPaginationControls() {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 350;
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          ElevatedButton(
            onPressed: (page > 1 && !loadingOrders)
                ? () => _fetchOrders(page - 1)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
              disabledBackgroundColor: Colors.indigo.shade300,
            ),
            child: const Text("Previous"),
          ),
          Container(
            height: 36,
            alignment: Alignment.center,
            child: Text(
              'Page $page of $totalPages',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: (page < totalPages && !loadingOrders)
                ? () => _fetchOrders(page + 1)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
              disabledBackgroundColor: Colors.indigo.shade300,
            ),
            child: const Text("Next"),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Top Bar with Title and Refresh button
              _buildTopBar(),

              const SizedBox(height: 16),

              Expanded(
                child: isWideScreen
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  _buildTopOrdersList(),
                                  const SizedBox(height: 24),
                                  _buildOrderHistoryList(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildTopOrdersList(),
                            const SizedBox(height: 24),
                            _buildOrderHistoryList(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // const Text(
        //   'Orders Dashboard',
        //   style: TextStyle(
        //     fontSize: 24,
        //     fontWeight: FontWeight.bold,
        //     color: Colors.indigo,
        //   ),
        // ),
        ElevatedButton.icon(
          onPressed: loadingOrders || loadingTopOrders ? null : _refreshAll,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
