import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../database_service.dart';
import '../services/cache_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/dropdown.dart';
import '../widgets/loading_view.dart';
import 'food_detail_screen.dart';
import 'static/colors.dart';

/// Lets the user photograph a meal, runs FatSecret Image Recognition through
/// the backend, and presents an adjustable results list before logging.
///
/// Returns `true` from `Navigator.pop` after at least one food was logged so
/// the caller can refresh.
class MealScanScreen extends StatefulWidget {
  final DateTime logDate;
  const MealScanScreen({super.key, required this.logDate});

  @override
  State<MealScanScreen> createState() => _MealScanScreenState();
}

enum _Stage { chooseSource, recognizing, results, error }

enum _ErrorKind { noFood, addonOrConfig, network, tooLarge }

class _MealScanScreenState extends State<MealScanScreen> {
  _Stage _stage = _Stage.chooseSource;
  Uint8List? _imageBytes;
  List<_DetectedItem> _items = [];
  String _batchMeal = 'Breakfast';
  _ErrorKind _errorKind = _ErrorKind.network;
  String? _errorMessage;
  bool _submitting = false;

  static const List<(String, String)> _mealOptions = [
    ('Breakfast', 'Breakfast'),
    ('Lunch', 'Lunch'),
    ('Dinner', 'Dinner'),
    ('Snack', 'Snack'),
  ];

  // ── Photo capture + recognition ────────────────────────────────────────────

  Future<void> _pick(ImageSource source) async {
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not access ${source == ImageSource.camera ? "the camera" : "photos"}: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (file == null) return; // user cancelled

    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);

