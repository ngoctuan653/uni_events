import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../event/event_detail_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Admin Event Dashboard',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('events')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final events = snapshot.data!.docs.map((doc) {
            return Event.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: events.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final event = events[index];
              return _buildEventItem(event);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No Events Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There are currently no events in the system.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(Event event) {
    final bool isPastOrInactive =
        event.isPastEvent || event.status == 'inactive';

    String dateStr = 'TBD';
    if (event.startTime != null) {
      dateStr = DateFormat('MMM dd, yyyy • h:mm a').format(event.startTime!);
    }

    Widget eventContent = Container(
      decoration: BoxDecoration(
        color: isPastOrInactive ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPastOrInactive ? Colors.grey.shade200 : Colors.grey.shade100,
        ),
        boxShadow: isPastOrInactive
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Banner
          Container(
            width: 100,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              color: Colors.grey.shade200,
              image: event.image.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(event.image),
                      fit: BoxFit.cover,
                      colorFilter: isPastOrInactive
                          ? const ColorFilter.mode(
                              Colors.grey,
                              BlendMode.saturation,
                            )
                          : null,
                    )
                  : null,
            ),
            child: event.image.isEmpty
                ? const Icon(Icons.event, color: Colors.grey, size: 40)
                : null,
          ),

          // Event Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isPastOrInactive
                                ? Colors.grey.shade600
                                : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: event.status == 'active' && !event.isPastEvent
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          event.isPastEvent
                              ? 'Past'
                              : event.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color:
                                event.status == 'active' && !event.isPastEvent
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: isPastOrInactive
                            ? Colors.grey.shade400
                            : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: isPastOrInactive
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: isPastOrInactive
                            ? Colors.grey.shade400
                            : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.location,
                          style: TextStyle(
                            fontSize: 12,
                            color: isPastOrInactive
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 14,
                        color: isPastOrInactive
                            ? Colors.grey.shade400
                            : Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${event.participantCount} / ${event.capacity} participants',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isPastOrInactive
                              ? Colors.grey.shade500
                              : Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (isPastOrInactive) {
      eventContent = Opacity(opacity: 0.6, child: eventContent);
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: eventContent,
    );
  }
}
