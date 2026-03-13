import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';

class RoleManagement extends StatefulWidget {
  final Dio dio;

  const RoleManagement({super.key, required this.dio});

  @override
  State<RoleManagement> createState() => _RoleManagementState();
}

class _RoleManagementState extends State<RoleManagement> {
  List<Map<String, dynamic>> _userRoles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    setState(() => _isLoading = true);

    try {
      final response = await widget.dio.get('/waydowntown/user-roles');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List<dynamic>;
        final included =
            (response.data['included'] as List<dynamic>?) ?? [];

        setState(() {
          _userRoles = data.map((role) {
            final userId =
                role['relationships']?['user']?['data']?['id'] as String?;
            final userJson = userId != null
                ? included.firstWhere(
                    (item) =>
                        item['type'] == 'users' && item['id'] == userId,
                    orElse: () => null,
                  )
                : null;

            return {
              'id': role['id'],
              'role': role['attributes']['role'],
              'user_id': userId,
              'user_email': userJson?['attributes']?['email'],
              'user_name': userJson?['attributes']?['name'],
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      talker.error('Error fetching roles: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeRole(String roleId) async {
    try {
      await widget.dio.delete('/waydowntown/user-roles/$roleId');
      _fetchRoles();
    } catch (e) {
      talker.error('Error removing role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _showAddRoleDialog() {
    final emailController = TextEditingController();
    String selectedRole = 'validator';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration:
                    const InputDecoration(labelText: 'User ID (UUID)'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(
                      value: 'validator', child: Text('Validator')),
                  DropdownMenuItem(
                      value: 'validation_overseer',
                      child: Text('Validation Overseer')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => selectedRole = v);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await widget.dio.post(
                    '/waydowntown/user-roles',
                    data: {
                      'data': {
                        'type': 'user-roles',
                        'attributes': {
                          'role': selectedRole,
                        },
                        'relationships': {
                          'user': {
                            'data': {
                              'type': 'users',
                              'id': emailController.text,
                            }
                          },
                        },
                      }
                    },
                  );
                  if (context.mounted) Navigator.of(context).pop();
                  _fetchRoles();
                } catch (e) {
                  talker.error('Error assigning role: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Role Management')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRoleDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userRoles.isEmpty
              ? const Center(child: Text('No roles assigned'))
              : RefreshIndicator(
                  onRefresh: _fetchRoles,
                  child: ListView.builder(
                    itemCount: _userRoles.length,
                    itemBuilder: (context, index) {
                      final role = _userRoles[index];
                      return ListTile(
                        title: Text(role['user_name'] ??
                            role['user_email'] ??
                            role['user_id'] ??
                            'Unknown'),
                        subtitle: Text(role['role']),
                        leading: Icon(
                          role['role'] == 'validator'
                              ? Icons.verified_user
                              : Icons.supervisor_account,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeRole(role['id']),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
