import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';

const _knownRoles = ['validator', 'validation_overseer'];

const _roleLabels = {
  'validator': 'Validator',
  'validation_overseer': 'Validation Overseer',
};

class RoleManagement extends StatefulWidget {
  final Dio dio;

  const RoleManagement({super.key, required this.dio});

  @override
  State<RoleManagement> createState() => _RoleManagementState();
}

class _RoleManagementState extends State<RoleManagement> {
  List<_UserWithRoles> _users = [];
  List<_SimpleUser> _allUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      final rolesResponse = await widget.dio.get('/waydowntown/user-roles');
      final usersResponse = await widget.dio.get('/waydowntown/users');

      if (rolesResponse.statusCode == 200 && usersResponse.statusCode == 200) {
        final rolesData = rolesResponse.data['data'] as List<dynamic>;
        final rolesIncluded =
            (rolesResponse.data['included'] as List<dynamic>?) ?? [];

        // Parse all users
        final usersData = usersResponse.data['data'] as List<dynamic>;
        _allUsers = usersData
            .map((u) => _SimpleUser(
                  id: u['id'] as String,
                  email: u['attributes']['email'] as String? ?? '',
                  name: u['attributes']['name'] as String?,
                ))
            .toList();

        // Build role assignment map: userId -> {role -> roleRecordId}
        final Map<String, Map<String, String>> userRoleMap = {};
        for (final role in rolesData) {
          final userId =
              role['relationships']?['user']?['data']?['id'] as String?;
          if (userId == null) continue;
          final roleName = role['attributes']['role'] as String;
          userRoleMap.putIfAbsent(userId, () => {});
          userRoleMap[userId]![roleName] = role['id'] as String;
        }

        // Build user list: users with at least one role
        final usersWithRoles = <_UserWithRoles>[];
        for (final entry in userRoleMap.entries) {
          final userId = entry.key;
          // Find user info from included or allUsers
          var email = '';
          String? name;
          final includedUser = rolesIncluded.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['type'] == 'users' && item?['id'] == userId,
            orElse: () => null,
          );
          if (includedUser != null) {
            email = includedUser['attributes']?['email'] as String? ?? '';
            name = includedUser['attributes']?['name'] as String?;
          }

          usersWithRoles.add(_UserWithRoles(
            id: userId,
            email: email,
            name: name,
            roleIds: entry.value,
          ));
        }

        usersWithRoles.sort((a, b) => a.email.compareTo(b.email));

        setState(() {
          _users = usersWithRoles;
          _isLoading = false;
        });
      }
    } catch (e) {
      talker.error('Error fetching roles: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignRole(String userId, String role) async {
    try {
      await widget.dio.post(
        '/waydowntown/user-roles',
        data: {
          'data': {
            'type': 'user-roles',
            'attributes': {'role': role},
            'relationships': {
              'user': {
                'data': {'type': 'users', 'id': userId}
              },
            },
          }
        },
      );
      _fetchData();
    } catch (e) {
      talker.error('Error assigning role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _removeRole(String roleId) async {
    try {
      await widget.dio.delete('/waydowntown/user-roles/$roleId');
      _fetchData();
    } catch (e) {
      talker.error('Error removing role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _showAddUserDialog() {
    _SimpleUser? selectedUser;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add User'),
            content: DropdownButtonFormField<_SimpleUser>(
              // ignore: deprecated_member_use
              value: selectedUser,
              decoration: const InputDecoration(labelText: 'User'),
              isExpanded: true,
              items: _allUsers.map((user) {
                final label = user.name != null
                    ? '${user.name} (${user.email})'
                    : user.email;
                return DropdownMenuItem(
                  value: user,
                  child: Text(label, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (v) => setDialogState(() => selectedUser = v),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedUser == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        // Add user with no roles initially - they'll appear in the list
                        // and roles can be toggled via checkboxes
                        _assignRole(selectedUser!.id, _knownRoles.first);
                      },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Role Management')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        tooltip: 'Add user',
        child: const Icon(Icons.person_add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('No roles assigned'))
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  child: ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name ?? user.email,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (user.name != null)
                                Text(
                                  user.email,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              const SizedBox(height: 4),
                              ..._knownRoles.map((role) {
                                final hasRole =
                                    user.roleIds.containsKey(role);
                                return CheckboxListTile(
                                  dense: true,
                                  title: Text(_roleLabels[role] ?? role),
                                  value: hasRole,
                                  onChanged: (checked) {
                                    if (checked == true) {
                                      _assignRole(user.id, role);
                                    } else if (hasRole) {
                                      _removeRole(user.roleIds[role]!);
                                    }
                                  },
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _SimpleUser {
  final String id;
  final String email;
  final String? name;

  _SimpleUser({required this.id, required this.email, this.name});
}

class _UserWithRoles {
  final String id;
  final String email;
  final String? name;
  final Map<String, String> roleIds; // role name -> role record ID

  _UserWithRoles({
    required this.id,
    required this.email,
    this.name,
    required this.roleIds,
  });
}
