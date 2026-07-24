import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'planner_event.dart';
import 'planner_service.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({
    super.key,
    this.addEventToken = 0,
  });

  final int addEventToken;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final PlannerService _service = PlannerService();
  List<PlannerEvent> _events = [];
  bool _loading = true;
  bool _saving = false;
  _PlannerView _view = _PlannerView.month;
  DateTime _selectedDay = DateTime.now();
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  List<_Member> _members = const [
    _Member(
      id: 'luka',
      name: 'Luka',
      color: Color(0xFF4F7DF3),
    ),
    _Member(
      id: 'rebecca',
      name: 'Rebecca',
      color: Color(0xFF9B5DE5),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(
      covariant PlannerScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.addEventToken !=
        widget.addEventToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _addOrEdit();
        }
      });
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final results = await Future.wait([
      _service.loadEvents(),
      _service.loadMemberColors(),
    ]);

    if (!mounted) return;

    final events = results[0] as List<PlannerEvent>;
    final storedColors = results[1] as Map<String, int>;

    setState(() {
      _events = events;
      _members = _members.map((member) {
        final storedValue = storedColors[member.id];

        return storedValue == null
            ? member
            : member.copyWith(
          color: Color(storedValue),
        );
      }).toList();
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.saveEvents(_events);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _id() => '${DateTime.now().millisecondsSinceEpoch}${math.Random().nextInt(999999)}';

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<PlannerEvent> _eventsForDay(DateTime day) {
    return _events.where((event) => _sameDay(event.start, day)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  _Member _member(String id) => _members.firstWhere(
        (member) => member.id == id,
    orElse: () => _members.first,
  );

  Color _eventColor(PlannerEvent event) {
    if (event.participantIds.length > 1) {
      return Theme.of(context).colorScheme.tertiary;
    }
    return _member(event.participantIds.firstOrNull ?? event.createdBy).color;
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Future<void> _openMaps(PlannerEvent event) async {
    final query = [event.locationName, event.address]
        .where((value) => value.trim().isNotEmpty)
        .join(', ');
    if (query.isEmpty) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Karten-App konnte nicht geöffnet werden.')),
      );
    }
  }

  Future<void> _addOrEdit([PlannerEvent? existing]) async {
    final result = await showModalBottomSheet<PlannerEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventSheet(
        existing: existing,
        initialDate: existing?.start ?? _selectedDay,
        members: _members,
        createId: _id,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      final index = _events.indexWhere((event) => event.id == result.id);
      if (index == -1) {
        _events.add(result);
      } else {
        _events[index] = result;
      }
      _events.sort((a, b) => a.start.compareTo(b.start));
      _selectedDay = result.start;
      _visibleMonth = DateTime(result.start.year, result.start.month);
    });
    await _save();
  }

  Future<void> _delete(PlannerEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Termin löschen?'),
        content: Text('„${event.title}“ wird dauerhaft gelöscht.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _events.removeWhere((item) => item.id == event.id));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planer'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _addOrEdit,
                icon: const Icon(Icons.add),
                label: const Text('Termin hinzufügen'),
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<_PlannerView>(
              segments: const [
                ButtonSegment(value: _PlannerView.today, icon: Icon(Icons.today_outlined), label: Text('Heute')),
                ButtonSegment(value: _PlannerView.week, icon: Icon(Icons.view_week_outlined), label: Text('Woche')),
                ButtonSegment(value: _PlannerView.month, icon: Icon(Icons.calendar_month_outlined), label: Text('Monat')),
              ],
              selected: {_view},
              showSelectedIcon: false,
              onSelectionChanged: (value) => setState(() => _view = value.first),
            ),
            const SizedBox(height: 16),
            _buildLegend(),
            const SizedBox(height: 16),
            if (_view == _PlannerView.month) _buildMonth(),
            if (_view == _PlannerView.week) _buildWeek(),
            if (_view == _PlannerView.today) _buildToday(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final upcoming = _events.where((event) => event.end.isAfter(DateTime.now())).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.calendar_month_outlined),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$upcoming kommende Termine', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('Gemeinsam planen, erinnern und direkt losfahren.', style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          ..._members.map(
                (member) => _legendItem(
              member.color,
              member.name,
              onTap: () => _showColorPicker(member),
            ),
          ),
          _legendItem(
            colors.tertiary,
            'Gemeinsam',
          ),
        ],
      ),
    );
  }

  Widget _legendItem(
      Color color,
      String label, {
        VoidCallback? onTap,
      }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(label),
              if (onTap != null) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.edit_outlined,
                  size: 14,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showColorPicker(
      _Member member,
      ) async {
    const availableColors = [
      Color(0xFF4F7DF3),
      Color(0xFF9B5DE5),
      Color(0xFFE76F51),
      Color(0xFF2A9D8F),
      Color(0xFFE9C46A),
      Color(0xFFF4A261),
      Color(0xFFEF476F),
      Color(0xFF06D6A0),
      Color(0xFF118AB2),
      Color(0xFF8338EC),
      Color(0xFFFF006E),
      Color(0xFF8D6E63),
    ];

    final selectedColor = await showModalBottomSheet<Color>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colors = theme.colorScheme;

        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Farbe für ${member.name}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: availableColors.map((color) {
                    final selected =
                        color.toARGB32() ==
                            member.color.toARGB32();

                    return InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () {
                        Navigator.of(sheetContext).pop(color);
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? colors.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                          Icons.check,
                          color: Colors.white,
                        )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedColor == null || !mounted) {
      return;
    }

    setState(() {
      _members = _members.map((current) {
        return current.id == member.id
            ? current.copyWith(
          color: selectedColor,
        )
            : current;
      }).toList();
    });

    await _service.saveMemberColors({
      for (final current in _members)
        current.id: current.color.toARGB32(),
    });
  }

  Widget _buildMonth() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final days = DateUtils.getDaysInMonth(first.year, first.month);
    final leading = first.weekday - 1;
    final cells = leading + days;
    final rows = (cells / 7).ceil();
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1)), icon: const Icon(Icons.chevron_left)),
                  Expanded(child: Text(_monthTitle(_visibleMonth), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                  IconButton(onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1)), icon: const Icon(Icons.chevron_right)),
                ],
              ),
              Row(
                children: [
                  for (final day in const [
                    'Mo',
                    'Di',
                    'Mi',
                    'Do',
                    'Fr',
                    'Sa',
                    'So',
                  ])
                    Expanded(
                      child: Center(
                        child: Text(day),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (var row = 0; row < rows; row++)
                Row(
                  children: [
                    for (var column = 0; column < 7; column++)
                      Expanded(child: _monthCell(row * 7 + column, leading, days)),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _eventList(_selectedDay, title: 'Termine am ${_date(_selectedDay)}'),
      ],
    );
  }

  Widget _monthCell(int index, int leading, int days) {
    final dayNumber = index - leading + 1;
    if (dayNumber < 1 || dayNumber > days) return const SizedBox(height: 58);

    final day = DateTime(_visibleMonth.year, _visibleMonth.month, dayNumber);
    final selected = _sameDay(day, _selectedDay);
    final dayEvents = _eventsForDay(day);
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _selectedDay = day),
      child: Container(
        height: 58,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected ? colors.primaryContainer : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$dayNumber', style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.normal)),
            const SizedBox(height: 5),
            Wrap(
              spacing: 3,
              children: dayEvents.take(3).map((event) => Container(width: 6, height: 6, decoration: BoxDecoration(color: _eventColor(event), shape: BoxShape.circle))).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeek() {
    final monday = _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
    return Column(
      children: [
        for (var i = 0; i < 7; i++) ...[
          _eventList(monday.add(Duration(days: i)), title: i == 0 ? 'Diese Woche' : null, showDateHeader: true),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildToday() => _eventList(DateTime.now(), title: 'Heute');

  Widget _eventList(DateTime day, {String? title, bool showDateHeader = false}) {
    final events = _eventsForDay(day);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
        ],
        if (showDateHeader)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_weekdayTitle(day), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
        if (events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(22)),
            child: Text('Keine Termine', textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant)),
          )
        else
          ...events.map(_eventCard),
      ],
    );
  }

  Widget _eventCard(PlannerEvent event) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = _eventColor(event);
    final participants = event.participantIds.map((id) => _member(id).name).join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _addOrEdit(event),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(width: 7, height: 72, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(event.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                          if (event.visibility != PlannerVisibility.shared) const Icon(Icons.lock_outline, size: 17),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(event.isAllDay ? 'Ganztägig' : '${_time(event.start)}–${_time(event.end)} Uhr', style: TextStyle(color: colors.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(participants, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                      if (event.locationName.isNotEmpty || event.address.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        InkWell(
                          onTap: () => _openMaps(event),
                          child: Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 17, color: colors.primary),
                              const SizedBox(width: 4),
                              Expanded(child: Text(event.locationName.isNotEmpty ? event.locationName : event.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _addOrEdit(event);
                    if (value == 'delete') _delete(event);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                    PopupMenuItem(value: 'delete', child: Text('Löschen')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _monthTitle(DateTime date) {
    const months = ['Januar','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember'];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _weekdayTitle(DateTime date) {
    const days = ['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'];
    return '${days[date.weekday - 1]}, ${_date(date)}';
  }
}

class _EventSheet extends StatefulWidget {
  const _EventSheet({required this.initialDate, required this.members, required this.createId, this.existing});
  final DateTime initialDate;
  final List<_Member> members;
  final String Function() createId;
  final PlannerEvent? existing;

  @override
  State<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<_EventSheet> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _address;
  late final TextEditingController _note;
  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late bool _allDay;
  late Set<String> _participants;
  late PlannerVisibility _visibility;
  late PlannerRecurrence _recurrence;
  late int _reminder;

  @override
  void initState() {
    super.initState();
    final event = widget.existing;
    _title = TextEditingController(text: event?.title ?? '');
    _location = TextEditingController(text: event?.locationName ?? '');
    _address = TextEditingController(text: event?.address ?? '');
    _note = TextEditingController(text: event?.note ?? '');
    _date = event?.start ?? widget.initialDate;
    _start = TimeOfDay.fromDateTime(event?.start ?? DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day, 13));
    _end = TimeOfDay.fromDateTime(event?.end ?? DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day, 14));
    _allDay = event?.isAllDay ?? false;
    _participants = {...?event?.participantIds};
    if (_participants.isEmpty) _participants.add('luka');
    _visibility = event?.visibility ?? PlannerVisibility.shared;
    _recurrence = event?.recurrence ?? PlannerRecurrence.none;
    _reminder = event?.reminderMinutes.firstOrNull ?? 60;
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  DateTime _combine(TimeOfDay time) => DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);

  Future<void> _pickDate() async {
    final value = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 3650)), lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (value != null) setState(() => _date = value);
  }

  Future<void> _pickTime(bool start) async {
    final value = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (value != null) setState(() => start ? _start = value : _end = value);
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty || _participants.isEmpty) return;
    final start = _allDay ? DateTime(_date.year, _date.month, _date.day) : _combine(_start);
    var end = _allDay ? DateTime(_date.year, _date.month, _date.day, 23, 59) : _combine(_end);
    if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));

    Navigator.pop(
      context,
      PlannerEvent(
        id: widget.existing?.id ?? widget.createId(),
        title: title,
        start: start,
        end: end,
        createdBy: widget.existing?.createdBy ?? 'luka',
        participantIds: _participants.toList(),
        isAllDay: _allDay,
        visibility: _visibility,
        locationName: _location.text.trim(),
        address: _address.text.trim(),
        note: _note.text.trim(),
        reminderMinutes: [_reminder],
        recurrence: _recurrence,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .94),
          decoration: BoxDecoration(color: colors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 46, height: 5, decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(20))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    Expanded(child: Text(widget.existing == null ? 'Termin hinzufügen' : 'Termin bearbeiten', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    TextField(controller: _title, autofocus: widget.existing == null, decoration: const InputDecoration(labelText: 'Titel')),
                    const SizedBox(height: 14),
                    SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Ganztägig'), value: _allDay, onChanged: (value) => setState(() => _allDay = value)),
                    ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_today_outlined), title: const Text('Datum'), subtitle: Text('${_date.day.toString().padLeft(2, '0')}.${_date.month.toString().padLeft(2, '0')}.${_date.year}'), onTap: _pickDate),
                    if (!_allDay)
                      Row(
                        children: [
                          Expanded(child: ListTile(contentPadding: EdgeInsets.zero, title: const Text('Beginn'), subtitle: Text(_start.format(context)), onTap: () => _pickTime(true))),
                          Expanded(child: ListTile(contentPadding: EdgeInsets.zero, title: const Text('Ende'), subtitle: Text(_end.format(context)), onTap: () => _pickTime(false))),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Text('Teilnehmer', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: widget.members.map((member) => FilterChip(
                        avatar: CircleAvatar(backgroundColor: member.color),
                        label: Text(member.name),
                        selected: _participants.contains(member.id),
                        onSelected: (selected) => setState(() => selected ? _participants.add(member.id) : _participants.remove(member.id)),
                      )).toList(),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<PlannerVisibility>(
                      initialValue: _visibility,
                      decoration: const InputDecoration(labelText: 'Sichtbarkeit'),
                      items: const [
                        DropdownMenuItem(value: PlannerVisibility.shared, child: Text('Für alle sichtbar')),
                        DropdownMenuItem(value: PlannerVisibility.privateBusy, child: Text('Privat – nur „Belegt“ anzeigen')),
                        DropdownMenuItem(value: PlannerVisibility.privateHidden, child: Text('Privat – komplett ausblenden')),
                      ],
                      onChanged: (value) { if (value != null) setState(() => _visibility = value); },
                    ),
                    const SizedBox(height: 14),
                    TextField(controller: _location, decoration: const InputDecoration(labelText: 'Ort', prefixIcon: Icon(Icons.place_outlined))),
                    const SizedBox(height: 14),
                    TextField(controller: _address, decoration: const InputDecoration(labelText: 'Adresse', hintText: 'Straße, PLZ, Ort', prefixIcon: Icon(Icons.map_outlined))),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: _reminder,
                      decoration: const InputDecoration(labelText: 'Erinnerung'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Zur Terminzeit')),
                        DropdownMenuItem(value: 15, child: Text('15 Minuten vorher')),
                        DropdownMenuItem(value: 30, child: Text('30 Minuten vorher')),
                        DropdownMenuItem(value: 60, child: Text('1 Stunde vorher')),
                        DropdownMenuItem(value: 1440, child: Text('1 Tag vorher')),
                      ],
                      onChanged: (value) { if (value != null) setState(() => _reminder = value); },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<PlannerRecurrence>(
                      initialValue: _recurrence,
                      decoration: const InputDecoration(labelText: 'Wiederholung'),
                      items: const [
                        DropdownMenuItem(value: PlannerRecurrence.none, child: Text('Keine')),
                        DropdownMenuItem(value: PlannerRecurrence.daily, child: Text('Täglich')),
                        DropdownMenuItem(value: PlannerRecurrence.weekly, child: Text('Wöchentlich')),
                        DropdownMenuItem(value: PlannerRecurrence.monthly, child: Text('Monatlich')),
                        DropdownMenuItem(value: PlannerRecurrence.yearly, child: Text('Jährlich')),
                      ],
                      onChanged: (value) { if (value != null) setState(() => _recurrence = value); },
                    ),
                    const SizedBox(height: 14),
                    TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(labelText: 'Notiz')),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: SizedBox(width: double.infinity, height: 54, child: FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.check), label: Text(widget.existing == null ? 'Termin speichern' : 'Änderungen speichern'))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Member {
  const _Member({
    required this.id,
    required this.name,
    required this.color,
  });

  final String id;
  final String name;
  final Color color;

  _Member copyWith({
    String? id,
    String? name,
    Color? color,
  }) {
    return _Member(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}

enum _PlannerView { today, week, month }
