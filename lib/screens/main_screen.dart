import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dietingapp2026/database_service.dart';
import 'package:dietingapp2026/screens/home_screen.dart';
import 'package:dietingapp2026/screens/more_screen.dart';
import 'package:dietingapp2026/screens/log_screen.dart';
import 'package:dietingapp2026/screens/static/app_icons.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<String> _titles = ['Home', 'Log', 'More'];
  final PageController _pageController = PageController();
  int _selectedIndex = 0;

  // Date selected on the Home tab — drives the progress bar date.
  DateTime _selectedDate = _today();
  // Date selected on the Log tab — persisted across tab switches.
  DateTime _logDate = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    // Warm the cache with recent food logs + daily summaries in the background
    // so past days load instantly. Fire-and-forget — never blocks the UI.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      unawaited(DatabaseService.preloadFoodLogs(uid));
      unawaited(DatabaseService.preloadDailySummaries(uid));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDateChanged(DateTime date) => setState(() => _selectedDate = date);
  void _onLogDateChanged(DateTime date) => setState(() => _logDate = date);

  // Tapping a tab animates the PageView; the page itself is kept alive so it
  // only fetches on its first visit, not on every switch.
  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
    );
  }

  void _onPageChanged(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(_titles[_selectedIndex]),
        automaticallyImplyLeading: false,
      ),
      // PageView builds each page lazily on first visit; AutomaticKeepAlive on
      // each screen keeps it mounted afterwards so revisiting never refetches.
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [
          HomeScreen(selectedDate: _selectedDate, onDateChanged: _onDateChanged),
          LogScreen(logDate: _logDate, onLogDateChanged: _onLogDateChanged),
          const MoreScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline),
            activeIcon: Icon(Icons.bookmark),
            label: 'Log',
          ),
          BottomNavigationBarItem(
            icon: SizedBox(
              height: 24,
              child: ThreeDotsIcon(style: DotStyle.outlined),
            ),
            activeIcon: SizedBox(
              height: 24,
              child: ThreeDotsIcon(style: DotStyle.filled),
            ),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
