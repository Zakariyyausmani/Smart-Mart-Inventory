import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';

class CustomerDetailsPage extends StatefulWidget {
  final String customerId;

  const CustomerDetailsPage({Key? key, required this.customerId})
      : super(key: key);

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  dynamic _customer;
  bool _loading = true;
  String? _error;

  // Refund state variables
  int? _selectedOrderIndex;
  Map<String, int> _refundQuantities = {};
  String _refundPassword = "";
  bool _refundLoading = false;
  String? _refundError;
  String? _refundSuccess;

  @override
  void initState() {
    super.initState();
    _fetchCustomerDetails();
  }

  Future<void> _fetchCustomerDetails() async {
    setState(() {
      _loading = true;
      _error = null;
      _refundError = null;
      _refundSuccess = null;
    });

    final baseUrl = getBackendBaseUrl();

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/customers/${widget.customerId}'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _customer = data;
          _error = null;

          // Reset refund states on fresh data load
          _selectedOrderIndex = null;
          _refundQuantities = {};
          _refundPassword = "";
          _refundError = null;
          _refundSuccess = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error =
              "Failed to load customer details: Server error ${response.statusCode}";
          _customer = null;
        });
      }
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _error = "No internet connection";
        _customer = null;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = "Request timed out. Please try again.";
        _customer = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Unexpected error: $e";
        _customer = null;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "-";
    try {
      final dt = DateTime.parse(dateString);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateString ?? "-";
    }
  }

  void _handleRefundQtyChange(String productId, int maxQty, String value) {
    int qty = int.tryParse(value) ?? 0;
    if (qty < 0) qty = 0;
    if (qty > maxQty) qty = maxQty;
    setState(() {
      _refundQuantities[productId] = qty;
    });
  }

  Future<void> _handleRefundSubmit() async {
    if (_selectedOrderIndex == null) {
      setState(() {
        _refundError = "Please select an order to refund.";
        _refundSuccess = null;
      });
      return;
    }

    final order = _customer['purchaseHistory'][_selectedOrderIndex];
    final itemsToRefund = <Map<String, dynamic>>[];

    for (final item in order['items']) {
      final qty = _refundQuantities[item['productId']] ?? 0;
      if (qty > 0) {
        itemsToRefund.add({'productId': item['productId'], 'quantity': qty});
      }
    }

    if (itemsToRefund.isEmpty) {
      setState(() {
        _refundError = "Please enter refund quantities.";
        _refundSuccess = null;
      });
      return;
    }

    if (_refundPassword.isEmpty) {
      setState(() {
        _refundError = "Please enter password for refund.";
        _refundSuccess = null;
      });
      return;
    }

    setState(() {
      _refundLoading = true;
      _refundError = null;
      _refundSuccess = null;
    });

    final baseUrl = getBackendBaseUrl();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/customers/refund'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customerId': _customer['_id'],
          'orderDate': order['orderDate'],
          'refundItems': itemsToRefund,
          'password': _refundPassword,
        }),
      );

      if (response.statusCode == 200) {
        await _fetchCustomerDetails(); // Refresh details after refund

        setState(() {
          _refundSuccess = "Refund processed successfully.";
          _refundQuantities = {};
          _refundPassword = "";
          _selectedOrderIndex = null;
          _refundError = null;
        });
      } else {
        final responseData = jsonDecode(response.body);
        setState(() {
          _refundError =
              responseData['error'] ?? 'Refund failed. Please try again.';
          _refundSuccess = null;
        });
      }
    } catch (e) {
      setState(() {
        _refundError = 'Refund failed. Please try again.';
        _refundSuccess = null;
      });
    } finally {
      setState(() {
        _refundLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(_customer != null
            ? (_customer['name'] ?? 'Customer Details')
            : 'Customer Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _customer == null
                    ? const Center(child: Text('No data available'))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Phone
                            Text.rich(
                              TextSpan(children: [
                                const TextSpan(
                                    text: "Phone: ",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: _customer['phone'] ?? '-'),
                              ]),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 20),

                            // Purchase History heading
                            const Text(
                              "Purchase History",
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),

                            // No purchase history message
                            if (_customer['purchaseHistory'] == null ||
                                (_customer['purchaseHistory'] as List).isEmpty)
                              const Text(
                                "No purchase history available.",
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              )
                            else ...[
                              // Order Selector Dropdown
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: DropdownButtonFormField<int>(
                                  decoration: const InputDecoration(
                                    labelText: "Select Order to Refund",
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  value: _selectedOrderIndex,
                                  onChanged: (index) {
                                    setState(() {
                                      _selectedOrderIndex = index;
                                      _refundQuantities.clear();
                                      _refundPassword = "";
                                      _refundError = null;
                                      _refundSuccess = null;
                                    });
                                  },
                                  items: [
                                    const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text("-- Select an order --"),
                                    ),
                                    ...List.generate(
                                      (_customer['purchaseHistory'] as List)
                                          .length,
                                      (i) {
                                        final order =
                                            _customer['purchaseHistory'][i];
                                        final itemCount =
                                            (order['items'] as List).length;
                                        final dateStr =
                                            _formatDateTime(order['orderDate']);
                                        return DropdownMenuItem<int>(
                                          value: i,
                                          child: Text(
                                              '$dateStr | $itemCount item${itemCount != 1 ? "s" : ""}'),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Selected order refund Qty inputs area
                              if (_selectedOrderIndex != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      ...(_customer['purchaseHistory']
                                                  [_selectedOrderIndex]['items']
                                              as List)
                                          .map((item) {
                                        final maxQty =
                                            item['quantity'] as int? ?? 0;
                                        final refundQty = _refundQuantities[
                                                item['productId']] ??
                                            0;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'] ?? 'Unnamed Item',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Purchased Quantity: $maxQty | Price: Rs. ${item['price']}',
                                                style: const TextStyle(
                                                    color: Colors.black87),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Text(
                                                      "Refund Quantity:"),
                                                  const SizedBox(width: 12),
                                                  Container(
                                                    width: 80,
                                                    child: TextFormField(
                                                      initialValue:
                                                          refundQty.toString(),
                                                      keyboardType:
                                                          const TextInputType
                                                              .numberWithOptions(
                                                              signed: false,
                                                              decimal: false),
                                                      decoration:
                                                          const InputDecoration(
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    vertical: 8,
                                                                    horizontal:
                                                                        8),
                                                        border:
                                                            OutlineInputBorder(),
                                                      ),
                                                      onChanged: (value) =>
                                                          _handleRefundQtyChange(
                                                              item['productId'],
                                                              maxQty,
                                                              value),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),

                                      // Password Field
                                      TextFormField(
                                        obscureText: true,
                                        decoration: const InputDecoration(
                                          labelText: "Password for Refund",
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            _refundPassword = value;
                                          });
                                        },
                                        initialValue: _refundPassword,
                                      ),

                                      if (_refundError != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 12),
                                          child: Text(
                                            _refundError!,
                                            style: const TextStyle(
                                                color: Colors.red),
                                          ),
                                        ),

                                      if (_refundSuccess != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 12),
                                          child: Text(
                                            _refundSuccess!,
                                            style: const TextStyle(
                                                color: Colors.green),
                                          ),
                                        ),

                                      const SizedBox(height: 12),

                                      ElevatedButton(
                                        onPressed: _refundLoading
                                            ? null
                                            : _handleRefundSubmit,
                                        child: _refundLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text("Process Refund"),
                                      ),
                                    ],
                                  ),
                                ),

                              // Divider
                              const SizedBox(height: 24),

                              // Full purchase history list
                              Container(
                                constraints: BoxConstraints(
                                  maxHeight: isMobile ? 300 : 500,
                                ),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  shrinkWrap: true,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount:
                                      (_customer['purchaseHistory'] as List)
                                          .length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final order =
                                        _customer['purchaseHistory'][index];
                                    final items =
                                        (order['items'] as List<dynamic>?) ??
                                            [];

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Ordered on: ${_formatDateTime(order['orderDate'])}',
                                          style: const TextStyle(
                                              color: Colors.grey, fontSize: 14),
                                        ),
                                        const SizedBox(height: 8),
                                        ...items.map((item) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 6),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['name'] ??
                                                      'Unnamed Item',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 16),
                                                ),
                                                Text(
                                                  'Price: Rs. ${item['price']} | Quantity: ${item['quantity']}',
                                                  style: const TextStyle(
                                                      fontSize: 14),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 20),

                              Text(
                                "Total Purchases: ${_customer['purchaseCount'] ?? 0}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ],
                        ),
                      ),
      ),
    );
  }
}
