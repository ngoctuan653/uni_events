import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/checkin_services.dart';
import 'qr_scanner_screen.dart';

/// Screen for managing event check-ins.
///
/// Displays participant list with check-in status, filter tabs,
/// manual check-in buttons, and access to QR scanner.
/// Only accessible by club_staff or club_admin.
class ManageCheckInScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const ManageCheckInScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<ManageCheckInScreen> createState() => _ManageCheckInScreenState();
}

class _ManageCheckInScreenState extends State<ManageCheckInScreen> {
  final CheckInService _checkInService = CheckInService();
  String _filter = 'all'; // 'all', 'checked', 'not_checked'

  Future<void> _handleManualCheckIn(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Manual Check-in'),
        content: Text('Check in "$userName" manually?'),
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
              'Check-in',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _checkInService.manualCheckIn(widget.eventId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userName checked in successfully!'),
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
    }
  }

  Future<void> _handleUndoCheckIn(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Undo Check-in'),
        content: Text('Undo check-in for "$userName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Undo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _checkInService.undoCheckIn(widget.eventId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userName check-in undone'),
            backgroundColor: Colors.orange,
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
    }
  }

  List<Map<String, dynamic>> _applyFilter(
    List<Map<String, dynamic>> participants,
  ) {
    switch (_filter) {
      case 'checked':
        return participants.where((p) => p['isCheckedIn'] == true).toList();
      case 'not_checked':
        return participants.where((p) => p['isCheckedIn'] != true).toList();
      default:
        return participants;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Manage Check-in'), centerTitle: true),
      body: Column(
        children: [
          // Event header with Scan QR button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(bottom: BorderSide(color: Colors.orange.shade100)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.eventTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                // Check-in stats
                StreamBuilder<int>(
                  stream: _checkInService.getCheckInCountStream(widget.eventId),
                  builder: (context, snapshot) {
                    final checkedIn = snapshot.data ?? 0;
                    return Text(
                      'Checked in: $checkedIn',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Scan QR button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QRScannerScreen(
                            eventId: widget.eventId,
                            eventTitle: widget.eventTitle,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Scan QR Check-in',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
              ],
            ),
          ),

          // Filter tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Checked-in', 'checked'),
                const SizedBox(width: 8),
                _buildFilterChip('Not checked', 'not_checked'),
              ],
            ),
          ),

          // Participants list
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _checkInService.getEventParticipantsWithStatus(
                widget.eventId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No participants yet',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final participants = _applyFilter(snapshot.data!);

                if (participants.isEmpty) {
                  return Center(
                    child: Text(
                      _filter == 'checked'
                          ? 'No one has checked in yet'
                          : 'Everyone has checked in!',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final p = participants[index];
                    final isCheckedIn = p['isCheckedIn'] as bool;
                    final name = p['name'] as String;
                    final studentId = p['studentId'] as String;
                    final avatar = p['avatar'];
                    final checkedInAt = p['checkedInAt'] as DateTime?;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCheckedIn
                            ? Colors.green.shade50
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCheckedIn
                              ? Colors.green.shade200
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Status icon
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isCheckedIn
                                  ? Colors.green
                                  : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCheckedIn ? Icons.check : Icons.circle_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Avatar
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.orange.shade100,
                            backgroundImage: avatar != null && avatar.isNotEmpty
                                ? NetworkImage(avatar)
                                : null,
                            child: avatar == null || avatar.isEmpty
                                ? Icon(
                                    Icons.person,
                                    color: Colors.orange.shade700,
                                    size: 20,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),

                          // Name and info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$name${studentId.isNotEmpty ? ' ($studentId)' : ''}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (isCheckedIn && checkedInAt != null)
                                  Text(
                                    DateFormat('h:mm a').format(checkedInAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Check-in or Undo button
                          if (!isCheckedIn)
                            TextButton(
                              onPressed: () => _handleManualCheckIn(
                                p['userId'] as String,
                                name,
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.orange.shade50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Check-in',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          else
                            TextButton(
                              onPressed: () => _handleUndoCheckIn(
                                p['userId'] as String,
                                name,
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.red.shade50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Undo',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
