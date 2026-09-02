import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../database_service.dart';
import '../utils/adaptive_dialogs.dart';
import '../widgets/app_widgets.dart';
import './static/colors.dart';

class EditFoodLogScreen extends StatefulWidget {
  final FoodLogEntry entry;
  const EditFoodLogScreen({super.key, required this.entry});

  @override
  State<EditFoodLogScreen> createState() => _EditFoodLogScreenState();
}

class _EditFoodLogScreenState extends State<EditFoodLogScreen> {
  late double _quantity;
  late TextEditingController _qtyController;
  bool _saving = false;
  bool _deleting = false;

  double get _calories => widget.entry.caloriesPerUnit * _quantity;
  double get _protein => widget.entry.proteinPerUnit * _quantity;
  double get _carbs => widget.entry.carbsPerUnit * _quantity;
  double get _fats => widget.entry.fatsPerUnit * _quantity;

  TextInputType get _keyboardType {
    if (kIsWeb) return TextInputType.number;
    if (Platform.isIOS) return TextInputType.numberWithOptions(decimal: true);
    return TextInputType.numberWithOptions(decimal: true);
  }

  @override
  void initState() {
    super.initState();
    _quantity = widget.entry.servingQty;
    _qtyController = TextEditingController(
      text: _quantity % 1 == 0
          ? _quantity.toInt().toString()
          : _quantity.toString(),
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  String _fmt(double v) => v.toStringAsFixed(1);

  void _onQtyChanged(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed >= 0) setState(() => _quantity = parsed);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await DatabaseService.updateFoodLogEntry(
        id: widget.entry.id,
        servingQty: _quantity,
        servingUnit: widget.entry.servingUnit,
        calories: _calories,
        protein: _protein,
        carbs: _carbs,
        fats: _fats,
      );
      if (mounted) Navigator.of(context).pop(true);
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

  Future<void> _delete() async {
    final confirmed = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Remove from log?',
      content: 'Remove "${widget.entry.foodName}" from your log?',
      confirmText: 'Remove',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _deleting = true);
    try {
      await DatabaseService.deleteFoodLogEntry(widget.entry.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.foodName, overflow: TextOverflow.ellipsis),
        actions: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: AdaptiveActivityIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                      semanticLabel: 'Delete entry',
                    ),
              onPressed: _deleting ? null : _delete,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Macro header ────────────────────────────────────────────────
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
                  widget.entry.foodName,
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
                      valueColor: const Color.fromARGB(255, 0, 0, 0),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _MacroCard(
                      label: 'Carbs',
                      value: _fmt(_carbs),
                      unit: 'g',
                      color: AppColors.carbs,
                      valueColor: const Color.fromARGB(255, 0, 0, 0),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _MacroCard(
                      label: 'Fat',
                      value: _fmt(_fats),
                      unit: 'g',
                      color: AppColors.fat,
                      valueColor: const Color.fromARGB(255, 0, 0, 0),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _MacroCard(
                      label: 'Protein',
                      value: _fmt(_protein),
                      unit: 'g',
                      color: AppColors.protein,
                      valueColor: const Color.fromARGB(255, 0, 0, 0),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Controls ────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: 'SERVING SIZE'),
                  const SizedBox(height: AppSpacing.sm),

                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.restaurant_outlined,
                          color: cs.onSurface.withValues(alpha: 0.5),
                          size: 20,
                          semanticLabel: 'Serving size',
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          widget.entry.servingUnit,
                          style: tt.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(
                              AppRadius.noCurve,
                            ),
                          ),
                          child: Text(
                            'Fixed',
                            style: tt.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(title: 'Quantity'),
                  const SizedBox(height: AppSpacing.sm),

                  TextField(
                    controller: _qtyController,
                    keyboardType: _keyboardType,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.numbers_rounded,
                        semanticLabel: 'Quantity',
                      ),
                      suffixText: widget.entry.servingUnit,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                    ),
                    onChanged: _onQtyChanged,
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  PrimaryButton(
                    onPressed: _save,
                    isLoading: _saving,
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label, value, unit;
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: valueColor ?? Colors.black87,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: tt.labelSmall?.copyWith(color: Colors.black45),
                  ),
                ],
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
