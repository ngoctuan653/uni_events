import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final String clubId;
  final String location;
  final DateTime? startTime;
  final DateTime? endTime;
  final int capacity;
  final int participantCount;
  final String image;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String status;
  final String note;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.clubId,
    required this.location,
    this.startTime,
    this.endTime,
    required this.capacity,
    required this.participantCount,
    required this.image,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
    required this.status,
    this.note = '',
  });

  factory Event.fromFirestore(Map<String, dynamic> data, String id) {
    return Event(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      clubId: data['clubId'] ?? '',
      location: data['location'] ?? '',
      startTime: data['startTime'] != null
          ? (data['startTime'] as Timestamp).toDate()
          : null,
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      capacity: data['capacity'] ?? 0,
      participantCount: data['participantCount'] ?? 0,
      image: data['image'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      status: data['status'] ?? 'draft',
      note: data['note'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'clubId': clubId,
      'location': location,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'capacity': capacity,
      'participantCount': participantCount,
      'image': image,
      'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'status': status,
      'note': note,
    };
  }

  /// Check if the event has ended (past event)
  bool get isPastEvent {
    if (endTime != null) {
      return endTime!.isBefore(DateTime.now());
    }
    // If no endTime, check startTime
    if (startTime != null) {
      // Consider event ended if it started more than 3 hours ago
      return startTime!.add(const Duration(hours: 3)).isBefore(DateTime.now());
    }
    return false;
  }

  /// Check if the event is currently ongoing
  bool get isOngoing {
    final now = DateTime.now();
    if (startTime != null && endTime != null) {
      return now.isAfter(startTime!) && now.isBefore(endTime!);
    }
    return false;
  }

  /// Check if the event is upcoming (not started yet)
  bool get isUpcoming {
    if (startTime != null) {
      return startTime!.isAfter(DateTime.now());
    }
    return true; // If no startTime, consider it upcoming
  }
}
