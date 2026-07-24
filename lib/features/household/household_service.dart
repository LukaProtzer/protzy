import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'household_task.dart';

class HouseholdService {
  static const String _tasksKey = 'household_tasks';

  Future<List<HouseholdTask>> loadTasks() async {
    final preferences =
    await SharedPreferences.getInstance();

    final rawTasks =
        preferences.getStringList(_tasksKey) ?? const [];

    final tasks = <HouseholdTask>[];

    for (final rawTask in rawTasks) {
      try {
        final decoded = jsonDecode(rawTask);

        if (decoded is Map) {
          tasks.add(
            HouseholdTask.fromJson(
              Map<String, dynamic>.from(decoded),
            ),
          );
        }
      } catch (_) {
        // Ungültige Alt-Daten werden übersprungen.
      }
    }

    tasks.sort((a, b) {
      if (a.isDone != b.isDone) {
        return a.isDone ? 1 : -1;
      }

      final aDue = a.dueAt;
      final bDue = b.dueAt;

      if (aDue == null && bDue == null) {
        return a.createdAt.compareTo(b.createdAt);
      }

      if (aDue == null) return 1;
      if (bDue == null) return -1;

      return aDue.compareTo(bDue);
    });

    return tasks;
  }

  Future<void> saveTasks(
      List<HouseholdTask> tasks,
      ) async {
    final preferences =
    await SharedPreferences.getInstance();

    await preferences.setStringList(
      _tasksKey,
      tasks
          .map((task) => jsonEncode(task.toJson()))
          .toList(),
    );
  }

  Future<void> clearTasks() async {
    final preferences =
    await SharedPreferences.getInstance();

    await preferences.remove(_tasksKey);
  }
}
