import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../database_service.dart';
import '../services/cache_service.dart';
import '../services/water_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/dropdown.dart';
import '../widgets/loading_view.dart';
import 'static/colors.dart';
import '../widgets/custom_button.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  UserGoals? _goals;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  late TextEditingController _goalWeightController;
  late TextEditingController _waterGoalController;

  String? _selectedWeeklyGoal;
  String? _selectedActivityLevel;
  WaterUnit _waterUnit = WaterUnit.ml;

  static const _waterUnitOptions = [
    (WaterUnit.ml, 'Millilitres (ml)'),
    (WaterUnit.flOz, 'Fluid ounces (fl oz)'),
    (WaterUnit.cup, 'Cups'),
  ];

  ({int calories, int protein, int carbs, int fat})? _savedTargets;

  static const _weeklyGoalOptions = [
    ('lose_2', 'Lose 2 lbs/week'),
    ('lose_1_5', 'Lose 1.5 lbs/week'),
    ('lose_1', 'Lose 1 lb/week'),
    ('lose_0_5', 'Lose 0.5 lbs/week'),
    ('maintain', 'Maintain weight'),
    ('gain_0_5', 'Gain 0.5 lbs/week'),
    ('gain_1', 'Gain 1 lb/week'),
  ];

  static const _activityOptions = [
    ('sedentary', 'Sedentary (little or no exercise)'),
    ('lightly_active', 'Lightly Active (1–3 days/week)'),
    ('moderately_active', 'Moderately Active (3–5 days/week)'),
    ('very_active', 'Very Active (6–7 days/week)'),
  ];

  static const _activityIcons = {
    'sedentary': Icons.weekend_rounded,
    'lightly_active': Icons.directions_walk_rounded,
    'moderately_active': Icons.directions_bike_rounded,
    'very_active': Icons.fitness_center_rounded,
  };

  static const _activityShortLabels = {
    'sedentary': 'Sedentary',
    'lightly_active': 'Lightly Active',
    'moderately_active': 'Moderately Active',
    'very_active': 'Very Active',
  };

  static const _activitySubLabels = {
    'sedentary': 'Little/no exercise',
    'lightly_active': '1–3 days/week',
    'moderately_active': '3–5 days/week',
    'very_active': '6–7 days/week',
  };

  static const _activityMultipliers = {
    'sedentary': 1.2,
    'lightly_active': 1.375,
    'moderately_active': 1.55,
    'very_active': 1.725,
  };

  static const _weeklyAdjustments = {
    'lose_2': -1000,
    'lose_1_5': -750,
    'lose_1': -500,
    'lose_0_5': -250,
    'maintain': 0,
    'gain_0_5': 250,
    'gain_1': 500,
  };

  @override
  void initState() {
    super.initState();
    _goalWeightController = TextEditingController();
    _waterGoalController = TextEditingController();
    _loadGoals();
  }

  @override
  void dispose() {
    _goalWeightController.dispose();
    _waterGoalController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    // Water is stored on the device, so it loads independently of the server
    // round-trip below and still shows if the backend is unreachable.
    await waterService.loadFor(uid);
    _waterUnit = waterService.unit;
    _waterGoalController.text = _waterUnit.format(
      _waterUnit.fromMl(waterService.goalMl),
    );

    try {
      final results = await Future.wait([
        DatabaseService.getGoals(uid),
        DatabaseService.getUserProfile(uid: uid),
      ]);
      final goals = results[0] as UserGoals;
      final profile = results[1] as Map<String, dynamic>;

      setState(() {
        _goals = goals;
        _profile = profile;
        _loading = false;

        if (goals.goalWeightLbs != null) {
          final gw = goals.goalWeightLbs!;
          _goalWeightController.text = gw % 1 == 0
              ? gw.toInt().toString()
              : gw.toString();
        }
        // Validate loaded values exist in the options lists to prevent
        // DropdownButtonFormField duplicate-key / mismatched-value errors.
        _selectedWeeklyGoal =
            _weeklyGoalOptions.any((o) => o.$1 == goals.weeklyGoal)
            ? goals.weeklyGoal
            : null;
        _selectedActivityLevel =
            _activityOptions.any((o) => o.$1 == goals.activityLevel)
            ? goals.activityLevel
            : null;

        if (goals.calorieGoal != null) {
          _savedTargets = (
            calories: goals.calorieGoal!,
            protein: goals.proteinGoal ?? 0,
            carbs: goals.carbsGoal ?? 0,
            fat: goals.fatGoal ?? 0,
          );
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  ({int calories, int protein, int carbs, int fat})? _computePreview() {
    if (_selectedWeeklyGoal == null || _selectedActivityLevel == null) {
      return null;
    }
    final p = _profile;
    if (p == null) return null;

    final weightLbs = double.tryParse(p['weight_lbs']?.toString() ?? '');
    final heightFt = int.tryParse(p['height_ft']?.toString() ?? '');
    final heightIn = int.tryParse(p['height_in']?.toString() ?? '') ?? 0;
    final sex = p['sex'] as String?;
    final dob = p['date_of_birth'] as String?;

    if (weightLbs == null || heightFt == null || sex == null || dob == null) {
      return null;
    }

    final weightKg = weightLbs * 0.453592;
    final heightCm = ((heightFt * 12) + heightIn) * 2.54;

    final dobDate = DateTime.tryParse(dob);
    if (dobDate == null) return null;
    final today = DateTime.now();
    int age = today.year - dobDate.year;
    if (today.isBefore(DateTime(today.year, dobDate.month, dobDate.day))) age--;

    final bmr = sex == 'male'
        ? (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5
        : (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;

    final tdee = bmr * (_activityMultipliers[_selectedActivityLevel] ?? 1.2);
    final adjustment = _weeklyAdjustments[_selectedWeeklyGoal] ?? 0;

    int calorieGoal = (tdee + adjustment).round();
    calorieGoal = calorieGoal.clamp(sex == 'male' ? 1500 : 1200, 9999);

    return (
      calories: calorieGoal,
      protein: ((calorieGoal * 0.25) / 4).round(),
      carbs: ((calorieGoal * 0.50) / 4).round(),
      fat: ((calorieGoal * 0.25) / 9).round(),
    );
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Persist the water settings first. They're device-local and can't fail, and
    // the server-backed validations below return early — so doing this after
    // them would block a user who only wanted to change their water goal.
    await waterService.setUnit(_waterUnit);
    final waterGoal = double.tryParse(_waterGoalController.text.trim());
    if (waterGoal != null) {
      await waterService.setGoalMl(uid, _waterUnit.toMl(waterGoal));
    }
    if (!mounted) return;

    final goalWeight = double.tryParse(_goalWeightController.text.trim());
    if (goalWeight == null || goalWeight < 50 || goalWeight > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid goal weight (50–500 lbs)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedWeeklyGoal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a weekly goal'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedActivityLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an activity level'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await DatabaseService.saveGoals(
        uid: uid,
        goalWeight: goalWeight,
        weeklyGoal: _selectedWeeklyGoal!,
        activityLevel: _selectedActivityLevel!,
      );

      // New targets change both the cached goals and the daily summary — drop
      // them so Goals and the Home tab reload fresh on return.
      await CacheService.instance.invalidateGoals(uid);
      await CacheService.instance.invalidateDate(uid, DateTime.now());

      if (mounted) {
        setState(() {
          _savedTargets = (
            calories: saved.calorieGoal ?? 0,
            protein: saved.proteinGoal ?? 0,
            carbs: saved.carbsGoal ?? 0,
            fat: saved.fatGoal ?? 0,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goals saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  TextInputType get _keyboardType {
    if (kIsWeb) return TextInputType.number;
    if (Platform.isIOS) {
      return const TextInputType.numberWithOptions(decimal: true);
    }
    return const TextInputType.numberWithOptions(decimal: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingView());
    }

    final preview = _computePreview();
    final isSaved =
        preview != null &&
        _savedTargets != null &&
        preview.calories == _savedTargets!.calories &&
        preview.protein == _savedTargets!.protein &&
        preview.carbs == _savedTargets!.carbs &&
        preview.fat == _savedTargets!.fat;

    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Goals'),
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: AppCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        semanticLabel: 'Error',
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            SectionHeader(title: 'CURRENT WEIGHT'),
            const SizedBox(height: AppSpacing.sm),

            AppCard(
              child: Row(
                children: [
                  Icon(
                    Icons.monitor_weight_outlined,
                    color: cs.primary,
                    size: 20,
                    semanticLabel: 'Current weight',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _goals?.currentWeightLbs != null
                          ? '${_goals!.currentWeightLbs!.toStringAsFixed(1)} lbs'
                          : 'Not set — update your profile first',
                      style: tt.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _goals?.currentWeightLbs != null
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: 'GOAL WEIGHT'),
            const SizedBox(height: AppSpacing.sm),

            TextField(
              controller: _goalWeightController,
              keyboardType: _keyboardType,
              decoration: InputDecoration(
                hintText: '50 – 500 lbs',
                prefixIcon: const Icon(Icons.flag_outlined),
                suffixText: 'lbs',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: 'WEEKLY GOAL'),
            const SizedBox(height: AppSpacing.sm),

            AppDropdown<String>(
              options: _weeklyGoalOptions,
              value: _selectedWeeklyGoal,
              hint: 'Select a goal',
              prefixIcon: Icons.trending_up_rounded,
              onChanged: (v) => setState(() => _selectedWeeklyGoal = v),
            ),

            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: 'ACTIVITY LEVEL'),
            const SizedBox(height: AppSpacing.sm),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 2.4,
              children: _activityOptions.map((opt) {
                final isSelected = _selectedActivityLevel == opt.$1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedActivityLevel = opt.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primaryContainer : cs.surface,
                      borderRadius: BorderRadius.circular(AppRadius.noCurve),
                      border: Border.all(
                        color: isSelected ? cs.primary : cs.outlineVariant,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _activityIcons[opt.$1]!,
                          size: 26,
                          color: isSelected
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: AppSpacing.xl),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _activityShortLabels[opt.$1]!,
                                style: tt.labelMedium?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected ? cs.primary : cs.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _activitySubLabels[opt.$1]!,
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: 'HYDRATION'),
            const SizedBox(height: AppSpacing.sm),

            TextField(
              controller: _waterGoalController,
              keyboardType: _keyboardType,
              decoration: InputDecoration(
                hintText: 'Daily water goal',
                prefixIcon: const Icon(Icons.water_drop_outlined),
                suffixText: _waterUnit.label,
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: AppSpacing.md),

            AppDropdown<WaterUnit>(
              options: _waterUnitOptions,
              value: _waterUnit,
              hint: 'Select a unit',
              prefixIcon: Icons.straighten_rounded,
              onChanged: (u) => setState(() {
                // Re-express whatever is in the field in the new unit so the
                // number the user is looking at keeps meaning the same volume.
                final typed = double.tryParse(_waterGoalController.text.trim());
                final ml = typed != null
                    ? _waterUnit.toMl(typed)
                    : waterService.goalMl;
                _waterUnit = u;
                _waterGoalController.text = u.format(u.fromMl(ml));
              }),
            ),

            // Daily targets preview
            if (preview != null) ...[
              const SizedBox(height: AppSpacing.xl),

              Row(
                children: [
                  SectionHeader(title: 'DAILY TARGETS'),
                  if (!isSaved) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: 2,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  _GoalCard(
                    label: 'Calories',
                    value: '${preview.calories}',
                    unit: 'kcal',
                    color: AppColors.calories,
                    valueColor: AppColors.default_text_color,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _GoalCard(
                    label: 'Protein',
                    value: '${preview.protein}',
                    unit: 'g',
                    color: AppColors.protein,
                    valueColor: AppColors.default_text_color,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _GoalCard(
                    label: 'Carbs',
                    value: '${preview.carbs}',
                    unit: 'g',
                    color: AppColors.carbs,
                    valueColor: AppColors.default_text_color,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _GoalCard(
                    label: 'Fat',
                    value: '${preview.fat}',
                    unit: 'g',
                    color: AppColors.fat,
                    valueColor: AppColors.default_text_color,
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
            CustomButton(
              text: 'Save Goals',
              onPressed: _save,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  final Color? valueColor;

  const _GoalCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.noCurve),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: valueColor ?? Colors.black87,
              ),
            ),
            Text(unit, style: tt.labelSmall?.copyWith(color: Colors.black45)),
          ],
        ),
      ),
    );
  }
}
