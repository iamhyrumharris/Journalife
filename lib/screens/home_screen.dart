import 'package:flutter/material.dart';
import '../services/error_service.dart';
import 'calendar/calendar_screen.dart';
import 'timeline/timeline_screen.dart';
import 'reflect/reflect_screen.dart';
import 'map/map_screen.dart';
import 'attachments/attachments_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = [
    const CalendarScreen(),
    const TimelineScreen(),
    const ReflectScreen(),
    const MapScreen(),
    const AttachmentsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        physics: const NeverScrollableScrollPhysics(), // Disable swipe navigation
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.calendar_today,
              semanticLabel: 'Calendar view',
            ),
            label: 'Calendar',
            tooltip: 'View calendar and entries by date',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.timeline,
              semanticLabel: 'Timeline view',
            ),
            label: 'Timeline',
            tooltip: 'View chronological timeline of entries',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.book,
              semanticLabel: 'Reflect view',
            ),
            label: 'Reflect',
            tooltip: 'View statistics and reflection insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.map,
              semanticLabel: 'Map view',
            ),
            label: 'Map',
            tooltip: 'View entries with location on map',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.attachment,
              semanticLabel: 'Attachments view',
            ),
            label: 'Attachments',
            tooltip: 'View media and file attachments',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_create_entry_fab',
        onPressed: () {
          ErrorService.addBreadcrumb('User tapped create entry button');
          Navigator.pushNamed(context, '/entry/create');
        },
        tooltip: 'Create new journal entry',
        child: const Icon(
          Icons.add,
          semanticLabel: 'Add new entry',
        ),
      ),
    );
  }
}