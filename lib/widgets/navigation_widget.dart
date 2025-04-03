import 'package:flutter/material.dart';
import 'package:resourcehub/pages/home_page.dart'; // Import your UnifiedHomepage
// import 'package:resourcehub/pages/previous_year_papers_page.dart'; // Placeholder import

class NavigationWidget extends StatefulWidget {
  const NavigationWidget({super.key});

  @override
  State<NavigationWidget> createState() => _NavigationWidgetState();
}

class _NavigationWidgetState extends State<NavigationWidget> {
  int _selectedIndex = 0;

  final List<Widget> _widgetOptions = <Widget>[
    const UnifiedHomepage(), // Use your UnifiedHomepage here
    const Placeholder(child: Text('Previous Year Papers Page')), // Placeholder for PreviousYearPapersPage
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: NavigationBar(
        destinations: <Widget>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Previous Year',
          ),
        ],
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
      ),
    );
  }
}