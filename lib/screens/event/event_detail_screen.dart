import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/event.dart';
import '../../services/event_services.dart';
import '../../services/club_services.dart';
import '../club/club_public_profile_screen.dart';
import 'qr_display_screen.dart';
import 'manage_checkin_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final EventService _eventService = EventService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isProcessing = false;

  // Club/organizer data
  String _clubName = '';
  String? _clubAvatar;
  bool _clubLoaded = false;

  // User role
  String _userRole = 'student';

  // Staff/admin check for manage check-in
  bool _isStaffOrAdmin = false;
  final ClubService _clubService = ClubService();

  @override
  void initState() {
    super.initState();
    _fetchClubData();
    _fetchUserRole();
    _checkStaffStatus();
  }

  Future<void> _checkStaffStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final clubId = widget.event.clubId.isNotEmpty
        ? widget.event.clubId
        : widget.event.createdBy;
    if (clubId.isEmpty) return;
    final isStaff = await _clubService.isStaffOrAdmin(user.uid, clubId);
    if (mounted) {
      setState(() => _isStaffOrAdmin = isStaff);
    }
  }

  Future<void> _fetchUserRole() async {
    User? user = _auth.currentUser;
    if (user != null) {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userRole = doc.data()?['role'] ?? 'student';
        });
      }
    }
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

                  // Countdown Timer
                  if (event.startTime != null &&
                      event.startTime!.isAfter(DateTime.now()))
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Event starts in',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _getCountdown(event.startTime!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),

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

                  const SizedBox(height: 32),

                  // Participants List Section
                  const Text(
                    'Participants',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: _db
                        .collection('registrations')
                        .where('eventId', isEqualTo: event.id)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final registrations = snapshot.data!.docs;
                      if (registrations.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Center(
                            child: Text(
                              'No participants yet',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: registrations.map((regDoc) {
                          final userId = regDoc['userId'] as String;
                          return FutureBuilder<DocumentSnapshot>(
                            future: _db.collection('users').doc(userId).get(),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) {
                                return const SizedBox.shrink();
                              }

                              final userData =
                                  userSnapshot.data!.data()
                                      as Map<String, dynamic>?;
                              final userName =
                                  userData?['name'] ?? 'Unknown User';
                              final userEmail = userData?['email'] ?? '';
                              final userAvatar = userData?['avatar'];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.orange.shade100,
                                      backgroundImage:
                                          userAvatar != null &&
                                              userAvatar.isNotEmpty
                                          ? NetworkImage(userAvatar)
                                          : null,
                                      child:
                                          userAvatar == null ||
                                              userAvatar.isEmpty
                                          ? Icon(
                                              Icons.person,
                                              color: Colors.orange.shade700,
                                              size: 24,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userName,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          if (userEmail.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              userEmail,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Manage Check-in button (for staff/admin only)
                  if (_isStaffOrAdmin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ManageCheckInScreen(
                                  eventId: event.id,
                                  eventTitle: event.title,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.qr_code_scanner,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Manage Check-in',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Register / Unregister Button (live state) - Only for students, NOT staff of this club
                  if (_userRole == 'student' && !_isStaffOrAdmin)
                    StreamBuilder<bool>(
                      stream: _eventService.isRegisteredStream(event.id),
                      builder: (context, snapshot) {
                        final isRegistered = snapshot.data ?? false;

                        if (isRegistered) {
                          // Already registered — show status + QR + unregister
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
                              // View My QR Code button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    // Get registration ID for QR
                                    final user = _auth.currentUser;
                                    if (user == null) return;
                                    final regSnapshot = await _db
                                        .collection('registrations')
                                        .where('eventId', isEqualTo: event.id)
                                        .where('userId', isEqualTo: user.uid)
                                        .limit(1)
                                        .get();
                                    if (regSnapshot.docs.isNotEmpty &&
                                        mounted) {
                                      final regId = regSnapshot.docs.first.id;
                                      final userData = await _db
                                          .collection('users')
                                          .doc(user.uid)
                                          .get();
                                      final studentName =
                                          userData.data()?['name'] ?? 'Student';
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => QRDisplayScreen(
                                            registrationId: regId,
                                            eventTitle: event.title,
                                            studentName: studentName,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.qr_code,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'View My QR Code',
                                    style: TextStyle(
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
                                    side: BorderSide(
                                      color: Colors.red.shade200,
                                    ),
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

  String _getCountdown(DateTime eventTime) {
    final now = DateTime.now();
    final difference = eventTime.difference(now);

    if (difference.isNegative) {
      return 'Event has started';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    if (days > 30) {
      final months = (days / 30).floor();
      final remainingDays = days % 30;
      return '$months ${months == 1 ? 'month' : 'months'} ${remainingDays > 0 ? '$remainingDays ${remainingDays == 1 ? 'day' : 'days'}' : ''}';
    } else if (days > 7) {
      final weeks = (days / 7).floor();
      final remainingDays = days % 7;
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ${remainingDays > 0 ? '$remainingDays ${remainingDays == 1 ? 'day' : 'days'}' : ''}';
    } else if (days > 0) {
      return '$days ${days == 1 ? 'day' : 'days'} $hours ${hours == 1 ? 'hour' : 'hours'}';
    } else if (hours > 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'} $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    } else {
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }
  }
}
