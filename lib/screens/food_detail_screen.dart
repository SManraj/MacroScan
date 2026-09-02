import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../database_service.dart';
import '../services/cache_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/loading_view.dart';
import 'static/colors.dart';
import '../widgets/custom_button.dart';

/// The selection returned by [FoodDetailScreen] when opened with
/// `returnSelection: true` — the chosen serving, quantity, and meal.
typedef FoodDetailSelection = (
  ServingSize serving,
  double quantity,
  String meal,
);

class FoodDetailScreen extends StatefulWidget {
  final FoodResult food;
  final DateTime? logDate;

  /// Pre-supplied detail to skip the network fetch (used by meal-scan rows
  /// that already have the parsed FoodDetail from the recognize response).
  final FoodDetail? initialDetail;

  /// Serving id to preselect inside [initialDetail] / fetched servings.
  final String? initialServingId;

  /// Quantity to seed the field with (kept as a double to preserve decimals
  /// like 1.319 that come back from FatSecret's suggested serving).
  final double? initialQuantity;

  /// Meal to preselect in the chip row.
  final String? initialMeal;

  /// When true, the bottom button reads "Apply Changes" and pops the chosen
  /// [FoodDetailSelection] instead of calling `logFood` directly — used by
  /// the meal-scan results screen so each row owns the final logFood call.
  final bool returnSelection;

  const FoodDetailScreen({
    super.key,
    required this.food,
    this.logDate,
    this.initialDetail,
    this.initialServingId,
    this.initialQuantity,
    this.initialMeal,
    this.returnSelection = false,
  });

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  FoodDetail? _detail;
  bool _loading = true;
  String? _error;
  ServingSize? _selectedServing;
  late String _selectedMeal;
  late double _quantity;
  late final TextEditingController _quantityController;

  static const _meals = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  double? get _calories => _selectedServing?.calories != null
      ? _selectedServing!.calories! * _quantity
      : null;
  double? get _carbs => _selectedServing?.carbs != null
      ? _selectedServing!.carbs! * _quantity
      : null;
  double? get _fat =>
      _selectedServing?.fat != null ? _selectedServing!.fat! * _quantity : null;
  double? get _protein => _selectedServing?.protein != null
      ? _selectedServing!.protein! * _quantity
      : null;

  TextInputType get _keyboardType {
    if (kIsWeb) return TextInputType.number;
    if (Platform.isIOS) return TextInputType.numberWithOptions(decimal: true);
    return TextInputType.numberWithOptions(decimal: true);
  }

