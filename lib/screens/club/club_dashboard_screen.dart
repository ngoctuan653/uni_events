import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/event_services.dart';
import '../../models/event.dart';
import '../event/create_edit_event_screen.dart';
import '../event/event_detail_screen.dart';
import 'manage_staff_screen.dart';

class ClubDashboardScreen extends StatelessWidget {
  const ClubDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final EventService eventService = EventService();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Club Dashboard',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            // Header Info from Firestore
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .snapshots(),
              builder: (context, snapshot) {
                String clubName = 'Unknown Club';
                String? avatarUrl;

                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  clubName = data['name'] ?? 'Unknown Club';
                  avatarUrl = data['avatar'];
                }

                return Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade200),
                        image: avatarUrl != null && avatarUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(avatarUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? const Icon(
                              Icons.hub,
                              color: Colors.orange,
                              size: 30,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clubName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Organizer Dashboard',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // StreamBuilder for active events count could go here, for now static visual
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Active Events',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // Manage Staff button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  String clubName = 'My Club';
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    clubName = data['name'] ?? 'My Club';
                  }
                  return OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ManageStaffScreen(
                            clubId: userId,
                            clubName: clubName,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.group_add, color: Colors.orange.shade700),
                    label: Text(
                      'Manage Staff',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.orange.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 30),

            // Managed Events Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Managed Events',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'View Past',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Events List
            Expanded(
              child: StreamBuilder<List<Event>>(
                stream: eventService.getManagedEvents(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        'No events managing yet.\nTap + to create one!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: snapshot.data!.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      Event event = snapshot.data![index];
                      String eventId = event.id;

                      String title = event.title.isNotEmpty
                          ? event.title
                          : 'No Title';
                      DateTime? startTime = event.startTime;
                      int participants = event.participantCount;

                      String dateStr = 'TBD';
                      if (startTime != null) {
                        // Simple format for now
                        DateTime dt = startTime;
                        dateStr =
                            '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                      }
                      bool isPast =
                          event.endTime != null &&
                          event.endTime!.isBefore(DateTime.now());
                      bool isInactive = event.status == 'inactive';
                      bool isGrayedOut = isPast || isInactive;

                      return InkWell(
                        onTap: () {
                          // Navigate to Event details
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventDetailScreen(event: event),
                            ),
                          );
                        },
                        child: Opacity(
                          opacity: isGrayedOut ? 0.6 : 1.0,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isGrayedOut
                                  ? Colors.grey.shade50
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: isGrayedOut
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Row(
                              children: [
                                // Event Banner/Image
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                    image: event.image.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(event.image),
                                            fit: BoxFit.cover,
                                            colorFilter: isGrayedOut
                                                ? const ColorFilter.mode(
                                                    Colors.grey,
                                                    BlendMode.saturation,
                                                  )
                                                : null,
                                          )
                                        : null,
                                  ),
                                  child: event.image.isEmpty
                                      ? const Icon(
                                          Icons.event,
                                          color: Colors.grey,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),

                                // Event Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.people,
                                            size: 16,
                                            color: Colors.blue.shade400,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$participants participants',
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Actions
                                Column(
                                  children: [
                                    // We remove Inkwell on Edit since entire row is clickable?
                                    // Wait, they still might want to edit directly. Let's keep Edit button separate.
                                    InkWell(
                                      onTap: () {
                                        // Navigate to Edit screen
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                CreateEditEventScreen(
                                                  eventId: eventId,
                                                ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          size: 18,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () async {
                                        // Confirm Delete
                                        bool? confirm = await showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Event'),
                                            content: const Text(
                                              'Are you sure you want to delete this event?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await eventService.deleteEvent(
                                            eventId,
                                          );
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.delete,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateEditEventScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}
