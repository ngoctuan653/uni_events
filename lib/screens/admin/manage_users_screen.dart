import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;

  void _onSearchChanged(String query) async {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
    });

    if (_searchQuery.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // Create a basic prefix search on email (assuming emails are stored lowercase)
      // "array-contains", "==" are standard. Prefix search requires '>=' and '<=' hack or string matching on client side.
      // Easiest is to fetch students and clubs, then filter in Dart if dataset is small, or use a specific index.
      // Since University apps rarely have >10,000 users, filtering top 50 matches client-side is mostly fine.

      final querySnapshot = await _db.collection('users').get();

      final filteredDocs = querySnapshot.docs.where((doc) {
        final data = doc.data();
        final email = (data['email'] ?? '').toString().toLowerCase();
        final name = (data['name'] ?? '').toString().toLowerCase();
        final studentId = (data['studentId'] ?? '').toString().toLowerCase();

        return email.contains(_searchQuery) ||
            name.contains(_searchQuery) ||
            studentId.contains(_searchQuery);
      }).toList();

      if (mounted) {
        setState(() {
          _searchResults = filteredDocs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error searching users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateUserRole(DocumentSnapshot userDoc, String newRole) async {
    final data = userDoc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'User';
    final currentRole = data['role'] ?? 'student';

    if (currentRole == newRole) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name is already a $newRole.')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Role'),
        content: Text(
          'Are you sure you want to change $name\'s role to $newRole?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _db.collection('users').doc(userDoc.id).update({'role': newRole});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully updated $name to $newRole.')),
          );
          // Refresh search to show new role
          _onSearchChanged(_searchController.text);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to update role.')));
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Manage Roles',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search Users',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or student ID...',
                prefixIcon: const Icon(Icons.search, color: Colors.orange),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(child: _buildSearchResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Find users to manage their roles.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No users found for "$_searchQuery".',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final doc = _searchResults[index];
        final data = doc.data() as Map<String, dynamic>;

        final name = data['name'] ?? 'Unknown User';
        final email = data['email'] ?? 'No email';
        final role = data['role'] ?? 'student';
        final avatar = data['avatar'] as String?;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: CircleAvatar(
            backgroundColor: Colors.orange.shade100,
            backgroundImage: (avatar != null && avatar.isNotEmpty)
                ? NetworkImage(avatar)
                : null,
            child: (avatar == null || avatar.isEmpty)
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                email,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: role == 'club'
                      ? Colors.blue.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: role == 'club'
                        ? Colors.blue.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: role == 'club'
                        ? Colors.blue.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (newRole) => _updateUserRole(doc, newRole),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'student',
                child: Text('Set as Student'),
              ),
              const PopupMenuItem<String>(
                value: 'club',
                child: Text('Set as Club Admin'),
              ),
              const PopupMenuItem<String>(
                value: 'admin',
                child: Text(
                  'Set as System Admin',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
