import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';

class CreateEditHabitScreen extends ConsumerStatefulWidget {
  final Habit? habit;
  const CreateEditHabitScreen({super.key, this.habit});

  @override
  ConsumerState<CreateEditHabitScreen> createState() =>
      _CreateEditHabitScreenState();
}

class _CreateEditHabitScreenState extends ConsumerState<CreateEditHabitScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _intervalController;
  late TextEditingController _customLabelController;

  String _selectedCategory = AppConstants.catWater;
  bool _isCustomCategory = false;
  String _selectedRecurrence = 'Daily';
  String _intervalUnit = 'Minutes';
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  List<int> _customDays = [];
  int _hourlyInterval = 2;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<String> _recurrences = [
    'Once',
    'Daily',
    'Weekdays',
    'Weekends',
    'CustomDays',
    'Hourly',
    'CustomInterval',
  ];
  final List<String> _recurrenceLabels = [
    'Once',
    'Daily',
    'Weekdays',
    'Weekends',
    'Custom',
    'Hourly',
    'Interval',
  ];
  final List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.habit?.title ?? '');
    _descController = TextEditingController(
      text: widget.habit?.description ?? '',
    );
    _intervalController = TextEditingController(text: '5');
    _customLabelController = TextEditingController();

    if (widget.habit != null) {
      _selectedCategory = widget.habit!.category;
      // Detect if category is custom (not in standard list)
      _isCustomCategory = !AppConstants.categories
          .where((c) => c != AppConstants.catCustom)
          .contains(_selectedCategory);
      if (_isCustomCategory) {
        _customLabelController.text = _selectedCategory;
        _selectedCategory = AppConstants.catCustom;
      }
      _selectedRecurrence = widget.habit!.recurrenceType;
      _customDays = List.from(widget.habit!.customDays);
      _hourlyInterval = widget.habit!.hourlyInterval;
      final parts = widget.habit!.timeOfDay.split(':');
      _selectedTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );

      if (widget.habit!.recurrenceType == 'CustomInterval') {
        if (widget.habit!.intervalSeconds % 60 == 0) {
          _intervalUnit = 'Minutes';
          _intervalController.text = (widget.habit!.intervalSeconds ~/ 60)
              .toString();
        } else {
          _intervalUnit = 'Seconds';
          _intervalController.text = widget.habit!.intervalSeconds.toString();
        }
      }
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _intervalController.dispose();
    _customLabelController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _saveHabit() {
    if (!_formKey.currentState!.validate()) return;
    final formattedTime =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final int notifId =
        widget.habit?.notificationId ?? Random().nextInt(1000000);

    int intervalSecs = 0;
    if (_selectedRecurrence == 'CustomInterval') {
      final val = int.tryParse(_intervalController.text.trim()) ?? 30;
      intervalSecs = _intervalUnit == 'Minutes' ? val * 60 : val;
    }

    // Resolve the actual category: if Custom, use the typed label
    final String resolvedCategory =
        _isCustomCategory && _customLabelController.text.trim().isNotEmpty
        ? _customLabelController.text.trim()
        : _selectedCategory;

    final habitData = Habit(
      id: widget.habit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: resolvedCategory,
      timeOfDay: formattedTime,
      recurrenceType: _selectedRecurrence,
      customDays: _customDays,
      hourlyInterval: _hourlyInterval,
      notificationId: notifId,
      isEnabled: widget.habit?.isEnabled ?? true,
      createdAt: widget.habit?.createdAt ?? DateTime.now(),
      completedDates: widget.habit?.completedDates ?? [],
      currentStreak: widget.habit?.currentStreak ?? 0,
      longestStreak: widget.habit?.longestStreak ?? 0,
      intervalSeconds: intervalSecs,
      skippedDates: widget.habit?.skippedDates ?? [],
    );

    final notifier = ref.read(habitNotifierProvider.notifier);
    if (widget.habit == null) {
      notifier.addHabit(habitData);
    } else {
      notifier.updateHabit(habitData);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppConstants.getCategoryColor(_selectedCategory);
    final icon = AppConstants.getCategoryIcon(_selectedCategory);
    final isEditing = widget.habit != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              // ── Animated Hero Header ──────────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.85),
                          color.withValues(alpha: 0.4),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              key: ValueKey(_selectedCategory),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, size: 44, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isEditing ? 'Edit Habit' : 'New Habit',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Form Body ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Description
                      _sectionLabel('Details'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _inputDeco(
                          theme,
                          'Habit Title',
                          Icons.title_rounded,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Title is required'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _inputDeco(
                          theme,
                          'Description (optional)',
                          Icons.notes_rounded,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Category picker
                      _sectionLabel('Category'),
                      const SizedBox(height: 12),
                      _buildCategoryGrid(theme),

                      // Custom category label field (animated)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: _isCustomCategory
                            ? Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: TextFormField(
                                  controller: _customLabelController,
                                  textCapitalization: TextCapitalization.words,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration:
                                      _inputDeco(
                                        theme,
                                        'Name your habit type…',
                                        Icons.auto_awesome_rounded,
                                      ).copyWith(
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE91E8C),
                                            width: 2,
                                          ),
                                        ),
                                        labelStyle: const TextStyle(
                                          color: Color(0xFFE91E8C),
                                        ),
                                      ),
                                  validator: (v) {
                                    if (_isCustomCategory &&
                                        (v == null || v.trim().isEmpty)) {
                                      return 'Please name your custom habit type';
                                    }
                                    return null;
                                  },
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 32),

                      // Recurrence
                      _sectionLabel('Repeat Schedule'),
                      const SizedBox(height: 12),
                      _buildRecurrencePills(theme, color),

                      // Custom days
                      if (_selectedRecurrence == 'CustomDays') ...[
                        const SizedBox(height: 16),
                        _buildCustomDaysPicker(theme, color),
                      ],

                      // Hourly interval
                      if (_selectedRecurrence == 'Hourly') ...[
                        const SizedBox(height: 16),
                        _buildHourlySlider(theme, color),
                      ],

                      // Custom trigger interval (Minutes/Seconds)
                      if (_selectedRecurrence == 'CustomInterval') ...[
                        const SizedBox(height: 16),
                        _buildCustomIntervalPicker(theme, color),
                      ],

                      const SizedBox(height: 32),

                      // Time picker (only for non-interval triggers)
                      if (_selectedRecurrence != 'CustomInterval') ...[
                        _sectionLabel('Reminder Time'),
                        const SizedBox(height: 12),
                        _buildTimeTile(theme, color),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Floating Save Button ──────────────────────────────────────────
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: Icon(
                isEditing ? Icons.save_rounded : Icons.add_task_rounded,
                color: Colors.white,
              ),
              label: Text(
                isEditing ? 'Save Changes' : 'Create Habit',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              onPressed: _saveHabit,
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
  );

  InputDecoration _inputDeco(ThemeData theme, String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppConstants.getCategoryColor(_selectedCategory),
            width: 1.5,
          ),
        ),
      );

  Widget _buildCategoryGrid(ThemeData theme) {
    const categories = AppConstants.categories;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: categories.map((cat) {
        final catColor = AppConstants.getCategoryColor(cat);
        final catIcon = AppConstants.getCategoryIcon(cat);
        final selected = _selectedCategory == cat;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? catColor.withValues(alpha: 0.15)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: selected
                    ? catColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  catIcon,
                  size: 16,
                  color: selected
                      ? catColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  cat,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected
                        ? catColor
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecurrencePills(ThemeData theme, Color color) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_recurrences.length, (i) {
        final selected = _selectedRecurrence == _recurrences[i];
        return GestureDetector(
          onTap: () => setState(() => _selectedRecurrence = _recurrences[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? color
                  : theme.colorScheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: selected
                    ? color
                    : theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              _recurrenceLabels[i],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCustomDaysPicker(ThemeData theme, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select days',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final day = i + 1;
            final selected = _customDays.contains(day);
            return GestureDetector(
              onTap: () => setState(() {
                selected ? _customDays.remove(day) : _customDays.add(day);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? color
                      : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? color
                        : theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    _dayLabels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? Colors.white
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildHourlySlider(ThemeData theme, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Every $_hourlyInterval hour${_hourlyInterval > 1 ? 's' : ''}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Slider(
          value: _hourlyInterval.toDouble(),
          min: 1,
          max: 12,
          divisions: 11,
          activeColor: color,
          label: '$_hourlyInterval h',
          onChanged: (v) => setState(() => _hourlyInterval = v.round()),
        ),
      ],
    );
  }

  Widget _buildCustomIntervalPicker(ThemeData theme, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trigger Interval',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _intervalController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _inputDeco(theme, 'Value', Icons.timer_outlined),
                validator: (v) {
                  if (_selectedRecurrence != 'CustomInterval') return null;
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final val = int.tryParse(v.trim());
                  if (val == null) return 'Must be a number';
                  if (_intervalUnit == 'Seconds' && val < 30) {
                    return 'Min 30s';
                  }
                  if (_intervalUnit == 'Minutes' && val < 1) {
                    return 'Min 1m';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                initialValue: _intervalUnit,
                decoration: _inputDeco(theme, 'Unit', Icons.tune_rounded),
                items: ['Minutes', 'Seconds']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _intervalUnit = v;
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeTile(ThemeData theme, Color color) {
    final formattedTime = _selectedTime.format(context);
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: _selectedTime,
        );
        if (time != null) setState(() => _selectedTime = time);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.alarm_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminder at',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
