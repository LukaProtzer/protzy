class PlannerEvent {
  const PlannerEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.createdBy,
    required this.participantIds,
    this.isAllDay = false,
    this.visibility = PlannerVisibility.shared,
    this.locationName = '',
    this.address = '',
    this.note = '',
    this.reminderMinutes = const [60],
    this.recurrence = PlannerRecurrence.none,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String createdBy;
  final List<String> participantIds;
  final bool isAllDay;
  final PlannerVisibility visibility;
  final String locationName;
  final String address;
  final String note;
  final List<int> reminderMinutes;
  final PlannerRecurrence recurrence;

  PlannerEvent copyWith({
    String? id,
    String? title,
    DateTime? start,
    DateTime? end,
    String? createdBy,
    List<String>? participantIds,
    bool? isAllDay,
    PlannerVisibility? visibility,
    String? locationName,
    String? address,
    String? note,
    List<int>? reminderMinutes,
    PlannerRecurrence? recurrence,
  }) {
    return PlannerEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      createdBy: createdBy ?? this.createdBy,
      participantIds: participantIds ?? this.participantIds,
      isAllDay: isAllDay ?? this.isAllDay,
      visibility: visibility ?? this.visibility,
      locationName: locationName ?? this.locationName,
      address: address ?? this.address,
      note: note ?? this.note,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      recurrence: recurrence ?? this.recurrence,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'createdBy': createdBy,
    'participantIds': participantIds,
    'isAllDay': isAllDay,
    'visibility': visibility.name,
    'locationName': locationName,
    'address': address,
    'note': note,
    'reminderMinutes': reminderMinutes,
    'recurrence': recurrence.name,
  };

  factory PlannerEvent.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participantIds'];
    final rawReminders = json['reminderMinutes'];

    return PlannerEvent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      start: DateTime.tryParse(json['start']?.toString() ?? '') ?? DateTime.now(),
      end: DateTime.tryParse(json['end']?.toString() ?? '') ?? DateTime.now().add(const Duration(hours: 1)),
      createdBy: json['createdBy']?.toString() ?? 'luka',
      participantIds: rawParticipants is List
          ? rawParticipants.map((value) => value.toString()).toList()
          : const ['luka'],
      isAllDay: json['isAllDay'] == true,
      visibility: PlannerVisibility.values.firstWhere(
            (value) => value.name == json['visibility']?.toString(),
        orElse: () => PlannerVisibility.shared,
      ),
      locationName: json['locationName']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      reminderMinutes: rawReminders is List
          ? rawReminders.whereType<num>().map((value) => value.toInt()).toList()
          : const [60],
      recurrence: PlannerRecurrence.values.firstWhere(
            (value) => value.name == json['recurrence']?.toString(),
        orElse: () => PlannerRecurrence.none,
      ),
    );
  }
}

enum PlannerVisibility { shared, privateHidden, privateBusy }
enum PlannerRecurrence { none, daily, weekly, monthly, yearly }
