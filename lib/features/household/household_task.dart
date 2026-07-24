class HouseholdTask {
  const HouseholdTask({
    required this.id,
    required this.title,
    required this.assigneeIds,
    required this.createdAt,
    this.dueAt,
    this.note = '',
    this.isDone = false,
    this.completedAt,
    this.recurrence = HouseholdTaskRecurrence.none,
    this.priority = HouseholdTaskPriority.normal,
    this.category = 'Allgemein',
    this.history = const [],
  });

  final String id;
  final String title;
  final List<String> assigneeIds;
  final DateTime createdAt;
  final DateTime? dueAt;
  final String note;
  final bool isDone;
  final DateTime? completedAt;
  final HouseholdTaskRecurrence recurrence;
  final HouseholdTaskPriority priority;
  final String category;
  final List<HouseholdRoutineEntry> history;

  HouseholdTask copyWith({
    String? id,
    String? title,
    List<String>? assigneeIds,
    DateTime? createdAt,
    DateTime? dueAt,
    bool clearDueAt = false,
    String? note,
    bool? isDone,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    HouseholdTaskRecurrence? recurrence,
    HouseholdTaskPriority? priority,
    String? category,
    List<HouseholdRoutineEntry>? history,
  }) {
    return HouseholdTask(
      id: id ?? this.id,
      title: title ?? this.title,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      createdAt: createdAt ?? this.createdAt,
      dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
      note: note ?? this.note,
      isDone: isDone ?? this.isDone,
      completedAt: clearCompletedAt
          ? null
          : completedAt ?? this.completedAt,
      recurrence: recurrence ?? this.recurrence,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      history: history ?? this.history,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'assigneeIds': assigneeIds,
      'createdAt': createdAt.toIso8601String(),
      'dueAt': dueAt?.toIso8601String(),
      'note': note,
      'isDone': isDone,
      'completedAt': completedAt?.toIso8601String(),
      'recurrence': recurrence.name,
      'priority': priority.name,
      'category': category,
      'history': history.map((entry) => entry.toJson()).toList(),
    };
  }

  factory HouseholdTask.fromJson(
      Map<String, dynamic> json,
      ) {
    final rawAssigneeIds = json['assigneeIds'];
    final rawHistory = json['history'];

    return HouseholdTask(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      assigneeIds: rawAssigneeIds is List
          ? rawAssigneeIds
          .map((value) => value.toString())
          .where((value) => value.trim().isNotEmpty)
          .toList()
          : const [],
      createdAt: DateTime.tryParse(
        json['createdAt']?.toString() ?? '',
      ) ??
          DateTime.now(),
      dueAt: DateTime.tryParse(
        json['dueAt']?.toString() ?? '',
      ),
      note: json['note']?.toString() ?? '',
      isDone: json['isDone'] == true,
      completedAt: DateTime.tryParse(
        json['completedAt']?.toString() ?? '',
      ),
      recurrence: HouseholdTaskRecurrence.values.firstWhere(
            (value) =>
        value.name == json['recurrence']?.toString(),
        orElse: () => HouseholdTaskRecurrence.none,
      ),
      priority: HouseholdTaskPriority.values.firstWhere(
            (value) =>
        value.name == json['priority']?.toString(),
        orElse: () => HouseholdTaskPriority.normal,
      ),
      category:
      json['category']?.toString().trim().isNotEmpty == true
          ? json['category'].toString()
          : 'Allgemein',
      history: rawHistory is List
          ? rawHistory
          .whereType<Map>()
          .map(
            (entry) => HouseholdRoutineEntry.fromJson(
          Map<String, dynamic>.from(entry),
        ),
      )
          .toList()
          : const [],
    );
  }
}

class HouseholdRoutineEntry {
  const HouseholdRoutineEntry({
    required this.scheduledFor,
    required this.status,
    this.completedAt,
    this.completedBy,
  });

  final DateTime scheduledFor;
  final HouseholdRoutineStatus status;
  final DateTime? completedAt;
  final String? completedBy;

  Map<String, dynamic> toJson() {
    return {
      'scheduledFor': scheduledFor.toIso8601String(),
      'status': status.name,
      'completedAt': completedAt?.toIso8601String(),
      'completedBy': completedBy,
    };
  }

  factory HouseholdRoutineEntry.fromJson(
      Map<String, dynamic> json,
      ) {
    return HouseholdRoutineEntry(
      scheduledFor: DateTime.tryParse(
        json['scheduledFor']?.toString() ?? '',
      ) ??
          DateTime.now(),
      status: HouseholdRoutineStatus.values.firstWhere(
            (value) => value.name == json['status']?.toString(),
        orElse: () => HouseholdRoutineStatus.completed,
      ),
      completedAt: DateTime.tryParse(
        json['completedAt']?.toString() ?? '',
      ),
      completedBy: json['completedBy']?.toString(),
    );
  }
}

enum HouseholdRoutineStatus {
  completed,
  missed,
  skipped,
}

enum HouseholdTaskRecurrence {
  none,
  daily,
  weekly,
  monthly,
}

enum HouseholdTaskPriority {
  low,
  normal,
  high,
}
