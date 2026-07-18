import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'analyze_call_screen.dart';
import 'history_screen.dart';
import 'app_theme.dart';
import 'call_detection_service_enhanced.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SentiCare',
      theme: AppTheme.theme,
      home: const RootNav(),
    );
  }
}

class RootNav extends StatefulWidget {
  const RootNav({super.key});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initCallDetection();
  }

  Future<void> _initCallDetection() async {
    final service = CallDetectionServiceEnhanced();
    final granted = await service.requestPermissions();
    if (!mounted) return;
    if (granted) {
      service.startListening(context);
    }
  }

  @override
  void dispose() {
    CallDetectionServiceEnhanced().stopListening();
    super.dispose();
  }

  void _goToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onAnalyzePressed: () => _goToTab(1)),
      const AnalyzeCallScreen(),
      const HistoryScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _goToTab,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Analyze'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
        ],
      ),
    );
  }
}
