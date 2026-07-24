import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../household/household_service.dart';
import '../household/household_task.dart';
import '../planner/planner_event.dart';
import '../planner/planner_service.dart';
import '../shopping/shopping_list.dart';
import '../shopping/shopping_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onNavigate,
    required this.onAddShoppingItem,
    required this.onAddPlannerEvent,
    required this.onAddHouseholdTask,
    this.refreshToken = 0,
  });

  final ValueChanged<int> onNavigate;
  final VoidCallback onAddShoppingItem;
  final VoidCallback onAddPlannerEvent;
  final VoidCallback onAddHouseholdTask;
  final int refreshToken;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final PlannerService _plannerService = PlannerService();
  final HouseholdService _householdService =
  HouseholdService();
  final ShoppingService _shoppingService = ShoppingService();

  List<PlannerEvent> _events = [];
  List<HouseholdTask> _tasks = [];
  List<ShoppingList> _shoppingLists = [];
  Map<String, int> _memberColors = {};

  bool _isLoading = true;
  bool _showCelebration = false;
  bool _celebrationCheckRunning = false;

  late final AnimationController _celebrationController;

  static const _defaultMemberColors = {
    'luka': 0xFF4F7DF3,
    'rebecca': 0xFF9B5DE5,
  };

  @override
  void initState() {
    super.initState();

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _loadDashboard();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadDashboard(showLoading: false);
    }
  }

  Future<void> _loadDashboard({
    bool showLoading = true,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final results = await Future.wait<dynamic>([
      _plannerService.loadEvents(),
      _plannerService.loadMemberColors(),
      _householdService.loadTasks(),
      _shoppingService.loadLists(),
    ]);

    if (!mounted) return;

    setState(() {
      _events = results[0] as List<PlannerEvent>;
      _memberColors = results[1] as Map<String, int>;
      _tasks = results[2] as List<HouseholdTask>;
      _shoppingLists = results[3] as List<ShoppingList>;
      _isLoading = false;
    });

    await _maybeShowCelebration();
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  bool _isBeforeDay(DateTime a, DateTime b) {
    final first = DateTime(a.year, a.month, a.day);
    final second = DateTime(b.year, b.month, b.day);

    return first.isBefore(second);
  }

  _HomeMood _homeMood() {
    final now = DateTime.now();
    final hour = now.hour;
    final hasNothingDue = _todayTotalCount == 0;
    final rareSparkle =
        (now.year + now.month + now.day) % 9 == 0;

    if (hour >= 5 && hour < 11) {
      return _HomeMood(
        greeting: 'Guten Morgen',
        emoji: '☕',
        message: hasNothingDue
            ? 'Ruhiger Start – heute ist alles im grünen Bereich.'
            : 'Kaffee an, Tag an.',
      );
    }

    if (hour >= 11 && hour < 14) {
      return _HomeMood(
        greeting: 'Guten Mittag',
        emoji: '☀️',
        message: now.weekday == DateTime.friday
            ? 'Freitagsmodus: nur noch der Endspurt.'
            : 'Halbzeit – ihr habt den Tag im Griff.',
      );
    }

    if (hour >= 14 && hour < 18) {
      return _HomeMood(
        greeting: 'Guten Nachmittag',
        emoji: rareSparkle ? '✨' : '🌤️',
        message: rareSparkle
            ? 'Kleine Sternschnuppe am Nachmittag erwischt.'
            : 'Noch ein paar Dinge, dann ist Feierabend.',
      );
    }

    if (hour >= 18 && hour < 23) {
      return _HomeMood(
        greeting: 'Guten Abend',
        emoji: '🌙',
        message: hasNothingDue
            ? 'Alles erledigt – Füße hoch.'
            : 'Der Abend ist da, Protzy hält den Rest im Blick.',
      );
    }

    return _HomeMood(
      greeting: 'Gute Nacht',
      emoji: '🦉',
      message: 'Die Eule hat alles im Blick.',
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _formatShortDate(DateTime date) {
    const weekdays = [
      'Mo',
      'Di',
      'Mi',
      'Do',
      'Fr',
      'Sa',
      'So',
    ];

    return '${weekdays[date.weekday - 1]}, '
        '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.';
  }

  String _assigneeName(String id) {
    switch (id) {
      case 'luka':
        return 'Luka';
      case 'rebecca':
        return 'Rebecca';
      case 'gemeinsam':
        return 'Gemeinsam';
      default:
        return id;
    }
  }

  Color _memberColor(String id) {
    final storedValue = _memberColors[id];
    final fallbackValue =
        _defaultMemberColors[id] ?? 0xFF6B7280;

    return Color(storedValue ?? fallbackValue);
  }

  List<PlannerEvent> get _upcomingEvents {
    final now = DateTime.now();

    final events = _events.where((event) {
      return event.visibility !=
          PlannerVisibility.privateHidden &&
          event.end.isAfter(now);
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return events.take(3).toList();
  }

  List<HouseholdTask> get _todaySingleTasks {
    final now = DateTime.now();

    final tasks = _tasks.where((task) {
      return !task.isDone &&
          task.recurrence ==
              HouseholdTaskRecurrence.none &&
          task.dueAt != null &&
          _sameDay(task.dueAt!, now);
    }).toList()
      ..sort((a, b) {
        final priorityComparison =
        b.priority.index.compareTo(a.priority.index);

        if (priorityComparison != 0) {
          return priorityComparison;
        }

        return a.title
            .toLowerCase()
            .compareTo(b.title.toLowerCase());
      });

    return tasks;
  }

  List<HouseholdTask> get _dueRoutines {
    final now = DateTime.now();

    final tasks = _tasks.where((task) {
      final dueAt = task.dueAt;

      if (task.recurrence ==
          HouseholdTaskRecurrence.none ||
          dueAt == null) {
        return false;
      }

      final completedToday = task.completedAt != null &&
          _sameDay(task.completedAt!, now);

      return !completedToday &&
          (_sameDay(dueAt, now) ||
              _isBeforeDay(dueAt, now));
    }).toList()
      ..sort((a, b) {
        final aDue = a.dueAt;
        final bDue = b.dueAt;

        if (aDue == null && bDue == null) return 0;
        if (aDue == null) return 1;
        if (bDue == null) return -1;

        return aDue.compareTo(bDue);
      });

    return tasks;
  }

  int get _openShoppingItemCount {
    return _shoppingLists.fold<int>(
      0,
          (total, list) =>
      total +
          list.items.where((item) => !item.done).length,
    );
  }

  List<ShoppingList> get _activeShoppingLists {
    final lists = _shoppingLists.where((list) {
      return list.items.any((item) => !item.done);
    }).toList()
      ..sort((a, b) {
        final aCount =
            a.items.where((item) => !item.done).length;
        final bCount =
            b.items.where((item) => !item.done).length;

        return bCount.compareTo(aCount);
      });

    return lists.take(3).toList();
  }

  int get _todayTotalCount {
    final eventCount = _events.where((event) {
      return event.visibility !=
          PlannerVisibility.privateHidden &&
          _sameDay(event.start, DateTime.now());
    }).length;

    return eventCount +
        _todaySingleTasks.length +
        _dueRoutines.length;
  }


  bool get _completedSomethingToday {
    final now = DateTime.now();

    return _tasks.any((task) {
      return task.completedAt != null &&
          _sameDay(task.completedAt!, now);
    });
  }

  Future<void> _maybeShowCelebration() async {
    if (_celebrationCheckRunning ||
        !mounted ||
        _todayTotalCount != 0 ||
        !_completedSomethingToday) {
      return;
    }

    _celebrationCheckRunning = true;

    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final storageKey = 'home_celebration_$dateKey';
    final preferences =
    await SharedPreferences.getInstance();
    final alreadyShown =
        preferences.getBool(storageKey) ?? false;

    if (!mounted) {
      _celebrationCheckRunning = false;
      return;
    }

    if (!alreadyShown) {
      await preferences.setBool(storageKey, true);

      setState(() {
        _showCelebration = true;
      });

      _celebrationController
        ..reset()
        ..forward();

      await Future<void>.delayed(
        const Duration(milliseconds: 1700),
      );

      if (mounted) {
        setState(() {
          _showCelebration = false;
        });
      }
    }

    _celebrationCheckRunning = false;
  }

  int _routineStreak(HouseholdTask task) {
    if (task.recurrence ==
        HouseholdTaskRecurrence.none ||
        task.history.isEmpty) {
      return 0;
    }

    final entries = [...task.history]
      ..sort(
            (a, b) =>
            b.scheduledFor.compareTo(a.scheduledFor),
      );

    var streak = 0;

    for (final entry in entries) {
      if (entry.status ==
          HouseholdRoutineStatus.completed) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  String _seasonEmoji(DateTime now) {
    if (now.month == 12 || now.month <= 2) {
      return '❄️';
    }

    if (now.month >= 3 && now.month <= 5) {
      return '🌱';
    }

    if (now.month >= 6 && now.month <= 8) {
      return '🌿';
    }

    return '🍂';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          _isLoading
              ? const Center(
            child: CircularProgressIndicator(),
          )
              : RefreshIndicator(
            onRefresh: _loadDashboard,
            child: ListView(
              physics:
              const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16,
                18,
                16,
                36,
              ),
              children: [
                _buildGreeting(),
                const SizedBox(height: 18),
                _buildOverviewCard(),
                const SizedBox(height: 18),
                _buildQuickActions(),
                const SizedBox(height: 24),
                _buildPlannerSection(),
                const SizedBox(height: 24),
                _buildHouseholdSection(),
                const SizedBox(height: 24),
                _buildShoppingSection(),
              ],
            ),
          ),
          if (_showCelebration)
            Positioned.fill(
              child: IgnorePointer(
                child: _CelebrationOverlay(
                  animation: _celebrationController,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();
    final mood = _homeMood();

    const weekdays = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag',
    ];

    const months = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      mood.greeting,
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0.72,
                      end: 1,
                    ),
                    duration:
                    const Duration(milliseconds: 850),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Transform.rotate(
                          angle: (1 - value) * -0.12,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      mood.emoji,
                      style: const TextStyle(fontSize: 31),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${weekdays[now.weekday - 1]}, '
                    '${now.day}. ${months[now.month - 1]} '
                    '${_seasonEmoji(now)}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  mood.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          onPressed: () {
            _loadDashboard(showLoading: false);
          },
          tooltip: 'Aktualisieren',
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildOverviewCard() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final todayCount = _todayTotalCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colors.surface.withValues(
                    alpha: 0.62,
                  ),
                  borderRadius:
                  BorderRadius.circular(18),
                ),
                child: Icon(
                  todayCount == 0
                      ? Icons.check_circle_outline
                      : Icons.auto_awesome_outlined,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      todayCount == 0
                          ? 'Heute ist alles ruhig'
                          : '$todayCount Dinge für heute',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(
                        fontWeight: FontWeight.w900,
                        color:
                        colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      todayCount == 0
                          ? 'Keine Termine oder Aufgaben fällig.'
                          : 'Termine, Aufgaben und Routinen auf einen Blick.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(
                        color: colors.onPrimaryContainer
                            .withValues(alpha: 0.8),
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
                child: _buildOverviewStat(
                  icon: Icons.event_outlined,
                  value:
                  '${_events.where((event) => _sameDay(event.start, DateTime.now()) && event.visibility != PlannerVisibility.privateHidden).length}',
                  label: 'Termine',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _buildOverviewStat(
                  icon: Icons.task_alt_outlined,
                  value:
                  '${_todaySingleTasks.length + _dueRoutines.length}',
                  label: 'Aufgaben',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _buildOverviewStat(
                  icon:
                  Icons.shopping_cart_outlined,
                  value: '$_openShoppingItemCount',
                  label: 'Einkauf',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat({
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
        color: colors.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 19,
            color: colors.onPrimaryContainer,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(
              fontWeight: FontWeight.w900,
              color: colors.onPrimaryContainer,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            style: theme.textTheme.bodySmall
                ?.copyWith(
              color: colors.onPrimaryContainer
                  .withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Direkt hinzufügen',
          icon: Icons.bolt_outlined,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.add_shopping_cart,
                label: 'Artikel',
                subtitle: 'Einkauf',
                onTap: widget.onAddShoppingItem,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                icon: Icons.event_available_outlined,
                label: 'Termin',
                subtitle: 'Planer',
                onTap: widget.onAddPlannerEvent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                icon: Icons.add_task,
                label: 'Aufgabe',
                subtitle: 'Haushalt',
                onTap: widget.onAddHouseholdTask,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlannerSection() {
    final events = _upcomingEvents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Nächste Termine',
          icon: Icons.calendar_month_outlined,
          onTap: () => widget.onNavigate(2),
        ),
        const SizedBox(height: 10),
        if (events.isEmpty)
          _emptyCard(
            icon: Icons.event_available_outlined,
            text: 'Keine kommenden Termine.',
          )
        else
          ...events.map(_buildEventCard),
      ],
    );
  }

  Widget _buildEventCard(PlannerEvent event) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final displayTitle =
    event.visibility == PlannerVisibility.privateBusy
        ? 'Belegt'
        : event.title;

    final participantId =
    event.participantIds.length == 1
        ? event.participantIds.first
        : 'gemeinsam';

    final color = participantId == 'gemeinsam'
        ? colors.tertiary
        : _memberColor(participantId);

    final dateText = _sameDay(
      event.start,
      DateTime.now(),
    )
        ? 'Heute'
        : _formatShortDate(event.start);

    final timeText = event.isAllDay
        ? 'Ganztägig'
        : '${_formatTime(event.start)} Uhr';

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: () => widget.onNavigate(2),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$dateText • $timeText',
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

  Widget _buildHouseholdSection() {
    final tasks = [
      ..._todaySingleTasks,
      ..._dueRoutines,
    ].take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Heute im Haushalt',
          icon: Icons.home_work_outlined,
          onTap: () => widget.onNavigate(3),
        ),
        const SizedBox(height: 10),
        if (tasks.isEmpty)
          _emptyCard(
            icon: Icons.check_circle_outline,
            text: 'Für heute ist nichts offen.',
          )
        else
          ...tasks.map(_buildHouseholdTaskCard),
      ],
    );
  }

  Widget _buildHouseholdTaskCard(
      HouseholdTask task,
      ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isRoutine = task.recurrence !=
        HouseholdTaskRecurrence.none;
    final streak = _routineStreak(task);

    final assigneeText = task.assigneeIds.isEmpty
        ? 'Nicht zugewiesen'
        : task.assigneeIds
        .map(_assigneeName)
        .join(', ');

    final accentColor = task.assigneeIds.length == 1
        ? _memberColor(task.assigneeIds.first)
        : colors.tertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: () => widget.onNavigate(3),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(
                      alpha: 0.17,
                    ),
                    borderRadius:
                    BorderRadius.circular(15),
                  ),
                  child: Icon(
                    isRoutine
                        ? Icons.repeat
                        : Icons.task_alt_outlined,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isRoutine
                            ? '$assigneeText • Routine'
                            : assigneeText,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isRoutine && streak >= 2) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius:
                      BorderRadius.circular(18),
                    ),
                    child: Text(
                      '🔥 $streak',
                      style: TextStyle(
                        color: colors.onSecondaryContainer,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (task.priority ==
                    HouseholdTaskPriority.high)
                  Icon(
                    Icons.priority_high,
                    color: colors.error,
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShoppingSection() {
    final lists = _activeShoppingLists;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Einkaufslisten',
          icon: Icons.shopping_cart_outlined,
          onTap: () => widget.onNavigate(1),
        ),
        const SizedBox(height: 10),
        if (lists.isEmpty)
          _emptyCard(
            icon: Icons.shopping_cart_checkout,
            text: 'Keine offenen Einkaufsartikel.',
          )
        else
          ...lists.map(_buildShoppingListCard),
      ],
    );
  }

  Widget _buildShoppingListCard(
      ShoppingList list,
      ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final openItems =
    list.items.where((item) => !item.done).toList();

    final preview = openItems
        .take(3)
        .map((item) => item.name)
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: () => widget.onNavigate(1),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius:
                    BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.list_alt_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        list.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${openItems.length} offen'
                            '${preview.isEmpty ? '' : ' • $preview'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  Widget _sectionTitle(
      String title, {
        required IconData icon,
      }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 21,
          color: colors.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 21,
          color: colors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: const Text('Alle'),
        ),
      ],
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String text,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: colors.primary,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 16,
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _CelebrationOverlay extends StatelessWidget {
  const _CelebrationOverlay({
    required this.animation,
  });

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = Curves.easeOut.transform(
          animation.value,
        );
        final fade = 1 -
            Curves.easeIn.transform(
              (animation.value - 0.65)
                  .clamp(0.0, 1.0),
            );

        return Opacity(
          opacity: fade,
          child: Stack(
            children: [
              Positioned(
                top: 95 - (value * 35),
                left: 24 + (value * 18),
                child: _sparkle(
                  '✨',
                  30,
                  value,
                ),
              ),
              Positioned(
                top: 135 - (value * 55),
                right: 28 + (value * 12),
                child: _sparkle(
                  '⭐',
                  25,
                  value,
                ),
              ),
              Positioned(
                top: 225 - (value * 70),
                left: 82,
                child: _sparkle(
                  '✦',
                  24,
                  value,
                ),
              ),
              Positioned(
                top: 260 - (value * 45),
                right: 80,
                child: _sparkle(
                  '✨',
                  22,
                  value,
                ),
              ),
              Align(
                alignment: const Alignment(0, -0.3),
                child: Transform.scale(
                  scale: 0.85 + (value * 0.15),
                  child: Opacity(
                    opacity: animation.value < 0.12
                        ? animation.value / 0.12
                        : fade,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius:
                        BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 22,
                            color: colors.shadow.withValues(
                              alpha: 0.18,
                            ),
                          ),
                        ],
                      ),
                      child: Text(
                        '✨ Alles geschafft – stark! ✨',
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sparkle(
      String symbol,
      double size,
      double value,
      ) {
    return Transform.rotate(
      angle: value * 1.4,
      child: Transform.scale(
        scale: 0.6 + (value * 0.6),
        child: Text(
          symbol,
          style: TextStyle(fontSize: size),
        ),
      ),
    );
  }
}

class _HomeMood {
  const _HomeMood({
    required this.greeting,
    required this.emoji,
    required this.message,
  });

  final String greeting;
  final String emoji;
  final String message;
}
