import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../household/household_screen.dart';
import '../planner/planner_screen.dart';
import '../settings/settings_screen.dart';
import '../shopping/shopping_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _shoppingRefreshToken = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      ShoppingScreen(refreshToken: _shoppingRefreshToken),
      const PlannerScreen(),
      const HouseholdScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 1) _shoppingRefreshToken++;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Einkauf'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Planer'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Haushalt'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Mehr'),
        ],
      ),
    );
  }
}
