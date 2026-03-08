import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/event.dart';
import '../../services/event_services.dart';
import '../../services/club_services.dart';
import 'event_detail_screen.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  final EventService _eventService = EventService();
  final ClubService _clubService = ClubService();
  List<String> _staffClubIds = [];
  bool _staffLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStaffClubs();
  }

  Future<void> _loadStaffClubs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final memberships = await _clubService.getUserClubMemberships(user.uid);
    print('Staff memberships found: ${memberships.length}');
    for (var m in memberships) {
      print('  clubId: ${m.clubId}, role: ${m.role}');
    }
    if (mounted) {
      setState(() {
        _staffClubIds = memberships.map((m) => m.clubId).toList();
        _staffLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Events',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<Event>>(
        stream: _eventService.getRegisteredEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Error loading events',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final events = snapshot.data ?? [];

          if (events.isEmpty && _staffClubIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No registered events yet',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Events you register for will appear here',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          // Split into upcoming (including ongoing) and past events
          final upcoming = events.where((e) => !e.isPastEvent).toList();
          final past = events.where((e) => e.isPastEvent).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Club Events section for staff
              if (_staffClubIds.isNotEmpty) ...[
                _buildSectionHeader(
                  'Club Events (Staff)',
                  Icons.groups,
                  Colors.blue,
                ),
                const SizedBox(height: 12),
                ..._staffClubIds.map((clubId) {
                  return StreamBuilder<List<Event>>(
                    stream: _eventService.getEventsByClubId(clubId),
                    builder: (context, clubSnapshot) {
                      if (!clubSnapshot.hasData || clubSnapshot.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        children: clubSnapshot.data!
                            .map(
                              (e) => _buildEventCard(
                                e,
                                e.isPastEvent,
                                isStaff: true,
                              ),
                            )
                            .toList(),
                      );
                    },
                  );
                }),
                const SizedBox(height: 24),
              ],

              if (upcoming.isNotEmpty) ...[
                _buildSectionHeader(
                  'Upcoming',
                  Icons.event_available,
                  Colors.orange,
                ),
                const SizedBox(height: 12),
                ...upcoming.map((event) => _buildEventCard(event, false)),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSectionHeader('Past Events', Icons.history, Colors.grey),
                const SizedBox(height: 12),
                ...past.map((event) => _buildEventCard(event, true)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(Event event, bool isPast, {bool isStaff = false}) {
    String dateStr = 'TBD';
    String timeStr = 'TBD';
    if (event.startTime != null) {
      dateStr = DateFormat('MMM dd, yyyy').format(event.startTime!);
      timeStr = DateFormat('h:mm a').format(event.startTime!);
    }

    String imageUrl = event.image.isNotEmpty
        ? event.image
        : 'https://images.unsplash.com/photo-1540575467063-112007325fb1?q=80&w=2600&auto=format&fit=crop';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(event: event),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isPast ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPast ? Colors.grey.shade200 : Colors.orange.shade100,
          ),
          boxShadow: isPast
              ? []
              : [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Event image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 100,
                height: 110,
                child: ColorFiltered(
                  colorFilter: isPast
                      ? const ColorFilter.mode(
                          Colors.grey,
                          BlendMode.saturation,
                        )
                      : const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.multiply,
                        ),
                  child: Image.network(imageUrl, fit: BoxFit.cover),
                ),
              ),
            ),
            // Event details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isPast
                            ? Colors.grey.shade200
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPast ? 'Attended' : 'Registered',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPast
                              ? Colors.grey.shade600
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Title
                    Text(
                      event.title.isNotEmpty ? event.title : 'No Title',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isPast ? Colors.grey : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Date & time
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: isPast ? Colors.grey.shade400 : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$dateStr • $timeStr',
                          style: TextStyle(
                            fontSize: 12,
                            color: isPast
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Location
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: isPast ? Colors.grey.shade400 : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location.isNotEmpty ? event.location : 'TBD',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isPast
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Arrow
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right,
                color: isPast ? Colors.grey.shade300 : Colors.orange.shade300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
