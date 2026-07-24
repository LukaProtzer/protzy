import 'package:flutter/material.dart';

import '../home/home_screen.dart';
import '../household/household_screen.dart';
import '../planner/planner_screen.dart';
import '../settings/settings_screen.dart';
import '../shopping/shopping_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() =>
      _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _homeRefreshToken = 0;
  int _shoppingRefreshToken = 0;
  int _shoppingAddItemToken = 0;
  int _plannerAddEventToken = 0;
  int _householdAddTaskToken = 0;

  void _selectPage(int index) {
    setState(() {
      _currentIndex = index;

      if (index == 0) {
        _homeRefreshToken++;
      }

      if (index == 1) {
        _shoppingRefreshToken++;
      }
    });
  }

  void _openShoppingItemCreator() {
    setState(() {
      _currentIndex = 1;
      _shoppingAddItemToken++;
    });
  }

  void _openPlannerEventCreator() {
    setState(() {
      _currentIndex = 2;
      _plannerAddEventToken++;
    });
  }

  void _openHouseholdTaskCreator() {
    setState(() {
      _currentIndex = 3;
      _householdAddTaskToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        refreshToken: _homeRefreshToken,
        onNavigate: _selectPage,
        onAddShoppingItem:
        _openShoppingItemCreator,
        onAddPlannerEvent:
        _openPlannerEventCreator,
        onAddHouseholdTask:
        _openHouseholdTaskCreator,
      ),
      ShoppingScreen(
        refreshToken: _shoppingRefreshToken,
        addItemToken: _shoppingAddItemToken,
      ),
      PlannerScreen(
        addEventToken: _plannerAddEventToken,
      ),
      HouseholdScreen(
        addTaskToken: _householdAddTaskToken,
      ),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.shopping_cart_outlined,
            ),
            selectedIcon: Icon(
              Icons.shopping_cart,
            ),
            label: 'Einkauf',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.calendar_month_outlined,
            ),
            selectedIcon: Icon(
              Icons.calendar_month,
            ),
            label: 'Planer',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Haushalt',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Mehr',
          ),
        ],
      ),
    );
  }
}
