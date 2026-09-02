import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../database_service.dart';
import '../services/cache_service.dart';
import '../utils/adaptive_dialogs.dart';
import '../widgets/app_widgets.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_view.dart';
import 'barcode_scan_screen.dart';
import 'edit_food_log_screen.dart';
import 'food_detail_screen.dart';
import 'meal_scan_screen.dart';
import 'static/colors.dart';

// ── Log Screen ────────────────────────────────────────────────────────────────
class LogScreen extends StatefulWidget {
  final DateTime logDate;
  final ValueChanged<DateTime> onLogDateChanged;

  const LogScreen({
    super.key,
    required this.logDate,
    required this.onLogDateChanged,
  });

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen>
    with AutomaticKeepAliveClientMixin {
  List<FoodLogEntry> _entries = [];
  bool _loading = true;
  String? _error;
  bool _showAddPanel = false;

  static const _meals = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  bool get wantKeepAlive => true;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isToday => widget.logDate == _today();

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  @override
  void didUpdateWidget(LogScreen old) {
    super.didUpdateWidget(old);
    if (old.logDate != widget.logDate) _loadLog();
  }

  Future<void> _loadLog({bool forceRefresh = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    setState(() {
      // Only blank to the full-screen spinner when there's nothing to show yet.
      // Refreshes/date changes update the list in place, which also avoids two
      // AnimatedSwitcher children briefly sharing the 'loading' key.
      _loading = _entries.isEmpty;
      _error = null;
    });
    try {
      final entries = await DatabaseService.getFoodLog(
        uid,
        date: widget.logDate,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _entries = entries;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  void _goBack() {
    final earliest = _today().subtract(const Duration(days: 90));
    final candidate = widget.logDate.subtract(const Duration(days: 1));
    if (!candidate.isBefore(earliest)) widget.onLogDateChanged(candidate);
  }

  void _goForward() {
    widget.onLogDateChanged(widget.logDate.add(const Duration(days: 1)));
  }

  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showAdaptiveDatePicker(
      context: context,
      initialDate: widget.logDate,
      firstDate: today.subtract(const Duration(days: 90)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) {
      widget.onLogDateChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  String _formatDate() {
    if (_isToday) return 'Today';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final d = widget.logDate;
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  String get _fabLabel =>
      _isToday ? 'Add Food for Today' : 'Add Food for ${_formatDate()}';

  List<FoodLogEntry> _entriesForMeal(String meal) =>
      _entries.where((e) => e.meal == meal.toLowerCase()).toList();

  // ── Add panel ──────────────────────────────────────────────────────────────

  void _openAddPanel() => setState(() => _showAddPanel = true);
  void _closeAddPanel() => setState(() => _showAddPanel = false);

  void _openFoodSearch() {
    _closeAddPanel();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _FoodSearchSheet(
          onFoodSelected: (food) {
            Navigator.of(sheetContext, rootNavigator: true)
                .push(
                  MaterialPageRoute(
                    builder: (_) =>
                        FoodDetailScreen(food: food, logDate: widget.logDate),
                  ),
                )
                .then((_) => _loadLog());
          },
        ),
      ).then((_) => _loadLog());
    });
  }

  void _openBarcodeScanner() {
    _closeAddPanel();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BarcodeScanScreen(logDate: widget.logDate),
        ),
      );
    });
  }

  void _openMealScan() {
    _closeAddPanel();
    Future.delayed(const Duration(milliseconds: 180), () async {
      if (!mounted) return;
      final added = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MealScanScreen(logDate: widget.logDate),
        ),
      );
      if (added == true && mounted) {
        await _invalidateLogDate();
        _loadLog();
      }
    });
  }

  Widget _buildAddPanel() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final panelHeight = MediaQuery.sizeOf(context).height * 0.42;

    return SizedBox(
      height: panelHeight,
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        elevation: 16,
        shadowColor: Colors.black26,
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(0),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Text(
                'Add Food',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),

            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),

            // Search Food
            Expanded(
              child: InkWell(
                onTap: _openFoodSearch,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.noCurve),
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: cs.primary,
                        semanticLabel: 'Search food',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'Search Food',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),

            // Scan Barcode
            Expanded(
              child: InkWell(
                onTap: _openBarcodeScanner,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.noCurve),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 22,
                        color: cs.primary,
                        semanticLabel: 'Scan barcode',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'Scan Barcode',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),

            // Scan Meal Photo — disabled until the FatSecret Image Recognition
            // add-on is enabled on the backend. The screen + backend route are
            // still wired up; flip `onTap` back to `_openMealScan` to re-enable.
            Expanded(
              child: InkWell(
                onTap: null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.noCurve),
                      ),
                      child: Icon(
                        Icons.photo_camera_rounded,
                        size: 22,
                        color: cs.onSurface.withValues(alpha: 0.35),
                        semanticLabel: 'Scan meal photo (coming soon)',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'Scan Meal Photo',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '(Coming Soon)',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.45),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit / delete ──────────────────────────────────────────────────────────

  Future<void> _openEdit(FoodLogEntry entry) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditFoodLogScreen(entry: entry)),
    );
    if (changed == true) {
      await _invalidateLogDate();
      _loadLog();
    }
  }

  Future<void> _invalidateLogDate() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await CacheService.instance.invalidateDate(uid, widget.logDate);
    }
  }

  Future<void> _deleteEntry(FoodLogEntry entry) async {
    // Dismissible requires the widget to be gone from the tree on the next
    // build, so remove the entry synchronously before awaiting the network
    // DELETE. On failure we reload to restore the real state.
    setState(() {
      _entries = _entries.where((e) => e.id != entry.id).toList();
    });
    try {
      await DatabaseService.deleteFoodLogEntry(entry.id);
      await _invalidateLogDate();
      _loadLog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
        _loadLog(forceRefresh: true);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Stack(
        children: [
          // ── Main content ─────────────────────────────────────────────────
          RefreshIndicator(
            onRefresh: () => _loadLog(forceRefresh: true),
            child: Column(
              children: [
                DateNavigator(
                  label: _formatDate(),
                  canGoBack: !widget.logDate
                      .subtract(const Duration(days: 1))
                      .isBefore(_today().subtract(const Duration(days: 90))),
                  onBack: _goBack,
                  onForward: _goForward,
                  onTapLabel: _pickDate,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _loading
                        ? const LoadingView(key: ValueKey('loading'))
                        : _error != null
                        ? Center(
                            key: const ValueKey('error'),
                            child: EmptyState(
                              icon: Icons.error_outline,
                              message: 'Failed to load log',
                              subMessage: _error,
                            ),
                          )
                        : _buildLogList(),
                  ),
                ),
              ],
            ),
          ),

          // ── FAB ──────────────────────────────────────────────────────────
          if (!_showAddPanel)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: CustomButton(
                  text: _fabLabel,
                  width: 260,
                  horizontalPadding: 10,
                  verticalPadding: 5,
                  onPressed: _openAddPanel,
                ),
              ),
            ),

          // ── Scrim ─────────────────────────────────────────────────────────
          AnimatedOpacity(
            opacity: _showAddPanel ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            child: IgnorePointer(
              ignoring: !_showAddPanel,
              child: GestureDetector(
                onTap: _closeAddPanel,
                child: Container(color: Colors.black38),
              ),
            ),
          ),

          // ── Add panel ─────────────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              offset: _showAddPanel ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: _buildAddPanel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    final totalCals = _entries.fold<double>(0, (s, e) => s + e.calories);

    // Give each meal card a minimum height derived from the viewport so the four
    // cards fill the screen on light days. Cards still grow with their content,
    // and the ListView scrolls on busy days (keeping pull-to-refresh working).
    return LayoutBuilder(
      key: const ValueKey('list'),
      builder: (context, constraints) {
        final cardMinHeight = ((constraints.maxHeight - 120) / _meals.length)
            .clamp(80.0, 400.0);
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // Daily total banner
            if (_entries.isNotEmpty)
              _DailyTotalBanner(totalCalories: totalCals),

            ..._meals.map((meal) {
              final entries = _entriesForMeal(meal);
              final totalCal = entries.fold<double>(
                0,
                (sum, e) => sum + e.calories,
              );
              return _MealSection(
                meal: meal,
                entries: entries,
                totalCal: totalCal,
                minCardHeight: cardMinHeight,
                onTap: _openEdit,
                onDismiss: _deleteEntry,
              );
            }),
          ],
        );
      },
    );
  }
}

