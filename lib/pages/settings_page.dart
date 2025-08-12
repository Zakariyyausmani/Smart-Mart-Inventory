import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api_config.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? currentUser;
  String? token;

  bool loadingUsers = false;
  String errorUsers = '';
  List<Map<String, dynamic>> users = [];

  Map<String, dynamic>? editingUser;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController currentPasswordController = TextEditingController();

  String roleValue = "cashier";

  @override
  void initState() {
    super.initState();
    _loadUserAndToken();
  }

  Future<void> _loadUserAndToken() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    final storedToken = prefs.getString('token');

    if (userString != null) {
      setState(() {
        currentUser = jsonDecode(userString);
        token = storedToken;
      });
      if (currentUser?['role'] == 'admin') {
        fetchUsers();
      }
    }
  }

  Future<void> fetchUsers() async {
    if (token == null) return;
    setState(() {
      loadingUsers = true;
      errorUsers = '';
    });
    try {
      final response = await http.get(
        Uri.parse('${getBackendBaseUrl()}/setting/users'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          users = List<Map<String, dynamic>>.from(data['users'] ?? []);
        });
      } else {
        setState(() {
          errorUsers = 'Failed to load users (Status: ${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        errorUsers = 'Failed to load users';
      });
      debugPrint('Error loading users: $e');
    } finally {
      setState(() {
        loadingUsers = false;
      });
    }
  }

  void openUserDialog([Map<String, dynamic>? user]) {
    editingUser = user;
    usernameController.text = user?['username'] ?? '';
    emailController.text = user?['email'] ?? '';
    roleValue = user?['role'] ?? 'cashier';
    passwordController.clear();
    confirmPasswordController.clear();
    currentPasswordController.clear();
    setState(() {});
    _showUserDialog();
  }

  void openProfileDialog() {
    if (currentUser == null) return;
    editingUser = currentUser;
    usernameController.text = currentUser!['username'] ?? '';
    emailController.text = currentUser!['email'] ?? '';
    roleValue = currentUser!['role'] ?? 'admin';
    passwordController.clear();
    confirmPasswordController.clear();
    currentPasswordController.clear();
    setState(() {});
    _showProfileDialog();
  }

  bool validateForm({required bool isProfile}) {
    final form = _formKey.currentState;
    if (form == null) return false;
    if (!form.validate()) return false;

    if (isProfile) {
      if ((passwordController.text.isNotEmpty ||
              confirmPasswordController.text.isNotEmpty) &&
          currentPasswordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Current password is required to change password in profile"),
          ),
        );
        return false;
      }
      if (passwordController.text != confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Passwords do not match")),
        );
        return false;
      }
    } else {
      if (editingUser == null && passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password is required")),
        );
        return false;
      }
      if (passwordController.text != confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Passwords do not match")),
        );
        return false;
      }
    }

    if (editingUser != null &&
        editingUser!['_id'] != currentUser?['_id'] &&
        currentUser?['role'] != 'admin' &&
        roleValue != editingUser!['role']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot change the role")),
      );
      return false;
    }

    return true;
  }

  Future<void> handleSubmit() async {
    final isProfile = editingUser != null && editingUser == currentUser;
    if (!validateForm(isProfile: isProfile)) return;
    if (token == null) return;

    try {
      if (isProfile) {
        final updateData = {
          'username': usernameController.text.trim(),
          'email': emailController.text.trim(),
        };
        if (passwordController.text.isNotEmpty) {
          updateData['password'] = passwordController.text;
          updateData['currentPassword'] = currentPasswordController.text;
        }

        final response = await http.put(
          Uri.parse(
              '${getBackendBaseUrl()}/setting/users/${currentUser?['userId'] ?? currentUser?['_id']}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(updateData),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile updated successfully")),
          );
          final updatedUser = {
            ...?currentUser,
            'username': usernameController.text.trim(),
            'email': emailController.text.trim(),
          };
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(updatedUser));
          setState(() {
            currentUser = updatedUser;
          });
          Navigator.of(context).pop();
        } else {
          final errorData = response.body;
          debugPrint('Error response: $errorData');
          throw Exception('Failed to update profile (Status ${response.statusCode})');
        }
      } else {
        if (editingUser != null) {
          final updateData = {
            'username': usernameController.text.trim(),
            'email': emailController.text.trim(),
            'role': roleValue,
          };
          if (passwordController.text.isNotEmpty) {
            updateData['password'] = passwordController.text;
          }

          final response = await http.put(
            Uri.parse('${getBackendBaseUrl()}/setting/users/${editingUser!['_id']}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(updateData),
          );

          if (response.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("User updated successfully")),
            );
            Navigator.of(context).pop();
            fetchUsers();
          } else {
            final errorData = response.body;
            debugPrint('Error response: $errorData');
            throw Exception('Failed to update user (Status ${response.statusCode})');
          }
        } else {
          final newUser = {
            'username': usernameController.text.trim(),
            'email': emailController.text.trim(),
            'password': passwordController.text,
            'role': roleValue,
          };

          final response = await http.post(
            Uri.parse('${getBackendBaseUrl()}/setting/users'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(newUser),
          );

          if (response.statusCode == 201 || response.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("User created successfully")),
            );
            Navigator.of(context).pop();
            fetchUsers();
          } else {
            final errorData = response.body;
            debugPrint('Error response: $errorData');
            throw Exception('Failed to create user (Status ${response.statusCode})');
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to save user/profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save user: $e')),
      );
    }
  }

  Future<void> handleDeleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this user?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;
    if (token == null) return;

    try {
      final response = await http.delete(
        Uri.parse('${getBackendBaseUrl()}/setting/users/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User deleted successfully")),
        );
        fetchUsers();
      } else {
        final errorData = response.body;
        debugPrint('Error response: $errorData');
        throw Exception('Failed to delete user (Status ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Failed to delete user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete user: $e")),
      );
    }
  }

  bool canEditUser(Map<String, dynamic> userToCheck) {
    if (userToCheck.isEmpty) return false;
    if (currentUser == null) return false;

    if (currentUser!['_id'] == userToCheck['_id']) return true;
    if (currentUser!['role'] == 'admin' && userToCheck['role'] == 'cashier') {
      return true;
    }
    return false;
  }

  bool canDeleteUser(Map<String, dynamic> userToCheck) {
    if (currentUser == null) return false;
    return currentUser!['role'] == 'admin' &&
        userToCheck['role'] == 'cashier' &&
        currentUser!['_id'] != userToCheck['_id'];
  }

  Future<void> _showUserDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(editingUser != null
            ? 'Edit User: ${editingUser!['username']}'
            : 'Add User'),
        content: _buildForm(isProfile: false),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await handleSubmit();
            },
            child: Text(editingUser != null ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _showProfileDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Edit Profile'),
        content: _buildForm(isProfile: true),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await handleSubmit();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm({required bool isProfile}) {
    return SizedBox(
      width: 350,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Username is required' : null,
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Email is required';
                  }
                  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                  if (!emailRegex.hasMatch(val.trim())) {
                    return 'Invalid email address';
                  }
                  return null;
                },
              ),
              if (isProfile) ...[
                TextFormField(
                  controller: currentPasswordController,
                  decoration: const InputDecoration(labelText: 'Current Password'),
                  obscureText: true,
                ),
              ],
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: isProfile
                      ? 'New Password'
                      : editingUser != null
                          ? 'New Password (leave empty to keep current)'
                          : 'Password',
                ),
                obscureText: true,
                validator: (val) {
                  if (!isProfile && editingUser == null) {
                    if (val == null || val.isEmpty) {
                      return 'Password is required';
                    }
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: confirmPasswordController,
                decoration: InputDecoration(
                  labelText: isProfile ? 'Confirm New Password' : 'Confirm Password',
                ),
                obscureText: true,
                validator: (val) {
                  if (passwordController.text.isNotEmpty &&
                      val != passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              if (!isProfile && currentUser?['role'] == 'admin') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Role'),
                  value: roleValue,
                  onChanged: (v) {
                    setState(() {
                      roleValue = v ?? 'cashier';
                    });
                  },
                  items: const [
                    DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    currentPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Loading user data...',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Refresh button at top-left corner
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Refresh"),
                  onPressed: () {
                    if (currentUser?['role'] == 'admin') {
                      fetchUsers();
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  bool isWide = constraints.maxWidth > 700;
                  return SingleChildScrollView(
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildProfileCard()),
                              const SizedBox(width: 16),
                              if (currentUser?['role'] == 'admin')
                                Expanded(child: _buildUserManagementCard(constraints)),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildProfileCard(),
                              if (currentUser?['role'] == 'admin') ...[
                                const SizedBox(height: 16),
                                _buildUserManagementCard(constraints),
                              ],
                            ],
                          ),
                  );
                }),
              ),

              if (currentUser?['role'] == 'admin' && users.isNotEmpty)
                Expanded(child: _buildAllUsersTable()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Icon(Icons.person, color: Colors.grey),
              SizedBox(width: 8),
              Text('Profile Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.grey.shade300,
                  child: const Icon(Icons.person, size: 32, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentUser?['username'] ?? '',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(currentUser?['email'] ?? '',
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        currentUser?['role']?.toString().capitalize() ?? '',
                        style: const TextStyle(
                            color: Colors.grey, fontStyle: FontStyle.italic),
                      )
                    ],
                  ),
                ),
                // Icon button only for Edit Profile, no text!
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Profile',
                  onPressed: openProfileDialog,
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserManagementCard(BoxConstraints constraints) {
    double maxHeight = 400;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Colors.grey),
                SizedBox(width: 8),
                Text('User Management',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),

            // Add User button on the next line below header
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () => openUserDialog(null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add User"),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: maxHeight,
              child: loadingUsers
                  ? const Center(child: CircularProgressIndicator())
                  : errorUsers.isNotEmpty
                      ? Center(
                          child: Text(
                          errorUsers,
                          style: const TextStyle(color: Colors.red),
                        ))
                      : users.isEmpty
                          ? const Center(child: Text('No users found'))
                          : ListView.separated(
                              itemCount: users.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final u = users[i];
                                return ListTile(
                                  title: Text(u['username'] ?? ''),
                                  subtitle: Text(u['email'] ?? ''),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed:
                                            canEditUser(u) ? () => openUserDialog(u) : null,
                                        tooltip: canEditUser(u) ? 'Edit user' : 'Cannot edit user',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed:
                                            canDeleteUser(u) ? () => handleDeleteUser(u['_id']) : null,
                                        tooltip: canDeleteUser(u)
                                            ? 'Delete user'
                                            : 'Cannot delete user',
                                        color: Colors.red,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAllUsersTable() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Username')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Role')),
            DataColumn(label: Text('Actions')),
          ],
          rows: users.map((u) {
            return DataRow(cells: [
              DataCell(Text(u['username'] ?? '')),
              DataCell(Text(u['email'] ?? '')),
              DataCell(Text(
                (u['role'] ?? '').toString().capitalize(),
              )),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: canEditUser(u) ? () => openUserDialog(u) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed:
                        canDeleteUser(u) ? () => handleDeleteUser(u['_id']) : null,
                    color: Colors.red,
                  ),
                ],
              ))
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : this[0].toUpperCase() + substring(1).toLowerCase();
}
