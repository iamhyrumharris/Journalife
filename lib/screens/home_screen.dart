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

  final List<Widget> _screens = [
    const CalendarScreen(),
    const TimelineScreen(),
    const ReflectScreen(),
    const MapScreen(),
    const AttachmentsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline),
            label: 'Timeline',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Reflect',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attachment),
            label: 'Attachments',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ErrorService.addBreadcrumb('User tapped create entry button');
          Navigator.pushNamed(context, '/entry/create');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}