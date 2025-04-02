import 'package:flutter/material.dart';
// import 'package:resourcehub/pages/homepage.dart'; // Placeholder import
// import 'package:resourcehub/pages/previous_year_papers_page.dart'; // Placeholder import

class NavigationWidget extends StatefulWidget {
  const NavigationWidget({super.key});

  @override
  State<NavigationWidget> createState() => _NavigationWidgetState();
}

class _NavigationWidgetState extends State<NavigationWidget> {
  int _selectedIndex = 0;

  // Keep instances of the pages to prevent rebuilding on each tap.
  // This assumes that the state within these pages is managed correctly
  // and they can remain in memory without issues.
  final List<Widget> _widgetOptions = <Widget>[
    const Placeholder(child: Text('Home Page')), // Placeholder for UnifiedHomepage
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
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Previous Year',
          ),
        ],
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
      ),
    );
  }
}