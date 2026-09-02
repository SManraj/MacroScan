import 'package:flutter/material.dart';
import '../utils/adaptive_dialogs.dart';

// ── App-wide design tokens ────────────────────────────────────────────────────
class AppSpacing {
  const AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double standard = 0;
  static const double negSm = -8;
}

class AppRadius {
  const AppRadius._();
  static const double sm = 8;
  static const double md = 0;
  static const double lg = 16;
  static const double xl = 20;
  static const double noCurve = 0;
}

// ── Reusable card container with soft shadow ──────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double radius;
  final double elevation;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.radius = AppRadius.noCurve,
    this.elevation = 1,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.surface;
    return Material(
      color: bg,
      elevation: elevation,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(radius),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: Padding(
                padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
                child: child,
              ),
            )
          : Padding(
              padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
              child: child,
            ),
    );
  }
}

// ── Section header with optional trailing ────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          title,
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

// ── Full-width primary action button ─────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final double height;

  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.noCurve),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: AdaptiveActivityIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : child,
      ),
    );
  }
}

// ── Inline info row (label + value) ──────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary, size: 20, semanticLabel: label),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state placeholder ───────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subMessage;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subMessage,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: cs.onSurface.withValues(alpha: 0.25),
              semanticLabel: message,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: tt.titleMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subMessage!,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ── Date navigation bar ───────────────────────────────────────────────────────
class DateNavigator extends StatelessWidget {
  final String label;
  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onTapLabel;

  const DateNavigator({
    super.key,
    required this.label,
    required this.canGoBack,
    required this.onBack,
    required this.onForward,
    required this.onTapLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(
                Icons.chevron_left_rounded,
                semanticLabel: 'Previous day',
                color: canGoBack
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.25),
              ),
              onPressed: canGoBack ? onBack : null,
              padding: EdgeInsets.zero,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTapLabel,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.5),
                      semanticLabel: 'Pick date',
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(
                Icons.chevron_right_rounded,
                semanticLabel: 'Next day',
                color: cs.onSurface,
              ),
              onPressed: onForward,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Macro chip ────────────────────────────────────────────────────────────────
// ── Labelled progress bar (macros, water) ────────────────────────────────────
class ProgressRow extends StatelessWidget {
  final String label;
  final String unit;
  final num consumed;
  final num goal;
  final Color fillColor;

  /// Overrides the right-hand figure. Defaults to "$consumed / $goal $unit";
  /// callers whose values aren't whole numbers pass their own formatting.
  final String? valueText;

  const ProgressRow({
    super.key,
    required this.label,
    required this.unit,
    required this.consumed,
    required this.goal,
    required this.fillColor,
    this.valueText,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    final over = consumed > goal;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                label,
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: fillColor,
                ),
              ),
            ),
            const Spacer(),
            Text(
              valueText ?? '$consumed / $goal $unit',
              style: tt.labelSmall?.copyWith(
                color: over
                    ? Colors.red.shade700
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.55),
                fontWeight: over ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 12,
          decoration: BoxDecoration(
            // Faint tint of the fill colour so the empty track still reads as
            // a progress bar; border + fill use the full colour.
            color: fillColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: fillColor, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: ColoredBox(color: fillColor),
          ),
        ),
      ],
    );
  }
}

class MacroChip extends StatelessWidget {
  final String label;
  final Color color;

  const MacroChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: Colors.black87,
        ),
      ),
    );
  }
}
