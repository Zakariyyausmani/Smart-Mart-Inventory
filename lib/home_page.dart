import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/users_page.dart';
import 'pages/customers_page.dart';
import 'pages/products_page.dart';
import 'pages/categories_page.dart';
import 'pages/orders_page.dart';
import 'pages/inventory_page.dart';
import 'pages/reports_page.dart';
import 'pages/sales_page.dart';
import 'pages/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  String userName = '';
  String userEmail = '';
  String userRole = '';
  bool _isLoadingUser = true;

  // Modern professional colors
  static const Color primaryBlue = Color(0xFF1E88E5); // nice blue for accents
  static const Color drawerBgColor = Color(0xFFF5F7FB); // very light grey background
  static const Color textPrimary = Color(0xFF222222);
  static const Color textSecondary = Color(0xFF666666);
  static const Color selectedBgColor = Color(0xFFE3F2FD); // light blue highlight

  final List<_DrawerItem> _drawerItems = const [
    _DrawerItem(icon: Icons.dashboard_outlined, title: 'Dashboard'),
    _DrawerItem(icon: Icons.supervised_user_circle_outlined, title: 'Users'),
    _DrawerItem(icon: Icons.group_outlined, title: 'Customers'),
    _DrawerItem(icon: Icons.shopping_bag_outlined, title: 'Products'),
    _DrawerItem(icon: Icons.category_outlined, title: 'Categories'),
    _DrawerItem(icon: Icons.list_alt_outlined, title: 'Orders'),
    _DrawerItem(icon: Icons.inventory_2_outlined, title: 'Inventory'),
    _DrawerItem(icon: Icons.bar_chart_outlined, title: 'Reports'),
    _DrawerItem(icon: Icons.point_of_sale_outlined, title: 'Sales'),
    _DrawerItem(icon: Icons.settings_outlined, title: 'Settings'),
  ];

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    _pages = [
      const DashboardPage(),
      const UsersPage(),
      const CustomersPage(),
      const ProductsPage(),
      const CategoriesPage(),
      const OrdersPage(),
      const InventoryPage(),
      const ReportsPage(),
      const SalesPage(),
      const SettingsPage(),
    ];
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');

    if (userJson != null) {
      try {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        setState(() {
          userName = userMap['name'] ?? '';
          userEmail = userMap['email'] ?? '';
          userRole = userMap['role'] ?? '';
          _isLoadingUser = false;
        });
      } catch (_) {
        setState(() {
          userName = '';
          userEmail = '';
          userRole = '';
          _isLoadingUser = false;
        });
      }
    } else {
      setState(() {
        userName = '';
        userEmail = '';
        userRole = '';
        _isLoadingUser = false;
      });
    }
  }

  void _onSelectItem(int index) {
    Navigator.pop(context); // close drawer
    setState(() => _selectedIndex = index);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _drawerItems[_selectedIndex].title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryBlue,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Open menu',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
            color: Colors.white,
          ),
        ],
        elevation: 0,
      ),
      drawer: Drawer(
        child: Container(
          color: drawerBgColor,
          child: SafeArea(
            child: Column(
              children: [
                // User header with close button inside top-right corner
                Container(
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Stack(
                    children: [
                      // User info column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.white,
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            userName.isNotEmpty ? userName : 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userEmail.isNotEmpty
                                ? userEmail
                                : 'user@example.com',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),

                      // Close button: Chevron left inside circle
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Material(
                          color: Colors.white24,
                          shape: const CircleBorder(),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.chevron_left,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: _drawerItems.length,
                    itemBuilder: (context, index) {
                      final item = _drawerItems[index];
                      final isSelected = _selectedIndex == index;

                      return Container(
                        decoration: BoxDecoration(
                          color: isSelected ? selectedBgColor : Colors.transparent,
                          border: isSelected
                              ? Border(
                                  left: BorderSide(
                                    color: primaryBlue,
                                    width: 4,
                                  ),
                                )
                              : null,
                        ),
                        child: ListTile(
                          leading: Icon(
                            item.icon,
                            color: isSelected ? primaryBlue : textSecondary,
                            size: 24,
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? primaryBlue : textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          onTap: () => _onSelectItem(index),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(
                  height: 1,
                  thickness: 1,
                ),

                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text(
                    'Logout',
                    style:
                        TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                  onTap: _logout,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }
}

class _DrawerItem {
  final IconData icon;
  final String title;

  const _DrawerItem({required this.icon, required this.title});
}