// ── Daily total banner ────────────────────────────────────────────────────────
class _DailyTotalBanner extends StatelessWidget {
  final double totalCalories;

  const _DailyTotalBanner({required this.totalCalories});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.noCurve),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: const Color(0xFFE65100),
            size: 20,
            semanticLabel: 'Total calories',
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Total today:',
            style: tt.bodyMedium?.copyWith(
              color: cs.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
          const Spacer(),
          Text(
            '${totalCalories.toStringAsFixed(0)} kcal',
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meal section ──────────────────────────────────────────────────────────────
class _MealSection extends StatelessWidget {
  final String meal;
  final List<FoodLogEntry> entries;
  final double totalCal;
  final double minCardHeight;
  final void Function(FoodLogEntry) onTap;
  final void Function(FoodLogEntry) onDismiss;

  const _MealSection({
    required this.meal,
    required this.entries,
    required this.totalCal,
    required this.onTap,
    required this.onDismiss,
    this.minCardHeight = 0,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Text(
                  meal,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                if (entries.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(AppRadius.noCurve),
                    ),
                    child: Text(
                      'Meal Total: ${totalCal.toStringAsFixed(0)} kcal',
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minCardHeight),
            child: AppCard(
              padding: EdgeInsets.zero,
              elevation: entries.isEmpty ? 0 : 1,
              child: entries.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 16,
                            color: cs.onSurface.withValues(alpha: 0.3),
                            semanticLabel: 'Nothing logged',
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Nothing logged',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: entries.mapIndexed((index, entry) {
                        return Dismissible(
                          key: Key('log_${entry.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: index == 0 && entries.length == 1
                                  ? BorderRadius.circular(AppRadius.noCurve)
                                  : index == 0
                                  ? const BorderRadius.vertical(
                                      top: Radius.circular(AppRadius.noCurve),
                                    )
                                  : index == entries.length - 1
                                  ? const BorderRadius.vertical(
                                      bottom: Radius.circular(
                                        AppRadius.noCurve,
                                      ),
                                    )
                                  : BorderRadius.zero,
                            ),
                            child: const Icon(
                              Icons.delete_rounded,
                              color: Colors.white,
                              semanticLabel: 'Delete entry',
                            ),
                          ),
                          onDismissed: (_) => onDismiss(entry),
                          child: InkWell(
                            onTap: () => onTap(entry),
                            borderRadius: BorderRadius.circular(
                              AppRadius.noCurve,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.md,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.foodName,
                                          style: tt.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        _LogEntryMacros(entry: entry),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: cs.onSurface.withValues(alpha: 0.3),
                                    semanticLabel: 'Edit entry',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

// ── Log entry macros chips ─────────────────────────────────────────────────────
class _LogEntryMacros extends StatelessWidget {
  final FoodLogEntry entry;
  const _LogEntryMacros({required this.entry});

  String _fmt(double v) => v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) => Text(
            '${entry.servingQty} × ${entry.servingUnit}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.60),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            MacroChip(
              label: '${_fmt(entry.calories)} kcal',
              color: AppColors.calories,
            ),
            MacroChip(label: 'C ${_fmt(entry.carbs)}g', color: AppColors.carbs),
            MacroChip(label: 'F ${_fmt(entry.fats)}g', color: AppColors.fat),
            MacroChip(
              label: 'P ${_fmt(entry.protein)}g',
              color: AppColors.protein,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Food search bottom sheet ───────────────────────────────────────────────────
class _FoodSearchSheet extends StatefulWidget {
  final void Function(FoodResult) onFoodSelected;
  const _FoodSearchSheet({required this.onFoodSelected});

  @override
  State<_FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends State<_FoodSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  List<FoodResult> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _debounce?.cancel();
    final query = _controller.text.trim();

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final id = ++_requestId;
      try {
        final results = await DatabaseService.searchFoods(query);
        if (mounted && id == _requestId) {
          setState(() {
            _results = results;
            _loading = false;
          });
        }
      } catch (e) {
        if (mounted && id == _requestId) {
          setState(() {
            _error = e.toString();
            _loading = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        bottomInset + AppSpacing.lg,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Text(
                'Search Food',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  semanticLabel: 'Close search',
                ),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search food...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                semanticLabel: 'Search',
              ),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: AdaptiveActivityIndicator(strokeWidth: 2),
                      ),
                    )
                  : _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        semanticLabel: 'Clear search',
                      ),
                      onPressed: () {
                        _controller.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _error != null
                  ? EmptyState(
                      key: const ValueKey('error'),
                      icon: Icons.error_outline,
                      message: 'Search failed',
                      subMessage: _error,
                    )
                  : _results.isEmpty
                  ? EmptyState(
                      key: const ValueKey('empty'),
                      icon: _controller.text.isEmpty
                          ? Icons.search_rounded
                          : Icons.search_off_rounded,
                      message: _controller.text.isEmpty
                          ? 'Start typing to search'
                          : 'No results found',
                      subMessage: _controller.text.isEmpty
                          ? null
                          : 'Try a different search term',
                    )
                  : ListView.separated(
                      key: const ValueKey('results'),
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.4),
                        indent: AppSpacing.lg,
                        endIndent: AppSpacing.lg,
                      ),
                      itemBuilder: (context, i) {
                        final food = _results[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.xs,
                          ),
                          title: Text(
                            food.displayName,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _SearchResultMacros(food: food),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: cs.onSurface.withValues(alpha: 0.3),
                            semanticLabel: 'Select food',
                          ),
                          onTap: () => widget.onFoodSelected(food),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search result macros ───────────────────────────────────────────────────────
class _SearchResultMacros extends StatelessWidget {
  final FoodResult food;
  const _SearchResultMacros({required this.food});

  String _fmt(double? v) => v != null ? v.toStringAsFixed(1) : '–';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (food.servingDesc != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Builder(
              builder: (context) => Text(
                food.servingDesc!,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            MacroChip(
              label: '${_fmt(food.calories)} kcal',
              color: AppColors.calories,
            ),
            MacroChip(label: 'C ${_fmt(food.carbs)}g', color: AppColors.carbs),
            MacroChip(label: 'F ${_fmt(food.fat)}g', color: AppColors.fat),
            MacroChip(
              label: 'P ${_fmt(food.protein)}g',
              color: AppColors.protein,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Extension for mapIndexed ───────────────────────────────────────────────────
extension _IterableIndexed<T> on List<T> {
  List<R> mapIndexed<R>(R Function(int index, T item) f) {
    final result = <R>[];
    for (var i = 0; i < length; i++) {
      result.add(f(i, this[i]));
    }
    return result;
  }
}
