import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/event.dart';
import '../../services/event_services.dart';
import '../club/club_public_profile_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final EventService _eventService = EventService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isProcessing = false;

  // Club/organizer data
  String _clubName = '';
  String? _clubAvatar;
  bool _clubLoaded = false;

  @override
  void initState() {
    super.initState();
    _fetchClubData();
  }

  Future<void> _fetchClubData() async {
    final clubId = widget.event.clubId.isNotEmpty
        ? widget.event.clubId
        : widget.event.createdBy;
    if (clubId.isEmpty) return;

    final doc = await _db.collection('users').doc(clubId).get();
    if (doc.exists && mounted) {
      setState(() {
        _clubName = doc.data()?['name'] ?? 'Unknown Club';
        _clubAvatar = doc.data()?['avatar'];
        _clubLoaded = true;
      });
    }
  }

  Future<void> _handleRegister() async {
    // Step 1: Check for time conflicts
    final conflicting = await _eventService.getConflictingEvent(widget.event);
    if (conflicting != null && mounted) {
      String conflictTimeStr = '';
      if (conflicting.startTime != null) {
        conflictTimeStr = DateFormat(
          'MMM dd, h:mm a',
        ).format(conflicting.startTime!);
      }

      final continueAnyway = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 28,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Time Conflict',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You already registered another event at this time:',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conflicting.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            conflictTimeStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Do you still want to join?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (continueAnyway != true) return;
    }

    // Step 2: Show confirmation dialog
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Registration',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'By registering for this event, you confirm that:',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            _buildConfirmItem('You will attend the event on time'),
            const SizedBox(height: 8),
            _buildConfirmItem(
              'You agree to follow the event\'s rules and regulations',
            ),
            const SizedBox(height: 8),
            _buildConfirmItem(
              'You understand your spot may be given to others if you do not attend',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Yes, Register',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await _eventService.registerForEvent(widget.event.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully registered for ${widget.event.title}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleUnregister() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Registration'),
        content: const Text(
          'Are you sure you want to unregister from this event?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Yes, Unregister',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await _eventService.unregisterFromEvent(widget.event.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have been unregistered from this event.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unregister: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    String imageUrl = event.image.isNotEmpty
        ? event.image
        : 'https://images.unsplash.com/photo-1540575467063-112007325fb1?q=80&w=2600&auto=format&fit=crop';

    String dateStr = 'TBD';
    String timeStr = 'TBD';
    String endTimeStr = '';
    if (event.startTime != null) {
      dateStr = DateFormat('EEEE, MMM dd, yyyy').format(event.startTime!);
      timeStr = DateFormat('h:mm a').format(event.startTime!);
    }
    if (event.endTime != null) {
      endTimeStr = ' - ${DateFormat('h:mm a').format(event.endTime!)}';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            floating: false,
            pinned: true,
            iconTheme: const IconThemeData(color: Colors.white),
            backgroundColor: Colors.orange,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(imageUrl, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Text(
                      event.title.isNotEmpty ? event.title : 'No Title',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Organizer card
                  if (_clubLoaded)
                    GestureDetector(
                      onTap: () {
                        final clubId = widget.event.clubId.isNotEmpty
                            ? widget.event.clubId
                            : widget.event.createdBy;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ClubPublicProfileScreen(clubId: clubId),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.orange.shade100,
                              backgroundImage:
                                  _clubAvatar != null && _clubAvatar!.isNotEmpty
                                  ? NetworkImage(_clubAvatar!)
                                  : null,
                              child: _clubAvatar == null || _clubAvatar!.isEmpty
                                  ? Icon(
                                      Icons.groups,
                                      color: Colors.orange.shade700,
                                      size: 22,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Organized by',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _clubName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // About Section
                  const Text(
                    'About this Event',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event.description.isNotEmpty
                        ? event.description
                        : 'No description available for this event.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),

                  // Note section
                  if (event.note.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade100),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.note_alt_outlined,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              event.note,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange.shade900,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Info Tiles
                  _buildInfoTile(
                    icon: Icons.calendar_today,
                    title: 'Date',
                    subtitle: dateStr,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoTile(
                    icon: Icons.access_time,
                    title: 'Time',
                    subtitle: '$timeStr$endTimeStr',
                  ),
                  const SizedBox(height: 16),
                  _buildInfoTile(
                    icon: Icons.location_on,
                    title: 'Location',
                    subtitle: event.location.isNotEmpty
                        ? event.location
                        : 'TBD',
                  ),
                  const SizedBox(height: 16),

                  // Live participant count
                  StreamBuilder<int>(
                    stream: _eventService.getParticipantCountStream(event.id),
                    builder: (context, snapshot) {
                      int count = snapshot.data ?? event.participantCount;
                      return _buildInfoTile(
                        icon: Icons.people,
                        title: 'Participants',
                        subtitle: event.capacity > 0
                            ? '$count / ${event.capacity} registered'
                            : '$count registered',
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Register / Unregister Button (live state)
                  StreamBuilder<bool>(
                    stream: _eventService.isRegisteredStream(event.id),
                    builder: (context, snapshot) {
                      final isRegistered = snapshot.data ?? false;

                      if (isRegistered) {
                        // Already registered — show status + unregister option
                        return Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade700,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'You are registered!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed: _isProcessing
                                    ? null
                                    : _handleUnregister,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.red.shade200),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isProcessing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.red,
                                        ),
                                      )
                                    : const Text(
                                        'Cancel Registration',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Not registered — show register button
                        return SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _handleRegister,
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.event_available,
                                    color: Colors.white,
                                  ),
                            label: Text(
                              _isProcessing
                                  ? 'Registering...'
                                  : 'Register for Event',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.orange, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, size: 18, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
