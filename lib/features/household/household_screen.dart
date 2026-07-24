import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'household_service.dart';
import 'household_task.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({
    super.key,
    this.addTaskToken = 0,
  });

  final int addTaskToken;

  @override
  State<HouseholdScreen> createState() =>
      _HouseholdScreenState();
}

class _HouseholdScreenState
    extends State<HouseholdScreen> {
  final HouseholdService _service = HouseholdService();

  List<HouseholdTask> _tasks = [];
  bool _isLoading = true;
  bool _isSaving = false;
  _HouseholdView _view = _HouseholdView.today;
  int _routinePreviewDays = 30;

  static const _members = [
    _HouseholdMember(
      id: 'luka',
      name: 'Luka',
      color: Color(0xFF4F7DF3),
    ),
    _HouseholdMember(
      id: 'rebecca',
      name: 'Rebecca',
      color: Color(0xFF9B5DE5),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void didUpdateWidget(
      covariant HouseholdScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.addTaskToken !=
        widget.addTaskToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showTaskSheet();
        }
      });
    }
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    final tasks = await _service.loadTasks();
    final normalizedTasks = tasks.map(_normalizeRoutine).toList();

    if (!mounted) return;

    setState(() {
      _tasks = normalizedTasks;
      _isLoading = false;
    });

    if (_tasksChanged(tasks, normalizedTasks)) {
      await _service.saveTasks(normalizedTasks);
    }
  }

  Future<void> _saveTasks() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _service.saveTasks(_tasks);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _generateId() {
    final random = math.Random();

    return '${DateTime.now().millisecondsSinceEpoch}'
        '${random.nextInt(999999)}';
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');

    return '$day.$month.${local.year}';
  }

  String _recurrenceLabel(
      HouseholdTaskRecurrence recurrence,
      ) {
    switch (recurrence) {
      case HouseholdTaskRecurrence.none:
        return 'Einmalig';
      case HouseholdTaskRecurrence.daily:
        return 'Täglich';
      case HouseholdTaskRecurrence.weekly:
        return 'Wöchentlich';
      case HouseholdTaskRecurrence.monthly:
        return 'Monatlich';
    }
  }

  _HouseholdMember _member(String id) {
    return _members.firstWhere(
          (member) => member.id == id,
      orElse: () => _members.first,
    );
  }

  List<HouseholdTask> get _visibleTasks {
    final now = DateTime.now();

    final tasks = _tasks.where((task) {
      switch (_view) {
        case _HouseholdView.today:
          return !task.isDone &&
              task.recurrence ==
                  HouseholdTaskRecurrence.none &&
              task.dueAt != null &&
              _sameDay(task.dueAt!, now);
        case _HouseholdView.open:
          return !task.isDone &&
              task.recurrence ==
                  HouseholdTaskRecurrence.none;
        case _HouseholdView.routines:
          return task.recurrence !=
              HouseholdTaskRecurrence.none;
        case _HouseholdView.done:
          return task.isDone &&
              task.recurrence ==
                  HouseholdTaskRecurrence.none;
      }
    }).toList();

    tasks.sort((a, b) {
      final aDue = a.dueAt;
      final bDue = b.dueAt;

      if (aDue == null && bDue == null) {
        return a.title
            .toLowerCase()
            .compareTo(b.title.toLowerCase());
      }

      if (aDue == null) return 1;
      if (bDue == null) return -1;

      return aDue.compareTo(bDue);
    });

    return tasks;
  }

  bool _tasksChanged(
      List<HouseholdTask> before,
      List<HouseholdTask> after,
      ) {
    if (before.length != after.length) return true;

    for (var index = 0; index < before.length; index++) {
      if (before[index].toJson().toString() !=
          after[index].toJson().toString()) {
        return true;
      }
    }

    return false;
  }

  HouseholdTask _normalizeRoutine(
      HouseholdTask task,
      ) {
    if (task.recurrence ==
        HouseholdTaskRecurrence.none ||
        task.dueAt == null) {
      return task;
    }

    var dueAt = task.dueAt!;
    final history = List<HouseholdRoutineEntry>.from(
      task.history,
    );
    final now = DateTime.now();

    while (_isBeforeDay(dueAt, now)) {
      final alreadyRecorded = history.any(
            (entry) => _sameDay(entry.scheduledFor, dueAt),
      );

      if (!alreadyRecorded) {
        history.add(
          HouseholdRoutineEntry(
            scheduledFor: dueAt,
            status: HouseholdRoutineStatus.missed,
          ),
        );
      }

      dueAt = _nextRoutineDate(
        dueAt,
        task.recurrence,
      );
    }

    return task.copyWith(
      dueAt: dueAt,
      history: history,
    );
  }

  bool _isBeforeDay(DateTime a, DateTime b) {
    final first = DateTime(a.year, a.month, a.day);
    final second = DateTime(b.year, b.month, b.day);

    return first.isBefore(second);
  }

  Future<void> _showTaskSheet([
    HouseholdTask? existing,
  ]) async {
    final result =
    await showModalBottomSheet<HouseholdTask>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HouseholdTaskSheet(
        existing: existing,
        members: _members,
        createId: _generateId,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      final index = _tasks.indexWhere(
            (task) => task.id == result.id,
      );

      if (index == -1) {
        _tasks.add(result);
      } else {
        _tasks[index] = result;
      }
    });

    await _saveTasks();
  }

  Future<void> _toggleDone(
      HouseholdTask task,
      ) async {
    final index = _tasks.indexWhere(
          (candidate) => candidate.id == task.id,
    );

    if (index == -1) return;

    if (task.recurrence !=
        HouseholdTaskRecurrence.none) {
      final completedAt = DateTime.now();
      final currentDue = task.dueAt ?? completedAt;
      final nextDue = _nextRoutineDate(
        currentDue,
        task.recurrence,
      );

      final updatedHistory = [
        ...task.history,
        HouseholdRoutineEntry(
          scheduledFor: currentDue,
          status: HouseholdRoutineStatus.completed,
          completedAt: completedAt,
          completedBy: task.assigneeIds.length == 1
              ? task.assigneeIds.first
              : 'gemeinsam',
        ),
      ];

      setState(() {
        _tasks[index] = task.copyWith(
          isDone: false,
          completedAt: completedAt,
          dueAt: nextDue,
          history: updatedHistory,
        );
      });

      await _saveTasks();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '„${task.title}“ für heute erledigt. '
                  'Nächste Ausführung: ${_formatDate(nextDue)}',
            ),
          ),
        );

      return;
    }

    setState(() {
      final nextDone = !task.isDone;

      _tasks[index] = task.copyWith(
        isDone: nextDone,
        completedAt:
        nextDone ? DateTime.now() : null,
        clearCompletedAt: !nextDone,
      );
    });

    await _saveTasks();
  }

  DateTime _nextRoutineDate(
      DateTime current,
      HouseholdTaskRecurrence recurrence,
      ) {
    switch (recurrence) {
      case HouseholdTaskRecurrence.none:
        return current;
      case HouseholdTaskRecurrence.daily:
        return DateTime(
          current.year,
          current.month,
          current.day + 1,
        );
      case HouseholdTaskRecurrence.weekly:
        return DateTime(
          current.year,
          current.month,
          current.day + 7,
        );
      case HouseholdTaskRecurrence.monthly:
        return DateTime(
          current.year,
          current.month + 1,
          current.day,
        );
    }
  }

  Future<void> _undoRoutineCompletion(
      HouseholdTask task,
      ) async {
    final index = _tasks.indexWhere(
          (candidate) => candidate.id == task.id,
    );

    if (index == -1 || task.dueAt == null) return;

    final previousDue = _previousRoutineDate(
      task.dueAt!,
      task.recurrence,
    );

    final updatedHistory =
    List<HouseholdRoutineEntry>.from(task.history);

    final completedIndex = updatedHistory.lastIndexWhere(
          (entry) =>
      entry.status ==
          HouseholdRoutineStatus.completed &&
          _sameDay(entry.scheduledFor, previousDue),
    );

    if (completedIndex != -1) {
      updatedHistory.removeAt(completedIndex);
    }

    setState(() {
      _tasks[index] = task.copyWith(
        dueAt: previousDue,
        clearCompletedAt: true,
        history: updatedHistory,
      );
    });

    await _saveTasks();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '„${task.title}“ wurde wieder als offen markiert.',
          ),
        ),
      );
  }

  DateTime _previousRoutineDate(
      DateTime current,
      HouseholdTaskRecurrence recurrence,
      ) {
    switch (recurrence) {
      case HouseholdTaskRecurrence.none:
        return current;
      case HouseholdTaskRecurrence.daily:
        return DateTime(
          current.year,
          current.month,
          current.day - 1,
        );
      case HouseholdTaskRecurrence.weekly:
        return DateTime(
          current.year,
          current.month,
          current.day - 7,
        );
      case HouseholdTaskRecurrence.monthly:
        return DateTime(
          current.year,
          current.month - 1,
          current.day,
        );
    }
  }

  Future<void> _deleteTask(
      HouseholdTask task,
      ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Aufgabe löschen?'),
          content: Text(
            '„${task.title}“ wird dauerhaft gelöscht.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) return;

    setState(() {
      _tasks.removeWhere(
            (candidate) => candidate.id == task.id,
      );
    });

    await _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _tasks.where((task) {
      return !task.isDone &&
          task.recurrence ==
              HouseholdTaskRecurrence.none;
    }).length;

    final todayCount = _tasks.where((task) {
      return !task.isDone &&
          task.recurrence ==
              HouseholdTaskRecurrence.none &&
          task.dueAt != null &&
          _sameDay(task.dueAt!, DateTime.now());
    }).length;

    final routineCount = _tasks.where((task) {
      return task.recurrence !=
          HouseholdTaskRecurrence.none;
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Haushalt'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _loadTasks,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            36,
          ),
          children: [
            _buildHeaderCard(
              openCount: openCount,
              todayCount: todayCount,
              routineCount: routineCount,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _showTaskSheet,
                icon: const Icon(Icons.add),
                label: const Text(
                  'Aufgabe hinzufügen',
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildViewSelector(),
            const SizedBox(height: 18),
            _buildTaskSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard({
    required int openCount,
    required int todayCount,
    required int routineCount,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius:
                  BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.home_work_outlined,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$openCount offene Einzelaufgaben',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Gemeinsam verteilen und im Blick behalten.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(
                        color:
                        colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStat(
                  icon: Icons.today_outlined,
                  value: '$todayCount',
                  label: 'heute',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStat(
                  icon: Icons.pending_actions_outlined,
                  value: '$openCount',
                  label: 'offen',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStat(
                  icon: Icons.repeat,
                  value: '$routineCount',
                  label: 'Routinen',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: colors.primary,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSelector() {
    return SegmentedButton<_HouseholdView>(
      segments: const [
        ButtonSegment(
          value: _HouseholdView.today,
          icon: Icon(Icons.today_outlined),
          label: Text('Heute'),
        ),
        ButtonSegment(
          value: _HouseholdView.open,
          icon: Icon(Icons.pending_actions_outlined),
          label: Text('Offen'),
        ),
        ButtonSegment(
          value: _HouseholdView.routines,
          icon: Icon(Icons.repeat),
          label: Text('Routinen'),
        ),
        ButtonSegment(
          value: _HouseholdView.done,
          icon: Icon(Icons.check_circle_outline),
          label: Text('Erledigt'),
        ),
      ],
      selected: {_view},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() {
          _view = selection.first;
        });
      },
    );
  }

  Widget _buildTaskSection() {
    if (_view == _HouseholdView.routines) {
      return _buildRoutineSections();
    }

    final tasks = _visibleTasks;

    final title = switch (_view) {
      _HouseholdView.today => 'Heute',
      _HouseholdView.open => 'Offene Aufgaben',
      _HouseholdView.routines => 'Routinen',
      _HouseholdView.done => 'Erledigt',
    };

    if (tasks.isEmpty) {
      return _buildEmptyState(title);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        ...tasks.map(_buildTaskCard),
      ],
    );
  }

  Widget _buildRoutineSections() {
    final now = DateTime.now();

    final completedToday = _tasks.where((task) {
      return task.recurrence !=
          HouseholdTaskRecurrence.none &&
          task.completedAt != null &&
          _sameDay(task.completedAt!, now);
    }).toList();

    final pending = _tasks.where((task) {
      return task.recurrence !=
          HouseholdTaskRecurrence.none &&
          (task.completedAt == null ||
              !_sameDay(task.completedAt!, now));
    }).toList();

    final previewEnd = now.add(
      Duration(days: _routinePreviewDays),
    );

    final upcoming = _tasks.where((task) {
      final dueAt = task.dueAt;

      return task.recurrence !=
          HouseholdTaskRecurrence.none &&
          dueAt != null &&
          !dueAt.isBefore(
            DateTime(now.year, now.month, now.day),
          ) &&
          !dueAt.isAfter(previewEnd);
    }).toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

    pending.sort((a, b) {
      final aDue = a.dueAt;
      final bDue = b.dueAt;

      if (aDue == null && bDue == null) {
        return a.title
            .toLowerCase()
            .compareTo(b.title.toLowerCase());
      }

      if (aDue == null) return 1;
      if (bDue == null) return -1;

      return aDue.compareTo(bDue);
    });

    completedToday.sort((a, b) {
      final aCompleted =
          a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bCompleted =
          b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bCompleted.compareTo(aCompleted);
    });

    if (pending.isEmpty && completedToday.isEmpty) {
      return _buildEmptyState('Routinen');
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Offene Routinen',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (pending.isEmpty)
          _simpleInfoCard(
            'Für heute sind alle Routinen erledigt.',
          )
        else
          ...pending.map(_buildTaskCard),
        const SizedBox(height: 22),
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: colors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Heute erledigt',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _countBadge(completedToday.length),
          ],
        ),
        const SizedBox(height: 10),
        if (completedToday.isEmpty)
          _simpleInfoCard(
            'Heute wurde noch keine Routine erledigt.',
          )
        else
          ...completedToday.map(
                (task) => _buildTaskCard(
              task,
              onOpenDetails: () => _showRoutineHistory(task),
            ),
          ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                'Kommende Routinen',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            DropdownButton<int>(
              value: _routinePreviewDays,
              items: const [
                DropdownMenuItem(
                  value: 7,
                  child: Text('7 Tage'),
                ),
                DropdownMenuItem(
                  value: 30,
                  child: Text('30 Tage'),
                ),
                DropdownMenuItem(
                  value: 90,
                  child: Text('3 Monate'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _routinePreviewDays = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (upcoming.isEmpty)
          _simpleInfoCard(
            'In diesem Zeitraum stehen keine Routinen an.',
          )
        else
          ...upcoming.map(_buildUpcomingRoutineCard),
      ],
    );
  }

  Widget _simpleInfoCard(String text) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _countBadge(int count) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildUpcomingRoutineCard(
      HouseholdTask task,
      ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dueAt = task.dueAt!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showRoutineHistory(task),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.event_repeat),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_formatDate(dueAt)} • '
                            '${_recurrenceLabel(task.recurrence)}',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRoutineHistory(
      HouseholdTask task,
      ) async {
    final completedCount = task.history
        .where(
          (entry) =>
      entry.status ==
          HouseholdRoutineStatus.completed,
    )
        .length;

    final missedCount = task.history
        .where(
          (entry) =>
      entry.status ==
          HouseholdRoutineStatus.missed,
    )
        .length;

    final entries = [...task.history]
      ..sort(
            (a, b) =>
            b.scheduledFor.compareTo(a.scheduledFor),
      );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colors = theme.colorScheme;

        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight:
              MediaQuery.of(sheetContext).size.height *
                  0.9,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    18,
                    12,
                    12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(
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
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _historyStat(
                          sheetContext,
                          completedCount,
                          'erledigt',
                          Icons.check_circle_outline,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _historyStat(
                          sheetContext,
                          missedCount,
                          'versäumt',
                          Icons.error_outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(
                    child: Text(
                      'Noch keine Historie vorhanden.',
                    ),
                  )
                      : ListView.builder(
                    padding:
                    const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      24,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final completed =
                          entry.status ==
                              HouseholdRoutineStatus
                                  .completed;

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            completed
                                ? Icons
                                .check_circle_outline
                                : Icons.error_outline,
                            color: completed
                                ? colors.primary
                                : colors.error,
                          ),
                          title: Text(
                            completed
                                ? 'Erledigt'
                                : 'Versäumt',
                          ),
                          subtitle: Text(
                            _formatDate(
                              entry.scheduledFor,
                            ),
                          ),
                          trailing: entry.completedBy ==
                              null
                              ? null
                              : Text(
                            entry.completedBy ==
                                'gemeinsam'
                                ? 'Gemeinsam'
                                : _member(
                              entry
                                  .completedBy!,
                            ).name,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _historyStat(
      BuildContext context,
      int value,
      String label,
      IconData icon,
      ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon),
          const SizedBox(height: 5),
          Text(
            '$value',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            _view == _HouseholdView.done
                ? Icons.check_circle_outline
                : Icons.home_work_outlined,
            size: 46,
            color: colors.primary,
          ),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _view == _HouseholdView.done
                ? 'Noch keine Aufgaben erledigt.'
                : _view == _HouseholdView.routines
                ? 'Noch keine Routinen angelegt.'
                : 'Hier ist gerade nichts offen.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
      HouseholdTask task, {
        VoidCallback? onOpenDetails,
      }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final assignees = task.assigneeIds
        .map(_member)
        .toList();

    final dueText = task.dueAt == null
        ? 'Ohne Termin'
        : _formatDate(task.dueAt!);

    final recurrenceText =
    _recurrenceLabel(task.recurrence);

    final isRoutine = task.recurrence !=
        HouseholdTaskRecurrence.none;

    final completedToday = isRoutine &&
        task.completedAt != null &&
        _sameDay(task.completedAt!, DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onOpenDetails ??
                  () => _showTaskSheet(task),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              12,
              8,
              12,
            ),
            child: Row(
              children: [
                if (isRoutine)
                  IconButton.filledTonal(
                    tooltip: completedToday
                        ? 'Als nicht erledigt markieren'
                        : 'Für heute erledigen',
                    onPressed: () {
                      if (completedToday) {
                        _undoRoutineCompletion(task);
                      } else {
                        _toggleDone(task);
                      }
                    },
                    icon: Icon(
                      completedToday
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                    ),
                  )
                else
                  Checkbox(
                    value: task.isDone,
                    onChanged: (_) {
                      _toggleDone(task);
                    },
                  ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: theme
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                fontWeight:
                                FontWeight.w800,
                                decoration: task.isDone
                                    ? TextDecoration
                                    .lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          if (task.priority ==
                              HouseholdTaskPriority.high)
                            Icon(
                              Icons.priority_high,
                              size: 18,
                              color: colors.error,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isRoutine
                            ? completedToday
                            ? 'Heute erledigt • Tippen zum Rückgängig machen'
                            : 'Fällig: $dueText • $recurrenceText'
                            : '$dueText • $recurrenceText',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(
                          color: completedToday
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          fontWeight: completedToday
                              ? FontWeight.w700
                              : null,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: assignees.map((member) {
                          return Container(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: member.color.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize:
                              MainAxisSize.min,
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration:
                                  BoxDecoration(
                                    color: member.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(member.name),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_TaskAction>(
                  tooltip: 'Optionen',
                  onSelected: (action) {
                    if (action == _TaskAction.edit) {
                      _showTaskSheet(task);
                    } else {
                      _deleteTask(task);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _TaskAction.edit,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 12),
                          Text('Bearbeiten'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _TaskAction.delete,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline),
                          SizedBox(width: 12),
                          Text('Löschen'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HouseholdTaskSheet
    extends StatefulWidget {
  const _HouseholdTaskSheet({
    required this.members,
    required this.createId,
    this.existing,
  });

  final List<_HouseholdMember> members;
  final String Function() createId;
  final HouseholdTask? existing;

  @override
  State<_HouseholdTaskSheet> createState() =>
      _HouseholdTaskSheetState();
}

class _HouseholdTaskSheetState
    extends State<_HouseholdTaskSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  late Set<String> _assigneeIds;
  late DateTime? _dueAt;
  late HouseholdTaskRecurrence _recurrence;
  late HouseholdTaskPriority _priority;
  late String _category;

  static const _categories = [
    'Allgemein',
    'Putzen',
    'Wäsche',
    'Küche',
    'Müll',
    'Einkauf',
    'Garten',
    'Haustier',
  ];

  @override
  void initState() {
    super.initState();

    final task = widget.existing;

    _titleController = TextEditingController(
      text: task?.title ?? '',
    );

    _noteController = TextEditingController(
      text: task?.note ?? '',
    );

    _assigneeIds = {
      ...?task?.assigneeIds,
    };

    if (_assigneeIds.isEmpty) {
      _assigneeIds.add('luka');
    }

    _dueAt = task?.dueAt ?? DateTime.now();

    _recurrence = task?.recurrence ??
        HouseholdTaskRecurrence.none;

    _priority =
        task?.priority ?? HouseholdTaskPriority.normal;

    _category = task?.category ?? 'Allgemein';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  Future<void> _pickDate() async {
    final initialDate = _dueAt ?? DateTime.now();

    final value = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(
        const Duration(days: 3650),
      ),
      lastDate: DateTime.now().add(
        const Duration(days: 3650),
      ),
    );

    if (value != null) {
      setState(() {
        _dueAt = value;
      });
    }
  }

  void _submit() {
    final title = _titleController.text.trim();

    if (title.isEmpty || _assigneeIds.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      HouseholdTask(
        id: widget.existing?.id ?? widget.createId(),
        title: title,
        assigneeIds: _assigneeIds.toList(),
        createdAt:
        widget.existing?.createdAt ?? DateTime.now(),
        dueAt: _dueAt,
        note: _noteController.text.trim(),
        isDone: widget.existing?.isDone ?? false,
        completedAt: widget.existing?.completedAt,
        recurrence: _recurrence,
        priority: _priority,
        category: _category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.94,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius:
                  BorderRadius.circular(20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  18,
                  12,
                  12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.existing == null
                            ? 'Aufgabe hinzufügen'
                            : 'Aufgabe bearbeiten',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    20,
                  ),
                  children: [
                    TextField(
                      controller: _titleController,
                      autofocus: widget.existing == null,
                      textCapitalization:
                      TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Aufgabe',
                        hintText:
                        'z. B. Müll rausbringen',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Zuständig',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.members.map((member) {
                        return FilterChip(
                          avatar: CircleAvatar(
                            backgroundColor: member.color,
                          ),
                          label: Text(member.name),
                          selected: _assigneeIds
                              .contains(member.id),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _assigneeIds.add(member.id);
                              } else {
                                _assigneeIds
                                    .remove(member.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.calendar_today_outlined,
                      ),
                      title: const Text('Fällig am'),
                      subtitle: Text(
                        _dueAt == null
                            ? 'Kein Datum'
                            : '${_dueAt!.day.toString().padLeft(2, '0')}.'
                            '${_dueAt!.month.toString().padLeft(2, '0')}.'
                            '${_dueAt!.year}',
                      ),
                      trailing: IconButton(
                        onPressed: () {
                          setState(() {
                            _dueAt = null;
                          });
                        },
                        icon: const Icon(Icons.clear),
                        tooltip: 'Datum entfernen',
                      ),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<
                        HouseholdTaskRecurrence>(
                      initialValue: _recurrence,
                      decoration: const InputDecoration(
                        labelText: 'Wiederholung',
                        helperText:
                        'Mit Wiederholung wird die Aufgabe automatisch als Routine eingeordnet.',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value:
                          HouseholdTaskRecurrence.none,
                          child: Text('Keine'),
                        ),
                        DropdownMenuItem(
                          value:
                          HouseholdTaskRecurrence.daily,
                          child: Text('Täglich'),
                        ),
                        DropdownMenuItem(
                          value:
                          HouseholdTaskRecurrence.weekly,
                          child: Text('Wöchentlich'),
                        ),
                        DropdownMenuItem(
                          value:
                          HouseholdTaskRecurrence.monthly,
                          child: Text('Monatlich'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _recurrence = value;
                        });
                      },
                    ),
                    if (_recurrence !=
                        HouseholdTaskRecurrence.none) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius:
                          BorderRadius.circular(18),
                        ),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.repeat,
                              color: colors
                                  .onPrimaryContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Diese Aufgabe erscheint nur unter „Routinen“. '
                                    'Beim Erledigen wird automatisch der nächste Termin gesetzt.',
                                style: TextStyle(
                                  color: colors
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    DropdownButtonFormField<
                        HouseholdTaskPriority>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Priorität',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value:
                          HouseholdTaskPriority.low,
                          child: Text('Niedrig'),
                        ),
                        DropdownMenuItem(
                          value:
                          HouseholdTaskPriority.normal,
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(
                          value:
                          HouseholdTaskPriority.high,
                          child: Text('Hoch'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _priority = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: 'Kategorie',
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _category = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      textCapitalization:
                      TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notiz',
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  16,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check),
                    label: Text(
                      widget.existing == null
                          ? 'Aufgabe speichern'
                          : 'Änderungen speichern',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HouseholdMember {
  const _HouseholdMember({
    required this.id,
    required this.name,
    required this.color,
  });

  final String id;
  final String name;
  final Color color;
}

enum _HouseholdView {
  today,
  open,
  routines,
  done,
}

enum _TaskAction {
  edit,
  delete,
}
