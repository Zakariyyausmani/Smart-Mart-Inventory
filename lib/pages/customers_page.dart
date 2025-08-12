import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart'; // Backend URL helper
import 'customer_details_page.dart'; // Import the details page

/// Capitalizes first letter of each word
String capitalizeWords(String input) {
  return input.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

class CustomersPage extends StatefulWidget {
  const CustomersPage({Key? key}) : super(key: key);

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  List<dynamic> _customers = [];
  List<dynamic> _filteredCustomers = [];
  bool _loading = false;
  String? _error;
  String _searchTerm = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchCustomers();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {
      _searchTerm = _searchController.text;
      _filterCustomers();
    });
  }

  void _filterCustomers() {
    if (_searchTerm.trim().isEmpty) {
      _filteredCustomers = _customers;
    } else {
      final lowerTerm = _searchTerm.toLowerCase();
      _filteredCustomers = _customers.where((customer) {
        final name = (customer['name'] ?? "").toString().toLowerCase();
        final phone = (customer['phone'] ?? "").toString().toLowerCase();
        return name.contains(lowerTerm) || phone.contains(lowerTerm);
      }).toList();
    }
  }

  Future<void> _fetchCustomers() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final baseUrl = getBackendBaseUrl();

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/customers'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final customers = data['customers'] as List<dynamic>?;

        if (customers == null) {
          if (!mounted) return;
          setState(() {
            _error = "Invalid data from server";
            _customers = [];
            _filteredCustomers = [];
          });
        } else {
          if (!mounted) return;
          setState(() {
            _customers = customers;
            _filterCustomers();
            _error = null;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _error =
              "Failed to load customers: Server error ${response.statusCode}";
          _customers = [];
          _filteredCustomers = [];
        });
      }
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _error = "No internet connection";
        _customers = [];
        _filteredCustomers = [];
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = "Request timed out. Please try again.";
        _customers = [];
        _filteredCustomers = [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Unexpected error: $e";
        _customers = [];
        _filteredCustomers = [];
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
      final dateTime = DateTime.parse(dateString);
      final month = _monthShortName(dateTime.month);
      final day = dateTime.day.toString().padLeft(2, '0');
      final year = dateTime.year;
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return "$month $day, $year, $hour:$minute";
    } catch (_) {
      return dateString;
    }
  }

  String _monthShortName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  void _openCustomerDetailsPage(dynamic customer) {
    if (customer['_id'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              CustomerDetailsPage(customerId: customer['_id']),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Align(
      alignment: Alignment.centerLeft,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.refresh),
        label: const Text("Refresh"),
        onPressed: _loading ? null : _fetchCustomers,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontSize: 14),
        ),
      ),
    ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search by name or phone...',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            enabled: !_loading,
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.red[800]),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _error = null),
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filteredCustomers.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  "No customers found.",
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchCustomers,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 1;
                    if (!isMobile) {
                      final width = constraints.maxWidth;
                      if (width >= 1100) {
                        crossAxisCount = 4;
                      } else if (width >= 800) {
                        crossAxisCount = 3;
                      } else if (width >= 500) {
                        crossAxisCount = 2;
                      }
                    }
                    return GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 2.3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openCustomerDetailsPage(customer),
                          child: Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    capitalizeWords(
                                        customer['name'] ?? "Unnamed"),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Phone: ${customer['phone'] ?? "-"}",
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: Colors.grey[800]),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Purchase Count: ${customer['purchaseCount'] ?? 0}",
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Created: ${_formatDateTime(customer['createdAt'])}",
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