    // Respect the FatSecret ~1MB body limit before calling the backend.
    if (b64.length > 999000) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _errorKind = _ErrorKind.tooLarge;
        _errorMessage = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _stage = _Stage.recognizing;
    });
    await _recognize(b64);
  }

  Future<void> _recognize(String b64) async {
    try {
      final foods = await DatabaseService.recognizeFoodImage(b64);
      if (!mounted) return;
      if (foods.isEmpty) {
        setState(() {
          _stage = _Stage.error;
          _errorKind = _ErrorKind.noFood;
        });
        return;
      }
      setState(() {
        _items = foods.map(_makeItem).toList();
        _stage = _Stage.results;
      });
    } on NoFoodDetectedException {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _errorKind = _ErrorKind.noFood;
      });
    } catch (e) {
      if (!mounted) return;
      final lower = e.toString().toLowerCase();
      final looksLikeAddonProblem =
          lower.contains('add-on') ||
          lower.contains('add on') ||
          lower.contains('scope') ||
          lower.contains('not enabled') ||
          lower.contains('not configured') ||
          lower.contains('not found') ||
          lower.contains('endpoint') ||
          lower.contains('http 404');
      setState(() {
        _stage = _Stage.error;
        _errorKind = looksLikeAddonProblem
            ? _ErrorKind.addonOrConfig
            : _ErrorKind.network;
        _errorMessage = e.toString();
      });
    }
  }

  /// Picks the effective serving for a recognized food: prefer the suggested
  /// serving, fall back to the is_default one when the suggested has no macros.
  _DetectedItem _makeItem(RecognizedFood f) {
    ServingSize? serving;
    if (f.detail != null) {
      for (final s in f.detail!.servings) {
        if (s.id == f.suggestedServingId) {
          serving = s;
          break;
        }
      }
      final hasNutrition = serving != null && serving.calories != null;
      if (!hasNutrition && f.defaultServingId != null) {
        for (final s in f.detail!.servings) {
          if (s.id == f.defaultServingId) {
            serving = s;
            break;
          }
        }
      }
    }
    return _DetectedItem(
      source: f,
      chosenServing: serving,
      chosenQuantity: f.suggestedUnits,
      chosenMealOverride: null,
      checked: true,
    );
  }

  // ── Per-row adjust + batch submit ──────────────────────────────────────────

  Future<void> _adjustItem(int index) async {
    final item = _items[index];
    final detail = item.source.detail;
    if (detail == null || item.chosenServing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Adjustment isn't available for this item — use the checkbox to add or skip it.",
          ),
        ),
      );
      return;
    }

    // FoodDetailScreen requires a FoodResult for its `food` parameter; build a
    // lightweight stub from the FoodDetail we already have.
    final stub = FoodResult(
      id: detail.id,
      name: detail.name,
      brandName: detail.brandName,
    );

    final selection = await Navigator.of(context).push<FoodDetailSelection>(
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(
          food: stub,
          logDate: widget.logDate,
          initialDetail: detail,
          initialServingId: item.chosenServing!.id,
          initialQuantity: item.chosenQuantity,
          initialMeal: item.chosenMealOverride ?? _batchMeal,
          returnSelection: true,
        ),
      ),
    );
    if (selection == null || !mounted) return;
    setState(() {
      _items[index] = item.copyWith(
        chosenServing: selection.$1,
        chosenQuantity: selection.$2,
        chosenMealOverride: selection.$3,
      );
    });
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to log food.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final selected = _items.where((i) => i.checked).toList();
    if (selected.isEmpty) return;

    setState(() => _submitting = true);
    try {
      for (final item in selected) {
        final meal = item.chosenMealOverride ?? _batchMeal;
        final s = item.chosenServing;
        if (s != null && s.calories != null) {
          // Logged using the chosen serving + quantity (matches food_detail).
          await DatabaseService.logFood(
            uid: uid,
            meal: meal,
            foodName: item.source.name,
            servingQty: item.chosenQuantity,
            servingUnit: s.description,
            calories: (s.calories ?? 0) * item.chosenQuantity,
            protein: (s.protein ?? 0) * item.chosenQuantity,
            carbs: (s.carbs ?? 0) * item.chosenQuantity,
            fats: (s.fat ?? 0) * item.chosenQuantity,
            date: widget.logDate,
          );
        } else {
          // No usable per-serving macros (no inline detail, or suggested + default
          // both lacked nutrition). Fall back to the recognize preview totals as
          // a single-unit entry described by the suggested serving text.
          await DatabaseService.logFood(
            uid: uid,
            meal: meal,
            foodName: item.source.name,
            servingQty: 1.0,
            servingUnit: item.source.suggestedServingDescription,
            calories: item.source.previewCalories ?? 0,
            protein: item.source.previewProtein ?? 0,
            carbs: item.source.previewCarbs ?? 0,
            fats: item.source.previewFat ?? 0,
            date: widget.logDate,
          );
        }
      }
      await CacheService.instance.invalidateDate(uid, widget.logDate);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add some foods: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Meal Photo')),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.chooseSource => _buildChooseSource(),
          _Stage.recognizing => _buildRecognizing(),
          _Stage.results => _buildResults(),
          _Stage.error => _buildError(),
        },
      ),
    );
  }

  Widget _buildChooseSource() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget option({
      required IconData icon,
      required String label,
      required String subtitle,
      required VoidCallback onTap,
      required String semanticLabel,
    }) {
      return AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                icon,
                color: cs.primary,
                size: 22,
                semanticLabel: semanticLabel,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withValues(alpha: 0.35),
              size: 20,
              semanticLabel: 'Open',
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: 'CAPTURE A MEAL PHOTO'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Take or pick a clear photo of your meal. We\'ll detect the foods and let you review before logging.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          option(
            icon: Icons.photo_camera_rounded,
            label: 'Take Photo',
            subtitle: 'Use the camera',
            onTap: () => _pick(ImageSource.camera),
            semanticLabel: 'Open camera',
          ),
          const SizedBox(height: AppSpacing.sm),
          option(
            icon: Icons.photo_library_rounded,
            label: 'Choose from Library',
            subtitle: 'Pick an existing photo',
            onTap: () => _pick(ImageSource.gallery),
            semanticLabel: 'Open photo library',
          ),
        ],
      ),
    );
  }

  Widget _buildRecognizing() {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_imageBytes != null)
          Image.memory(_imageBytes!, fit: BoxFit.cover)
        else
          ColoredBox(color: cs.surfaceContainerHighest),
        Container(color: Colors.black.withValues(alpha: 0.45)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LoadingView(size: 140),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Looking up foods…',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This can take a few seconds.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final checkedCount = _items.where((i) => i.checked).length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: [
              // Thumbnail of the scanned photo + counts.
              Row(
                children: [
                  if (_imageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Image.memory(
                        _imageBytes!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (_imageBytes != null) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_items.length} food${_items.length == 1 ? '' : 's'} detected',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Review and tap a row to adjust.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              SectionHeader(title: 'MEAL'),
              const SizedBox(height: AppSpacing.sm),
              AppDropdown<String>(
                options: _mealOptions,
                value: _batchMeal,
                hint: 'Select a meal',
                prefixIcon: Icons.restaurant_menu_rounded,
                onChanged: (v) => setState(() => _batchMeal = v),
              ),

              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: 'DETECTED FOODS'),
              const SizedBox(height: AppSpacing.sm),

              for (var i = 0; i < _items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _DetectedFoodCard(
                    item: _items[i],
                    onCheckedChanged: (v) {
                      setState(
                        () => _items[i] = _items[i].copyWith(checked: v),
                      );
                    },
                    onTap: () => _adjustItem(i),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: PrimaryButton(
            onPressed: checkedCount > 0 ? _submit : null,
            isLoading: _submitting,
            child: Text(
              checkedCount > 0
                  ? 'Add $checkedCount to log'
                  : 'Select at least one food',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    final (icon, message, sub, actionLabel, action) = switch (_errorKind) {
      _ErrorKind.noFood => (
        Icons.no_food_rounded,
        "Couldn't find any food in that photo",
        'Try a clearer photo with the meal centered and well lit.',
        'Retake',
        () => setState(() => _stage = _Stage.chooseSource),
      ),
      _ErrorKind.tooLarge => (
        Icons.image_not_supported_rounded,
        'That photo is too large',
        'Try a smaller image (under ~1 MB) or take a fresh photo.',
        'Try Again',
        () => setState(() => _stage = _Stage.chooseSource),
      ),
      _ErrorKind.addonOrConfig => (
        Icons.cloud_off_rounded,
        'Meal recognition is unavailable',
        _errorMessage ??
            'The recognition service is not enabled on this backend. Please try again later.',
        'Back',
        () => Navigator.of(context).pop(),
      ),
      _ErrorKind.network => (
        Icons.error_outline,
        'Recognition failed',
        _errorMessage ??
            'Something went wrong reaching the server. Check your connection and try again.',
        'Retry',
        () => setState(() => _stage = _Stage.chooseSource),
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: EmptyState(
          icon: icon,
          message: message,
          subMessage: sub,
          action: FilledButton(onPressed: action, child: Text(actionLabel)),
        ),
      ),
    );
  }
}

// ── Detected food card ────────────────────────────────────────────────────────

class _DetectedFoodCard extends StatelessWidget {
  final _DetectedItem item;
  final ValueChanged<bool> onCheckedChanged;
  final VoidCallback onTap;

  const _DetectedFoodCard({
    required this.item,
    required this.onCheckedChanged,
    required this.onTap,
  });

  String _fmt(double? v) => v != null ? v.toStringAsFixed(1) : '–';

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    // Macros displayed = chosen-serving macros × quantity, or the recognize
    // preview totals when no usable serving is available.
    final s = item.chosenServing;
    final hasServing = s != null && s.calories != null;
    final q = item.chosenQuantity;
    final cals = hasServing
        ? (s.calories ?? 0) * q
        : item.source.previewCalories;
    final prot = hasServing ? (s.protein ?? 0) * q : item.source.previewProtein;
    final carb = hasServing ? (s.carbs ?? 0) * q : item.source.previewCarbs;
    final fat = hasServing ? (s.fat ?? 0) * q : item.source.previewFat;

    final servingLine = hasServing
        ? '${q % 1 == 0 ? q.toInt() : q.toStringAsFixed(2)} × ${s.description}'
        : item.source.suggestedServingDescription;

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Checkbox(
                value: item.checked,
                onChanged: (v) => onCheckedChanged(v ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.source.name,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      servingLine,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        MacroChip(
                          label: '${_fmt(cals)} kcal',
                          color: AppColors.calories,
                        ),
                        MacroChip(
                          label: 'C ${_fmt(carb)}g',
                          color: AppColors.carbs,
                        ),
                        MacroChip(
                          label: 'F ${_fmt(fat)}g',
                          color: AppColors.fat,
                        ),
                        MacroChip(
                          label: 'P ${_fmt(prot)}g',
                          color: AppColors.protein,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onSurface.withValues(alpha: 0.35),
                semanticLabel: 'Adjust serving',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Item model ────────────────────────────────────────────────────────────────

class _DetectedItem {
  final RecognizedFood source;
  final ServingSize? chosenServing;
  final double chosenQuantity;
  final String? chosenMealOverride;
  final bool checked;

  _DetectedItem({
    required this.source,
    required this.chosenServing,
    required this.chosenQuantity,
    required this.chosenMealOverride,
    required this.checked,
  });

  _DetectedItem copyWith({
    ServingSize? chosenServing,
    double? chosenQuantity,
    String? chosenMealOverride,
    bool? checked,
  }) => _DetectedItem(
    source: source,
    chosenServing: chosenServing ?? this.chosenServing,
    chosenQuantity: chosenQuantity ?? this.chosenQuantity,
    chosenMealOverride: chosenMealOverride ?? this.chosenMealOverride,
    checked: checked ?? this.checked,
  );
}
