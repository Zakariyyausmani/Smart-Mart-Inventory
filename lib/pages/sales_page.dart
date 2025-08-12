import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';

// String getBackendBaseUrl() {
//   const port = 8080;
//   if (kIsWeb) return 'http://localhost:$port';
//   if (Platform.isAndroid) return 'http://10.0.2.2:$port';
//   if (Platform.isIOS) return 'http://localhost:$port';
//   return 'http://localhost:$port';
// }

class SalesPage extends StatefulWidget {
  const SalesPage({Key? key}) : super(key: key);

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  bool loading = true;
  String? error;
  Map<String, dynamic> salesData = {
    "todaySales": 0.0,
    "weeklySales": 0.0,
    "monthlySales": 0.0,
    "yearlySales": 0.0,
    "totalSales": 0.0,
  };

  @override
  void initState() {
    super.initState();
    _fetchSalesSummary();
  }

  Future<void> _fetchSalesSummary() async {
    setState(() {
      loading = true;
      error = null;
    });

    final url = Uri.parse('${getBackendBaseUrl()}/api/SalesSummary');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          salesData = {
            "todaySales": (data['todaySales'] ?? 0).toDouble(),
            "weeklySales": (data['weeklySales'] ?? 0).toDouble(),
            "monthlySales": (data['monthlySales'] ?? 0).toDouble(),
            "yearlySales": (data['yearlySales'] ?? 0).toDouble(),
            "totalSales": (data['totalSales'] ?? 0).toDouble(),
          };
          loading = false;
        });
      } else {
        setState(() {
          error = "Failed to load sales summary";
          loading = false;
        });
      }
    } catch (_) {
      setState(() {
        error = "Failed to load sales summary";
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Construct sales summary items
    final salesItems = [
      {"label": "Today's Sale", "value": salesData["todaySales"] ?? 0.0},
      {
        "label": "Weekly Sale (Last 7 Days)",
        "value": salesData["weeklySales"] ?? 0.0
      },
      {
        "label": "Monthly Sale (Last 30 Days)",
        "value": salesData["monthlySales"] ?? 0.0
      },
      {
        "label": "Yearly Sale (Last 365 Days)",
        "value": salesData["yearlySales"] ?? 0.0
      },
      {"label": "Total Sale", "value": salesData["totalSales"] ?? 0.0},
    ];

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: loading
                ? const SizedBox(
                    height: 150,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 3)),
                  )
                : error != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          error!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          // Responsive grid: 1 col on narrow, 2 cols on wider windows >= 450 px, 3 cols >= 700 px
                          int crossAxisCount = 1;
                          if (constraints.maxWidth >= 700) {
                            crossAxisCount = 3;
                          } else if (constraints.maxWidth >= 450) {
                            crossAxisCount = 2;
                          }

                          return GridView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: salesItems.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              childAspectRatio: 1.4,
                            ),
                            itemBuilder: (context, index) {
                              final item = salesItems[index];
                              return Card(
                                elevation: 6,
                                shadowColor: Colors.indigo.shade100,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(22),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        item["label"] ?? '',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.indigo.shade700,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'RS ${(item["value"] as double).toStringAsFixed(2)}',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade900,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ),
      ),
    );
  }
}
