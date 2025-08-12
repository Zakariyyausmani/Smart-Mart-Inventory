import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart'; // import backend config helper

class UsersPage extends StatefulWidget {
  const UsersPage({Key? key}) : super(key: key);

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<dynamic> users = [];
  bool loading = false;
  String? error;

  String searchQuery = "";

  // Editing User state & controllers
  dynamic editingUser;
  late TextEditingController editedUsernameController;
  late TextEditingController editedEmailController;
  String editedRole = "cashier";

  // Delete Confirmation state
  dynamic userToDelete;

  @override
  void initState() {
    super.initState();
    editedUsernameController = TextEditingController();
    editedEmailController = TextEditingController();
    fetchUsers();
  }

  @override
  void dispose() {
    editedUsernameController.dispose();
    editedEmailController.dispose();
    super.dispose();
  }

  Future<void> fetchUsers() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final baseUrl = getBackendBaseUrl();
      final resp = await http.get(
        Uri.parse("$baseUrl/api/users/all"),
        headers: {'Content-Type': 'application/json'},
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          users = data['users'] ?? [];
          loading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load users (code: ${resp.statusCode})';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load users: $e';
        loading = false;
      });
    }
  }

  Future<void> handleUpdateUser() async {
    if (editedUsernameController.text.trim().isEmpty ||
        editedEmailController.text.trim().isEmpty) {
      setState(() {
        error = "Please fill all required fields.";
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final baseUrl = getBackendBaseUrl();
      final resp = await http.put(
        Uri.parse("$baseUrl/api/users/${editingUser['_id']}"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': editedUsernameController.text.trim(),
          'email': editedEmailController.text.trim(),
          'role': editedRole,
        }),
      );

      if (resp.statusCode == 200) {
        setState(() {
          editingUser = null;
          loading = false;
        });
        await fetchUsers();
        if (mounted) Navigator.of(context).pop(); // Close edit dialog
      } else {
        setState(() {
          error = 'Failed to update user (code: ${resp.statusCode})';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Failed to update user: $e';
        loading = false;
      });
    }
  }

  Future<void> removeUser() async {
    if (userToDelete == null) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final baseUrl = getBackendBaseUrl();
      final resp = await http.delete(
        Uri.parse("$baseUrl/api/users/${userToDelete['_id']}"),
        headers: {'Content-Type': 'application/json'},
      );

      if (resp.statusCode == 200) {
        setState(() {
          userToDelete = null;
          loading = false;
        });
        await fetchUsers();
        if (mounted) Navigator.of(context).pop(); // Close delete dialog
      } else {
        setState(() {
          error = 'Failed to delete user (code: ${resp.statusCode})';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Failed to delete user: $e';
        loading = false;
      });
    }
  }

  void openEditDialog(dynamic user) {
    editingUser = user;
    editedUsernameController.text = user['username'] ?? "";
    editedEmailController.text = user['email'] ?? "";
    editedRole = user['role'] ?? "cashier";
    error = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text("Edit User"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    TextField(
                      controller: editedUsernameController,
                      decoration: const InputDecoration(labelText: "Username"),
                      enabled: !loading,
                      onChanged: (_) => setModalState(() {}),
                    ),
                    TextField(
                      controller: editedEmailController,
                      decoration: const InputDecoration(labelText: "Email"),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !loading,
                      onChanged: (_) => setModalState(() {}),
                    ),
                    DropdownButtonFormField<String>(
                      value: editedRole,
                      items: const [
                        DropdownMenuItem(
                            value: 'cashier', child: Text('Cashier')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: loading
                          ? null
                          : (val) {
                              if (val != null) {
                                setModalState(() {
                                  editedRole = val;
                                });
                              }
                            },
                      decoration: const InputDecoration(labelText: "Role"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          await handleUpdateUser();
                          setModalState(() {});
                        },
                  child: loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void openDeleteDialog(dynamic user) {
    userToDelete = user;
    error = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text("Confirm Delete"),
              content: Text(
                  'Are you sure you want to delete "${user['username']}"?'),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          await removeUser();
                          setModalState(() {});
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Delete"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<dynamic> get filteredUsers {
    if (searchQuery.trim().isEmpty) return users;
    final query = searchQuery.toLowerCase();
    return users.where((user) {
      final username = (user['username'] ?? "").toLowerCase();
      final email = (user['email'] ?? "").toLowerCase();
      return username.contains(query) || email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              if (loading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              if (loading) const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Refresh"),
                onPressed: loading ? null : fetchUsers,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: "Search users...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              setState(() {
                searchQuery = val;
              });
            },
            enabled: !loading,
          ),
          const SizedBox(height: 12),
          if (error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.red[100],
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(error!,
                          style: const TextStyle(color: Colors.red))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        error = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      loading ? "Loading users..." : "No users found.",
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: fetchUsers,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];

                        Widget userInfoSection = Wrap(
                          spacing: 16,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: isMobile
                                  ? MediaQuery.of(context).size.width * 0.95
                                  : 200,
                              child: Text(
                                user['username'] ?? "",
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: isMobile
                                  ? MediaQuery.of(context).size.width * 0.95
                                  : 280,
                              child: Text(
                                user['email'] ?? "",
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey[700]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: isMobile
                                  ? MediaQuery.of(context).size.width * 0.95
                                  : 120,
                              child: Text(
                                "Role: ${user['role'] ?? 'cashier'}",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );

                        return Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                userInfoSection,
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: loading
                                            ? null
                                            : () => openEditDialog(user),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[800],
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                        ),
                                        child: const Text("Edit"),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: loading
                                            ? null
                                            : () => openDeleteDialog(user),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red[700],
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                        ),
                                        child: const Text("Delete"),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
