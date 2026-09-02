import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/static/colors.dart';
import '../services/water_service.dart';
import 'app_widgets.dart';
import 'custom_button.dart';

/// Daily water intake for [selectedDate], sitting under the macro progress card
/// on the home screen.
///
/// Data is device-local: this reads and writes [waterService], which persists to
/// SharedPreferences. Because that store is a ChangeNotifier, the card stays
/// current without any cache-invalidation plumbing — relevant here since the
/// Home tab is kept alive and never rebuilds on tab switch.
class WaterCard extends StatefulWidget {
  final DateTime selectedDate;

  const WaterCard({super.key, required this.selectedDate});

  @override
  State<WaterCard> createState() => _WaterCardState();
}

class _WaterCardState extends State<WaterCard> {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(WaterCard old) {
    super.didUpdateWidget(old);
    if (old.selectedDate != widget.selectedDate) _load();
  }

  void _load() {
    final uid = _uid;
    if (uid != null) waterService.ensureLoaded(uid, widget.selectedDate);
  }

  Future<void> _add(int ml) async {
    final uid = _uid;
    if (uid == null) return;
    await waterService.add(uid, widget.selectedDate, ml);
  }

  Future<void> _undo() async {
    final uid = _uid;
    if (uid == null) return;
    await waterService.undoLast(uid, widget.selectedDate);
  }

  Future<void> _addCustom() async {
    final unit = waterService.unit;
    final entered = await showModalBottomSheet<num>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustomAmountSheet(unit: unit),
    );
    if (entered != null) await _add(unit.toMl(entered));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: waterService,
      builder: (context, _) {
        final uid = _uid;
        final unit = waterService.unit;
        final day = uid == null
            ? null
            : waterService.peek(uid, widget.selectedDate);
        final totalMl = day?.totalMl ?? 0;
        final goalMl = waterService.goalMl;

        return AppCard(
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
                  const Icon(
                    Icons.water_drop_outlined,
                    size: 18,
                    color: AppColors.water,
                    semanticLabel: 'Hydration',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Hydration',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  if (uid != null && (day?.entries.isNotEmpty ?? false)) ...[
                    const Spacer(),
                    IconButton(
                      onPressed: _undo,
                      icon: const Icon(
                        Icons.undo_rounded,
                        size: 20,
                        semanticLabel: 'Undo last drink',
                      ),
                      tooltip: 'Undo last',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              if (uid == null)
                Text(
                  'Sign in to track water.',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                )
              else ...[
                ProgressRow(
                  label: 'Water',
                  unit: unit.label,
                  consumed: totalMl,
                  goal: goalMl,
                  fillColor: AppColors.water,
                  valueText:
                      '${unit.format(unit.fromMl(totalMl))} / '
                      '${unit.formatWithLabel(unit.fromMl(goalMl))}',
                ),
                const SizedBox(height: AppSpacing.xl),
                // A Row, not a Center: CustomButton's internal Center expands to
                // any bounded width it's given, so wrapping it in a Center makes
                // it fill the card. A Row lays out non-flex children against an
                // unbounded main axis, which lets the button hug its label.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomButton(
                      text: 'Log Water',
                      onPressed: _addCustom,
                      // Roughly two spaces of breathing room at this font size,
                      // so it reads as a secondary action inside the card
                      // rather than a full-width CTA.
                      fontSize: 15,
                      horizontalPadding: 8,
                      verticalPadding: 6,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Bottom sheet for logging an exact amount. Pops the entered value in [unit]
/// (not millilitres) — the caller converts.
class _CustomAmountSheet extends StatefulWidget {
  final WaterUnit unit;

  const _CustomAmountSheet({required this.unit});

  @override
  State<_CustomAmountSheet> createState() => _CustomAmountSheetState();
}

class _CustomAmountSheetState extends State<_CustomAmountSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextInputType get _keyboardType {
    if (kIsWeb) return TextInputType.number;
    if (Platform.isIOS) {
      return const TextInputType.numberWithOptions(decimal: true);
    }
    return const TextInputType.numberWithOptions(decimal: true);
  }

  void _submit() {
    final value = double.tryParse(_controller.text.trim());

    if (value == null || value.isNaN || value <= 0) {
      setState(() => _error = 'Enter an amount greater than 0');
      return;
    }

    // Compared in the display unit and *before* converting: `value` may be
    // infinity (double.tryParse('9e999')), which would be undefined behaviour
    // once it reached round(). A double comparison handles it safely.
    if (value >= widget.unit.fromMl(WaterService.maxEntryMl)) {
      setState(() => _error = 'That is not physically possible');
      return;
    }

    // Catches amounts that are positive but round away to nothing, e.g. 0.4 ml.
    if (widget.unit.toMl(value) < WaterService.minEntryMl) {
      setState(() => _error = 'Enter an amount greater than 0');
      return;
    }

    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      // Lift the sheet above the keyboard.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add water',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            keyboardType: _keyboardType,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              hintText: 'Amount',
              errorText: _error,
              prefixIcon: const Icon(Icons.water_drop_outlined),
              suffixText: widget.unit.label,
              border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          CustomButton(text: 'Add', onPressed: _submit, width: double.infinity),
        ],
      ),
    );
  }
}
