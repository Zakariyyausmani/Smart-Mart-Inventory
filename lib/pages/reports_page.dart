import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

import '../api_config.dart'; // Make sure the path is correct

class ReportsPage extends StatefulWidget {
  const ReportsPage({Key? key}) : super(key: key);

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _period = 'daily';
  Map<String, dynamic>? _summary;
  bool _loadingSummary = true;
  String? _errorSummary;

  bool _loadingTopProducts = false;
  List<dynamic> _topProducts = [];
  String? _errorTopProducts;

  bool _showReports = true;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() {
      _loadingSummary = true;
      _errorSummary = null;
    });

    final url = '${getBackendBaseUrl()}/api/SalesReports';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _summary = Map<String, dynamic>.from(data);
          _errorSummary = null;
        });
      } else {
        setState(() {
          _errorSummary =
              'Failed to fetch sales summary: ${response.statusCode}';
          _summary = null;
        });
      }
    } catch (_) {
      setState(() {
        _errorSummary = 'Error fetching sales summary.';
        _summary = null;
      });
    } finally {
      setState(() {
        _loadingSummary = false;
      });
    }
  }

  Future<void> _fetchTopProducts() async {
    setState(() {
      _loadingTopProducts = true;
      _errorTopProducts = null;
      _topProducts = [];
    });

    final url = '${getBackendBaseUrl()}/api/TopProducts?period=$_period';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _topProducts =
              (data['products'] is List) ? List.from(data['products']) : [];
          _errorTopProducts = null;
        });
      } else {
        setState(() {
          _errorTopProducts =
              'Failed to load top products (${response.statusCode}).';
        });
      }
    } catch (_) {
      setState(() {
        _errorTopProducts = 'Failed to load top products.';
      });
    } finally {
      setState(() {
        _loadingTopProducts = false;
      });
    }

    _showTopProductsModal();
  }

  void _showTopProductsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final maxHeight = MediaQuery.of(context).size.height * 0.85;
        return SizedBox(
          height: maxHeight,
          child: Column(
            children: [
              // Close button
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _loadingTopProducts
                      ? const Center(child: CircularProgressIndicator())
                      : _errorTopProducts != null
                          ? Center(
                              child: Text(_errorTopProducts!,
                                  style: const TextStyle(color: Colors.red)),
                            )
                          : _topProducts.isEmpty
                              ? const Center(
                                  child: Text('No top products available'))
                              : _TopProductsContent(
                                  products: _topProducts,
                                  period: _period,
                                ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<ChartData> _processChartData() {
    if (_summary == null || _summary?['salesTrend'] == null) return [];

    List<dynamic> dataList = [];

    switch (_period) {
      case 'daily':
        dataList = List<dynamic>.from(_summary!['salesTrend']['daily'] ?? []);
        break;
      case 'weekly':
        dataList = List<dynamic>.from(_summary!['salesTrend']['weekly'] ?? []);
        break;
      case 'monthly':
        dataList = List<dynamic>.from(_summary!['salesTrend']['monthly'] ?? []);
        break;
      case 'yearly':
        dataList = List<dynamic>.from(_summary!['salesTrend']['yearly'] ?? []);
        break;
      default:
        dataList = [];
    }

    final reversed = List<dynamic>.from(dataList.reversed);

    return List.generate(reversed.length, (i) {
      String label;
      switch (_period) {
        case 'daily':
          label = '${i + 1} Day ago';
          break;
        case 'weekly':
          label = '${i + 1} Week ago';
          break;
        case 'monthly':
          label = '${i + 1} Month ago';
          break;
        case 'yearly':
          label = '${i + 1} Year ago';
          break;
        default:
          label = '';
      }
      return ChartData(label, (reversed[i] as num).toDouble());
    });
  }

  static String formatCurrency(num value) => 'RS ' + value.toStringAsFixed(2);

  List<BarChartGroupData> _buildBarGroups(List<ChartData> data) =>
      data.asMap().entries.map((e) {
        final index = e.key;
        final item = e.value;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: item.sales.toDouble(), // <<< Explicitly cast to double here
              color: Colors.blue,
              width: 12,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          showingTooltipIndicators: [0],
        );
      }).toList();

  Widget _buildBarChart() {
    final chartData = _processChartData();

    if (chartData.isEmpty) {
      return const Center(child: Text('No sales trend data'));
    }

    final maxY =
        chartData.map((d) => d.sales).fold<double>(0.0, math.max) * 1.2;
    final screenWidth = MediaQuery.of(context).size.width;

    // Width for horizontal scroll if needed (per bar: 12 width + 8 spacing)
    final totalBarWidth = chartData.length * (12 + 8);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: SizedBox(
        width: totalBarWidth < screenWidth
            ? screenWidth
            : totalBarWidth.toDouble(),
        height: 250, // Fixed ideal height for mobile-friendly chart
        child: BarChart(
          BarChartData(
            maxY: maxY,
            barGroups: _buildBarGroups(chartData),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= chartData.length)
                      return const SizedBox.shrink();

                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        chartData[index].label,
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                  interval: 1,
                  reservedSize: 42,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 36),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(show: true),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: Colors.blueAccent,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final label = chartData[group.x.toInt()].label;
                  final value = rod.toY;
                  return BarTooltipItem(
                    '$label\n',
                    const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    children: <TextSpan>[
                      TextSpan(
                        text: 'RS ${value.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.yellowAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          swapAnimationDuration: const Duration(milliseconds: 350),
          swapAnimationCurve: Curves.easeInOut,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final periods = [
      {'value': 'daily', 'label': 'Daily'},
      {'value': 'weekly', 'label': 'Weekly'},
      {'value': 'monthly', 'label': 'Monthly'},
      {'value': 'yearly', 'label': 'Yearly'},
    ];

    Map<String, num> totalSalesMap = {
      'daily': (_summary?['todaySales'] ?? 0) as num,
      'weekly': (_summary?['weeklySales'] ?? 0) as num,
      'monthly': (_summary?['monthlySales'] ?? 0) as num,
      'yearly': (_summary?['yearlySales'] ?? 0) as num,
    };

    Map<String, int> transactionsMap = {
      'daily': _summary?['todayTransactions'] is int
          ? _summary!['todayTransactions']
          : 0,
      'weekly': _summary?['weeklyTransactions'] is int
          ? _summary!['weeklyTransactions']
          : 0,
      'monthly': _summary?['monthlyTransactions'] is int
          ? _summary!['monthlyTransactions']
          : 0,
      'yearly': _summary?['yearlyTransactions'] is int
          ? _summary!['yearlyTransactions']
          : 0,
    };

    Map<String, int> itemsSoldMap = {
      'daily':
          _summary?['todayItemsSold'] is int ? _summary!['todayItemsSold'] : 0,
      'weekly': _summary?['weeklyItemsSold'] is int
          ? _summary!['weeklyItemsSold']
          : 0,
      'monthly': _summary?['monthlyItemsSold'] is int
          ? _summary!['monthlyItemsSold']
          : 0,
      'yearly': _summary?['yearlyItemsSold'] is int
          ? _summary!['yearlyItemsSold']
          : 0,
    };

    Map<String, num> avgSaleMap = {
      'daily': (_summary?['todayAvgSale'] ?? 0) as num,
      'weekly': (_summary?['weeklyAvgSale'] ?? 0) as num,
      'monthly': (_summary?['monthlyAvgSale'] ?? 0) as num,
      'yearly': (_summary?['yearlyAvgSale'] ?? 0) as num,
    };

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadingSummary ? null : _fetchSummary,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close Reports',
                    onPressed: () {
                      setState(() {
                        _showReports = false;
                      });
                    },
                  )
                ],
              ),
              if (_showReports) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: periods.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = periods[index];
                      final isSelected = item['value'] == _period;
                      return ChoiceChip(
                        label: Text(item['label']!),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _period = item['value']!;
                          });
                          _fetchTopProducts();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.start,
                  children: [
                    _SummaryCard(
                      icon: Icons.trending_up,
                      title: "Total Sales",
                      value: formatCurrency(totalSalesMap[_period]!),
                      color: Colors.blue,
                    ),
                    _SummaryCard(
                      icon: Icons.calendar_today,
                      title: "Transactions",
                      value: transactionsMap[_period].toString(),
                      color: Colors.green,
                    ),
                    _SummaryCard(
                      icon: Icons.inventory_2,
                      title: "Items Sold",
                      value: itemsSoldMap[_period].toString(),
                      color: Colors.orange,
                    ),
                    _SummaryCard(
                      icon: Icons.attach_money,
                      title: "Avg. Sale",
                      value: formatCurrency(avgSaleMap[_period]!),
                      color: Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: _loadingSummary
                      ? const Center(child: CircularProgressIndicator())
                      : _errorSummary != null
                          ? Center(
                              child: Text(_errorSummary!,
                                  style: const TextStyle(color: Colors.red)),
                            )
                          : _buildBarChart(),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.show_chart_rounded),
                    label: const Text("Show Top Products"),
                    onPressed: _loadingTopProducts ? null : _fetchTopProducts,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!_showReports)
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.bar_chart),
                    label: const Text("Open Reports"),
                    onPressed: () {
                      setState(() {
                        _showReports = true;
                        _fetchSummary();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _SummaryCard({
    Key? key,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class ChartData {
  final String label;
  final double sales;

  ChartData(this.label, this.sales);
}

class _TopProductsContent extends StatelessWidget {
  final List<dynamic> products;
  final String period;

  const _TopProductsContent(
      {Key? key, required this.products, required this.period})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Top Selling Products ($period)',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: products.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product['name'] ?? 'Unnamed product'),
                subtitle: Text(
                  'Price: Rs ${product['price'] != null ? (product['price'] as num).toStringAsFixed(2) : '-'}\n'
                  'Quantity Sold: ${product['sales'] ?? '-'}\n'
                  'Revenue: Rs ${product['revenue'] != null ? (product['revenue'] as num).toStringAsFixed(2) : '-'}',
                ),
                isThreeLine: true,
              );
            },
          ),
        ),
      ],
    );
  }
}
