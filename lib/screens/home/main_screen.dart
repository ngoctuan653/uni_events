import 'package:flutter/material.dart';
import '../event/events_screen.dart';
import '../event/my_events_screen.dart';
import '../admin/admin_dashboard.dart';
import '../admin/manage_users_screen.dart';
import '../profile/profile_screen.dart';
import '../club/club_profile_screen.dart';
import '../club/club_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final String role;

  const HomeScreen({super.key, this.initialIndex = 0, required this.role});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // Build screens based on role
    if (widget.role == 'student') {
      _screens = [
        const EventsScreen(),
        const MyEventsScreen(),
        const ProfileScreen(),
      ];
    } else if (widget.role == 'club') {
      _screens = [
        const EventsScreen(),
        const ClubDashboardScreen(),
        const ClubProfileScreen(),
      ];
    } else if (widget.role == 'admin') {
      _screens = [
        const AdminDashboard(),
        const ManageUsersScreen(),
        const ProfileScreen(),
      ];
    } else {
      // Fallback to student view
      _screens = [
        const EventsScreen(),
        const MyEventsScreen(),
        const ProfileScreen(),
      ];
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  List<BottomNavigationBarItem> _navItems() {
    if (widget.role == "student") {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.event), label: "Events"),
        BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: "My Events"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ];
    } else if (widget.role == "club") {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.event), label: "Events"),
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: "Dashboard",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ];
    } else if (widget.role == "admin") {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: "Dashboard",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.group), label: "Users"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ];
    }

    // Fallback nav items
    return const [
      BottomNavigationBarItem(icon: Icon(Icons.event), label: "Events"),
      BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: "My Events"),
      BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Scaffold bg for Main Screen
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.black54,
          currentIndex: _currentIndex,
          elevation: 0,
          onTap: _onTabTapped,
          items: _navItems(),
        ),
      ),
    );
  }
}