  @override
  void initState() {
    super.initState();
    _selectedMeal = widget.initialMeal ?? 'Breakfast';
    _quantity = widget.initialQuantity ?? 1.0;
    _quantityController = TextEditingController(
      text: _quantity % 1 == 0
          ? _quantity.toInt().toString()
          : _quantity.toString(),
    );

    if (widget.initialDetail != null) {
      // Meal-scan path — skip the network fetch entirely.
      _detail = widget.initialDetail;
      _selectedServing = _findServing(_detail!, widget.initialServingId);
      _loading = false;
    } else {
      _loadDetail();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  /// Returns the serving matching [servingId] from [detail.servings], or the
  /// first available serving as a fallback.
  ServingSize? _findServing(FoodDetail detail, String? servingId) {
    if (servingId != null) {
      for (final s in detail.servings) {
        if (s.id == servingId) return s;
      }
    }
    return detail.servings.isNotEmpty ? detail.servings.first : null;
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await DatabaseService.getFoodDetail(widget.food.id);
      if (mounted) {
        setState(() {
          _detail = detail;
          _selectedServing = _findServing(detail, widget.initialServingId);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _onQuantityChanged(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed >= 0) {
      setState(() => _quantity = parsed);
    }
  }

  String _fmt(double? v) => v != null ? v.toStringAsFixed(1) : '–';

  bool _saving = false;

  /// Used when [FoodDetailScreen.returnSelection] is true — pops with the
  /// chosen serving / quantity / meal so the caller (e.g. meal-scan results)
  /// can apply the change back to its row instead of logging directly.
  void _returnSelection() {
    if (_selectedServing == null) return;
    Navigator.of(
      context,
    ).pop<FoodDetailSelection>((_selectedServing!, _quantity, _selectedMeal));
  }

  Future<void> _addToLog() async {
    if (_selectedServing == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to log food.')),
      );
      return;
    }

    setState(() => _saving = true);

    final foodName = _detail?.displayName ?? widget.food.displayName;

    try {
      await DatabaseService.logFood(
        uid: uid,
        meal: _selectedMeal,
        foodName: foodName,
        servingQty: _quantity,
        servingUnit: _selectedServing!.description,
        calories: _calories ?? 0,
        protein: _protein ?? 0,
        carbs: _carbs ?? 0,
        fats: _fat ?? 0,
        date: widget.logDate,
      );

      // Drop the cached log + summary for this day so the next read is fresh.
      await CacheService.instance.invalidateDate(
        uid,
        widget.logDate ?? DateTime.now(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$foodName added to $_selectedMeal'),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.food.displayName, overflow: TextOverflow.ellipsis),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: EmptyState(
                  icon: Icons.error_outline,
                  message: 'Failed to load food details',
                  subMessage: _error,
                  action: FilledButton(
                    onPressed: _loadDetail,
                    child: const Text('Retry'),
                  ),
                ),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final detail = _detail!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        // ── Macro header ──────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          decoration: BoxDecoration(color: cs.primaryContainer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.displayName,
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onPrimaryContainer,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _MacroCard(
                    label: 'Calories',
                    value: _fmt(_calories),
                    unit: 'kcal',
                    color: AppColors.calories,
                    valueColor: AppColors.calories_text,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _MacroCard(
                    label: 'Carbs',
                    value: _fmt(_carbs),
                    unit: 'g',
                    color: AppColors.carbs,
                    valueColor: AppColors.carbs_text,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _MacroCard(
                    label: 'Fat',
                    value: _fmt(_fat),
                    unit: 'g',
                    color: AppColors.fat,
                    valueColor: AppColors.fat_text,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _MacroCard(
                    label: 'Protein',
                    value: _fmt(_protein),
                    unit: 'g',
                    color: AppColors.protein,
                    valueColor: AppColors.protein_text,
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Controls ──────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: 'SERVING SIZE'),
                const SizedBox(height: AppSpacing.sm),

                DropdownButtonFormField<ServingSize>(
                  initialValue: _selectedServing,
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.restaurant_outlined,
                      semanticLabel: 'Serving size',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.noCurve),
                    ),
                  ),
                  items: detail.servings
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            s.description,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (s) => setState(() => _selectedServing = s),
                ),

                const SizedBox(height: AppSpacing.xl),
                SectionHeader(title: 'QUANTITY'),
                const SizedBox(height: AppSpacing.sm),

                TextField(
                  controller: _quantityController,
                  keyboardType: _keyboardType,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.numbers_rounded,
                      semanticLabel: 'Quantity',
                    ),
                    hintText: '1',
                    suffixText: _selectedServing?.description,
                  ),
                  onChanged: _onQuantityChanged,
                ),

                const SizedBox(height: AppSpacing.xl),
                SectionHeader(title: 'MEAL'),
                const SizedBox(height: AppSpacing.sm),

                Row(
                  children: _meals.map((meal) {
                    final selected = meal == _selectedMeal;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMeal = meal),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: selected ? cs.primary : cs.surface,
                              borderRadius: BorderRadius.circular(
                                AppRadius.noCurve,
                              ),
                              border: selected
                                  ? null
                                  : Border.all(
                                      color: cs.outlineVariant.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              meal,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : cs.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: AppSpacing.xxl),

                CustomButton(
                  text: 'Add to Log',
                  onPressed: _addToLog,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color? valueColor;

  const _MacroCard({
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
            const SizedBox(height: 2),
            Text(
              value,
              style: tt.titleSmall?.copyWith(
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
