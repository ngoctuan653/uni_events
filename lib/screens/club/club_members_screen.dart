import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/club_member_model.dart';
import '../../services/club_services.dart';
import '../profile/public_user_profile_screen.dart';

class ClubMembersScreen extends StatelessWidget {
  final String clubId;
  final String clubName;

  const ClubMembersScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context) {
    final ClubService _clubService = ClubService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '$clubName Members',
          style: const TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<List<ClubMemberModel>>(
        stream: _clubService.getClubMembers(clubId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading members: ${snapshot.error}'),
            );
          }

          final members = snapshot.data ?? [];

          if (members.isEmpty) {
            return const Center(
              child: Text(
                'No members found.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final roleLabel = member.role == 'leader'
                  ? 'Leader'
                  : member.role == 'staff'
                  ? 'Staff'
                  : 'Member';

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(member.userId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text('Loading user...'),
                    );
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  final name = userData['name'] ?? 'Unknown User';
                  final avatar = userData['avatar'] as String?;
                  final studentId = userData['studentId'] ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      backgroundImage: (avatar != null && avatar.isNotEmpty)
                          ? NetworkImage(avatar)
                          : null,
                      child: (avatar == null || avatar.isEmpty)
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(color: Colors.orange.shade800),
                            )
                          : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(studentId),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: roleLabel == 'Leader'
                            ? Colors.red.shade100
                            : roleLabel == 'Staff'
                            ? Colors.blue.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: roleLabel == 'Leader'
                              ? Colors.red.shade800
                              : roleLabel == 'Staff'
                              ? Colors.blue.shade800
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PublicUserProfileScreen(userId: member.userId),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
