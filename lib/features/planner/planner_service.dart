import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'planner_event.dart';

class PlannerService {
  static const String _eventsKey = 'planner_events';
  static const String _memberColorsKey =
      'planner_member_colors';

  Future<List<PlannerEvent>> loadEvents() async {
    final preferences =
    await SharedPreferences.getInstance();

    final rawEvents =
        preferences.getStringList(_eventsKey) ?? const [];

    final events = <PlannerEvent>[];

    for (final rawEvent in rawEvents) {
      try {
        final decoded = jsonDecode(rawEvent);

        if (decoded is Map) {
          events.add(
            PlannerEvent.fromJson(
              Map<String, dynamic>.from(decoded),
            ),
          );
        }
      } catch (_) {
        // Ungültige Alt-Daten werden übersprungen.
      }
    }

    events.sort(
          (a, b) => a.start.compareTo(b.start),
    );

    return events;
  }

  Future<void> saveEvents(
      List<PlannerEvent> events,
      ) async {
    final preferences =
    await SharedPreferences.getInstance();

    await preferences.setStringList(
      _eventsKey,
      events
          .map(
            (event) => jsonEncode(event.toJson()),
      )
          .toList(),
    );
  }

  Future<Map<String, int>> loadMemberColors() async {
    final preferences =
    await SharedPreferences.getInstance();

    final rawValue =
    preferences.getString(_memberColorsKey);

    if (rawValue == null || rawValue.trim().isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(rawValue);

      if (decoded is! Map) {
        return {};
      }

      return decoded.map<String, int>(
            (key, value) {
          final parsedValue = value is num
              ? value.toInt()
              : int.tryParse(value.toString()) ?? 0;

          return MapEntry(
            key.toString(),
            parsedValue,
          );
        },
      )..removeWhere(
            (key, value) =>
        key.trim().isEmpty || value == 0,
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> saveMemberColors(
      Map<String, int> colors,
      ) async {
    final preferences =
    await SharedPreferences.getInstance();

    await preferences.setString(
      _memberColorsKey,
      jsonEncode(colors),
    );
  }

  Future<void> clearEvents() async {
    final preferences =
    await SharedPreferences.getInstance();

    await preferences.remove(_eventsKey);
  }

  Future<void> clearMemberColors() async {
    final preferences =
    await SharedPreferences.getInstance();

    await preferences.remove(_memberColorsKey);
  }
}
