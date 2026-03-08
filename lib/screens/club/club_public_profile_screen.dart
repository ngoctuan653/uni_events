import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../services/event_services.dart';
import '../../services/club_services.dart'; // Added for fetching members
import '../event/event_detail_screen.dart';
import 'club_members_screen.dart'; // Added for navigation

class ClubPublicProfileScreen extends StatefulWidget {
  final String clubId;

  const ClubPublicProfileScreen({super.key, required this.clubId});

  @override
  State<ClubPublicProfileScreen> createState() =>
      _ClubPublicProfileScreenState();
}

class _ClubPublicProfileScreenState extends State<ClubPublicProfileScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final EventService _eventService = EventService();
  final ClubService _clubService = ClubService(); // New instance

  Map<String, dynamic>? _clubData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClubData();
  }

  Future<void> _fetchClubData() async {
    final doc = await _db.collection('users').doc(widget.clubId).get();
    if (doc.exists) {
      setState(() {
        _clubData = doc.data();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    final name = _clubData?['name'] ?? 'Unknown Club';
    final avatar = _clubData?['avatar'] as String?;
    final email = _clubData?['email'] ?? '';
    final phone = _clubData?['phone'] ?? '';
    final faculty = _clubData?['faculty'] ?? '';
    final description = _clubData?['description'] ?? '';
    final bio = _clubData?['bio'] ?? '';
    final history = _clubData?['history'] ?? '';
    final introduction = _clubData?['introduction'] ?? '';

    // Generate initials for fallback avatar
    final initials = (name as String)
        .split(' ')
        .where((String w) => w.isNotEmpty)
        .take(2)
        .map((String w) => w[0].toUpperCase())
        .join();

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.orange,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.orange.shade600, Colors.orange.shade400],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),
                      // Avatar
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        backgroundImage: avatar != null && avatar.isNotEmpty
                            ? NetworkImage(avatar)
                            : null,
                        child: avatar == null || avatar.isEmpty
                            ? Text(
                                initials,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (faculty.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            faculty,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      // Member Count Builder
                      StreamBuilder<List<dynamic>>(
                        stream: _clubService.getClubMembers(widget.clubId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox.shrink();
                          }
                          final memberCount = snapshot.data?.length ?? 0;
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClubMembersScreen(
                                    clubId: widget.clubId,
                                    clubName: name,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.people,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$memberCount Members',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact info
                  if (email.isNotEmpty || phone.isNotEmpty) ...[
                    const Text(
                      'CONTACT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          if (email.isNotEmpty)
                            _buildContactRow(Icons.email, email),
                          if (email.isNotEmpty && phone.isNotEmpty)
                            Divider(color: Colors.grey.shade200, height: 20),
                          if (phone.isNotEmpty)
                            _buildContactRow(Icons.phone, phone),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Description
                  if (description.isNotEmpty) ...[
                    const Text(
                      'ABOUT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Bio
                  if (bio.isNotEmpty) ...[
                    Text(
                      '"$bio"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Club History Section
                  if (history.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Lịch sử CLB',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        history,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Club Introduction Section
                  if (introduction.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.description,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Giới thiệu CLB',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        introduction,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Events section
                  const Text(
                    'EVENTS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Events list
          StreamBuilder<List<Event>>(
            stream: _eventService.getEventsByClubId(widget.clubId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: Colors.orange),
                    ),
                  ),
                );
              }

              final events = snapshot.data ?? [];

              if (events.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No events yet',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Split into active (upcoming + ongoing) and past events
              final active = events.where((e) => !e.isPastEvent).toList();
              final past = events.where((e) => e.isPastEvent).toList();

              final combined = <Widget>[];

              if (active.isNotEmpty) {
                combined.add(
                  _buildEventSectionHeader(
                    'Upcoming',
                    Icons.event_available,
                    Colors.orange,
                  ),
                );
                for (var event in active) {
                  combined.add(_buildEventCard(event, false));
                }
              }

              if (past.isNotEmpty) {
                combined.add(const SizedBox(height: 16));
                combined.add(
                  _buildEventSectionHeader(
                    'Past Events',
                    Icons.history,
                    Colors.grey,
                  ),
                );
                for (var event in past) {
                  combined.add(_buildEventCard(event, true));
                }
              }

              combined.add(const SizedBox(height: 40));

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(delegate: SliverChildListDelegate(combined)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildEventSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event, bool isPast) {
    String dateStr = 'TBD';
    if (event.startTime != null) {
      dateStr = DateFormat('MMM dd, yyyy • h:mm a').format(event.startTime!);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPast ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPast ? Colors.grey.shade200 : Colors.orange.shade100,
          ),
        ),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: isPast ? Colors.grey.shade300 : Colors.orange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title.isNotEmpty ? event.title : 'No Title',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isPast ? Colors.grey : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: isPast ? Colors.grey.shade400 : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: isPast
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 12,
                        color: isPast ? Colors.grey.shade400 : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${event.participantCount} participants',
                        style: TextStyle(
                          fontSize: 12,
                          color: isPast
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isPast ? Colors.grey.shade300 : Colors.orange.shade300,
            ),
          ],
        ),
      ),
    );
  }
}
