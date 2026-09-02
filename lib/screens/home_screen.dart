import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../database_service.dart';
import '../services/cache_service.dart';
import '../utils/adaptive_dialogs.dart';
import '../widgets/app_widgets.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_view.dart';
import '../widgets/water_card.dart';
import 'goals_screen.dart';
import 'static/colors.dart';

class HomeScreen extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const HomeScreen({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isToday => widget.selectedDate == _today();

  @override
  void initState() {
    super.initState();
    _loadSummary();
    // This tab is kept alive, so it won't rebuild on switch. Listen for cache
    // invalidations (e.g. food logged on the Log tab) and refetch when the
    // affected day is the one we're showing.
    CacheService.instance.revision.addListener(_onCacheInvalidated);
  }

  @override
  void dispose() {
    CacheService.instance.revision.removeListener(_onCacheInvalidated);
    super.dispose();
  }

  void _onCacheInvalidated() {
    if (!mounted) return;
    if (CacheService.instance.lastInvalidatedDate == widget.selectedDate) {
      _loadSummary();
    }
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (old.selectedDate != widget.selectedDate) {
      _loadSummary();
    }
  }

  Future<void> _loadSummary({bool forceRefresh = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await DatabaseService.getDailySummary(
        uid,
        date: widget.selectedDate,
        forceRefresh: forceRefresh,
      );
      if (mounted)
        setState(() {
          _summary = data;
          _loading = false;
        });
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
    final candidate = widget.selectedDate.subtract(const Duration(days: 1));
    if (!candidate.isBefore(earliest)) widget.onDateChanged(candidate);
  }

  void _goForward() {
    widget.onDateChanged(widget.selectedDate.add(const Duration(days: 1)));
  }

  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showAdaptiveDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      firstDate: today.subtract(const Duration(days: 90)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) {
      widget.onDateChanged(DateTime(picked.year, picked.month, picked.day));
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
    final d = widget.selectedDate;
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadSummary(forceRefresh: true),
        child: CustomScrollView(
          slivers: [
            // Greeting banner
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'MacroScan',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    // Text(
                    //   _isToday ? "Your food log" : 'Your food log',
                    //   style: tt.labelMedium?.copyWith(
                    //     color: cs.primary,
                    //     fontWeight: FontWeight.w700,
                    //     letterSpacing: 1.0,
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),

            // Date navigator
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: DateNavigator(
                  label: _formatDate(),
                  canGoBack: !widget.selectedDate
                      .subtract(const Duration(days: 1))
                      .isBefore(_today().subtract(const Duration(days: 90))),
                  onBack: _goBack,
                  onForward: _goForward,
                  onTapLabel: _pickDate,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

            // Summary card
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              sliver: SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeInOut,
                  child: _buildSummaryCard(context),
                ),
              ),
            ),

            // Water card
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              sliver: SliverToBoxAdapter(
                child: WaterCard(selectedDate: widget.selectedDate),
              ),
            ),

            // Testing new button
            // const SliverPadding(
            //   padding: EdgeInsets.fromLTRB(
            //     AppSpacing.lg,
            //     0,
            //     AppSpacing.lg,
            //     AppSpacing.lg,
            //   ),
            //   sliver: SliverToBoxAdapter(
            //     child: CustomButton(
            //       text: 'test new button',
            //       horizontalPadding: 10,
            //       verticalPadding: 20,
            //     ),
            //   ),
            // ),

            // Jump to Today
            if (!_isToday)
              SliverToBoxAdapter(
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => widget.onDateChanged(_today()),
                    icon: const Icon(Icons.today_rounded, size: 18),
                    label: const Text('Jump to Today'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return AppCard(
        key: const ValueKey('loading'),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: LoadingView(size: 120),
        ),
      );
    }

    if (_error != null) {
      return AppCard(
        key: const ValueKey('error'),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              semanticLabel: 'Error',
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }

    final goals = _summary?['goals'] as Map<String, dynamic>? ?? {};
    final consumed = _summary?['consumed'] as Map<String, dynamic>? ?? {};
    final goalsSet = goals['calories'] != null;

    final cardTitle = _isToday
        ? "Today's Progress"
        : 'Progress · ${_formatDate()}';

    return AppCard(
      key: ValueKey('data-${widget.selectedDate.toIso8601String()}'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isToday ? Icons.today_rounded : Icons.calendar_today_outlined,
                size: 18,
                color: cs.primary,
                semanticLabel: 'Progress',
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                cardTitle,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          if (!goalsSet) ...[
            EmptyState(
              icon: Icons.flag_outlined,
              message: 'No goals set yet',
              subMessage:
                  'Set your daily nutrition goals to start tracking progress.',
              action: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoalsScreen()),
                ).then((_) => _loadSummary()),
                icon: const Icon(
                  Icons.add,
                  size: 18,
                  semanticLabel: 'Set goals',
                ),
                label: const Text('Set Your Goals'),
                style: FilledButton.styleFrom(minimumSize: const Size(180, 44)),
              ),
            ),
          ] else ...[
            ProgressRow(
              label: 'Calories',
              unit: 'kcal',
              consumed: (consumed['calories'] as num?)?.toInt() ?? 0,
              goal: (goals['calories'] as num).toInt(),
              fillColor: AppColors.calories,
            ),
            const SizedBox(height: AppSpacing.md),
            ProgressRow(
              label: 'Protein',
              unit: 'g',
              consumed: (consumed['protein'] as num?)?.toInt() ?? 0,
              goal: (goals['protein'] as num).toInt(),
              fillColor: AppColors.protein,
            ),
            const SizedBox(height: AppSpacing.md),
            ProgressRow(
              label: 'Carbs',
              unit: 'g',
              consumed: (consumed['carbs'] as num?)?.toInt() ?? 0,
              goal: (goals['carbs'] as num).toInt(),
              fillColor: AppColors.carbs,
            ),
            const SizedBox(height: AppSpacing.md),
            ProgressRow(
              label: 'Fat',
              unit: 'g',
              consumed: (consumed['fat'] as num?)?.toInt() ?? 0,
              goal: (goals['fat'] as num).toInt(),
              fillColor: AppColors.fat,
            ),
          ],
        ],
      ),
    );
  }
}

