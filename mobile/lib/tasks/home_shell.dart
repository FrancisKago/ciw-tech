import 'package:flutter/material.dart';

/// Coquille de navigation role-gatée. Reçoit les onglets déjà construits
/// (injection = testable sans Firebase) et choisit selon le rôle.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key, required this.role, required this.userId,
    required this.pointageTab, required this.myTasksTab, required this.managerTasksTab,
  });
  final String role;
  final String userId;
  final Widget pointageTab, myTasksTab, managerTasksTab;

  bool get isManager => role == 'manager' || role == 'admin';

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = widget.isManager
        ? [widget.managerTasksTab]
        : [widget.pointageTab, widget.myTasksTab];
    final dests = widget.isManager
        ? const [NavigationDestination(icon: Icon(Icons.assignment), label: 'Tâches')]
        : const [
            NavigationDestination(icon: Icon(Icons.access_time), label: 'Pointage'),
            NavigationDestination(icon: Icon(Icons.checklist), label: 'Mes tâches'),
          ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: dests.length < 2
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: dests,
            ),
    );
  }
}
