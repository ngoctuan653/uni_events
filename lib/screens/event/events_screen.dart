import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/event_services.dart';
import '../../services/notification_services.dart';
import '../../models/event.dart';
import 'event_detail_screen.dart';
import 'all_events_screen.dart';
import '../notification/notifications_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final EventService _eventService = EventService();
  final NotificationService _notificationService = NotificationService();
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Academic',
    'Social',
    'Sports',
    'Career',
    'Music',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Light background matching UI
      body: SafeArea(
        child: StreamBuilder<List<Event>>(
          stream: _eventService.getAllEvents(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            List<Event> allEvents = snapshot.data ?? [];

            // Filter out past events for featured section
            List<Event> activeEvents = allEvents
                .where((event) => !event.isPastEvent)
                .toList();

            // Sort active events by participant count (highest first)
            activeEvents.sort(
              (a, b) => b.participantCount.compareTo(a.participantCount),
            );
            // Show active events in featured section
            List<Event> featuredEvents = activeEvents;

            // Sort upcoming events by start time (nearest first)
            // Include ongoing events but exclude past events
            List<Event> upcomingEvents = activeEvents
                .where((event) => event.isUpcoming || event.isOngoing)
                .toList();
            upcomingEvents.sort((a, b) {
              if (a.startTime == null && b.startTime == null) return 0;
              if (a.startTime == null) return 1;
              if (b.startTime == null) return -1;
              return a.startTime!.compareTo(b.startTime!);
            });

            return CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildSearchBar(),
                        const SizedBox(height: 30),
                        _buildSectionHeader(
                          'Featured Events',
                          'See all',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AllEventsScreen(
                                  events: featuredEvents,
                                  title: 'Featured Events',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildFeaturedEvents(featuredEvents),
                        const SizedBox(height: 30),
                        _buildCategories(),
                        const SizedBox(height: 20),
                        const Text(
                          'Upcoming Events',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                _buildUpcomingEvents(upcomingEvents),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverPadding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
      sliver: SliverToBoxAdapter(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Campus Events',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
              child: StreamBuilder<int>(
                stream: _notificationService.getUnreadCount(),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data ?? 0;
                  return Stack(
                    children: [
                      const Icon(
                        Icons.notifications_none,
                        color: Colors.black54,
                        size: 28,
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 12),
          const Expanded(
            child: TextField(
              style: TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search events, clubs, or tags...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.grey),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String action, {
    VoidCallback? onTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedEvents(List<Event> events) {
    if (events.isEmpty) {
      return const Text(
        'No featured events',
        style: TextStyle(color: Colors.grey),
      );
    }

    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: events.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final event = events[index];
          // Determine tags or images randomly for UI demonstration
          List<String> tags = ['CAREER', 'MUSIC', 'ACADEMIC'];
          List<Color> tagColors = [Colors.blue, Colors.purple, Colors.orange];
          String tag = tags[index % tags.length];
          Color tagColor = tagColors[index % tagColors.length];

          String imageUrl = event.image.isNotEmpty
              ? event.image
              : 'https://images.unsplash.com/photo-1540575467063-112007325fb1?q=80&w=2600&auto=format&fit=crop';

          if (index % 2 != 0 && event.image.isEmpty) {
            imageUrl =
                'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?q=80&w=2600&auto=format&fit=crop';
          }

          String dateStr = 'TBD';
          if (event.startTime != null) {
            dateStr = DateFormat('MMM dd').format(event.startTime!);
          }

          return SizedBox(
            width: 260,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventDetailScreen(event: event),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Participant count
                          Positioned(
                            top: 12,
                            right: 12,
                            child: _buildParticipantBadge(event),
                          ),
                          // Category Tag
                          Positioned(
                            bottom: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: tagColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event.title.isNotEmpty ? event.title : 'No Title',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.grey,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$dateStr • ${event.location.isNotEmpty ? event.location : 'TBD'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategories() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((category) {
          bool isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildParticipantIcon(Event event) {
    // Check if event is hot (>= 40% capacity)
    final isHot =
        event.capacity > 0 && (event.participantCount / event.capacity) >= 0.4;

    if (isHot) {
      return const _HotIcon();
    }

    return const Icon(Icons.people, color: Colors.black87, size: 14);
  }

  Widget _buildParticipantBadge(Event event) {
    // Check if event is hot (>= 40% capacity)
    final isHot =
        event.capacity > 0 && (event.participantCount / event.capacity) >= 0.4;

    if (isHot) {
      return _HotBadge(participantCount: event.participantCount);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildParticipantIcon(event),
          const SizedBox(width: 4),
          Text(
            '${event.participantCount}+',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEvents(List<Event> events) {
    if (events.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Text(
            'No upcoming events',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final event = events[index];
          DateTime? startTime = event.startTime;
          String month = 'TBD';
          String day = '--';
          String timeStr = 'TBD';

          if (startTime != null) {
            month = DateFormat('MMM').format(startTime).toUpperCase();
            day = DateFormat('dd').format(startTime);
            timeStr = DateFormat('h:mm a').format(startTime);
          }

          String imageUrl = event.image.isNotEmpty
              ? event.image
              : 'https://images.unsplash.com/photo-1540575467063-112007325fb1?q=80&w=2600&auto=format&fit=crop';

          if (index % 2 != 0 && event.image.isEmpty) {
            imageUrl =
                'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?q=80&w=2600&auto=format&fit=crop';
          }

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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Image
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        Image.network(
                          imageUrl,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        // Date badge overlay
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  month,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  day,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Event Details
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title.isNotEmpty ? event.title : 'No Title',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                event.location.isNotEmpty
                                    ? event.location
                                    : 'Location TBD',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                timeStr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.people,
                              color: Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${event.participantCount}',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }, childCount: events.length),
      ),
    );
  }
}

class _HotIcon extends StatefulWidget {
  const _HotIcon();

  @override
  State<_HotIcon> createState() => _HotIconState();
}

class _HotIconState extends State<_HotIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _colorAnimation = ColorTween(
      begin: Colors.orange,
      end: Colors.red,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Icon(
            Icons.local_fire_department,
            color: _colorAnimation.value,
            size: 14,
          ),
        );
      },
    );
  }
}

class _HotBadge extends StatefulWidget {
  final int participantCount;

  const _HotBadge({required this.participantCount});

  @override
  State<_HotBadge> createState() => _HotBadgeState();
}

class _HotBadgeState extends State<_HotBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _bgColorAnimation;
  late Animation<Color?> _textColorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _bgColorAnimation = ColorTween(
      begin: Colors.orange.shade100.withValues(alpha: 0.9),
      end: Colors.red.shade100.withValues(alpha: 0.9),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _textColorAnimation = ColorTween(
      begin: Colors.orange.shade900,
      end: Colors.red.shade900,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _bgColorAnimation.value,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: (_bgColorAnimation.value ?? Colors.orange).withValues(
                  alpha: 0.4,
                ),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _HotIcon(),
              const SizedBox(width: 4),
              Text(
                '${widget.participantCount}+',
                style: TextStyle(
                  color: _textColorAnimation.value,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
