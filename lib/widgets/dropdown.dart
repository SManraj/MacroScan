import 'package:flutter/material.dart';

/// A reusable, generic dropdown that renders its panel through an [OverlayEntry]
/// anchored to the field with a [CompositedTransformTarget]/[CompositedTransformFollower]
/// pair. Sharp-cornered, theme-driven, with a fade + upward-slide open animation.
class AppDropdown<T> extends StatefulWidget {
  final List<(T, String)> options;
  final T? value;
  final String hint;
  final IconData? prefixIcon;
  final ValueChanged<T> onChanged;

  const AppDropdown({
    super.key,
    required this.options,
    required this.value,
    required this.hint,
    required this.onChanged,
    this.prefixIcon,
  });

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _controller.dispose();
    super.dispose();
  }

  void _toggle() => _isOpen ? _close() : _open();

  void _open() {
    _overlayEntry = _buildOverlay();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
    _controller.forward();
  }

  void _close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _controller.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  OverlayEntry _buildOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return OverlayEntry(
      builder: (_) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
              ),
            ),
            Positioned(
              width: size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, size.height + 4),
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (_, child) {
                    // Reveal the panel top-down so it visibly drops out of the
                    // field, and rolls back up on close. ClipRect prevents the
                    // unrevealed portion from painting.
                    return ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: _animation.value,
                        child: child,
                      ),
                    );
                  },
                  child: _buildPanel(cs, tt),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPanel(ColorScheme cs, TextTheme tt) {
    return Material(
      color: cs.surface,
      elevation: 4,
      borderRadius: BorderRadius.zero,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          border: Border.all(color: cs.primary, width: 2),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: widget.options.map((opt) {
            final isSelected = opt.$1 == widget.value;
            return InkWell(
              onTap: () {
                widget.onChanged(opt.$1);
                _close();
              },
              child: Container(
                color: isSelected ? cs.primaryContainer : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        opt.$2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          color: isSelected
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_rounded, size: 18, color: cs.primary),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    String? selectedLabel;
    for (final opt in widget.options) {
      if (opt.$1 == widget.value) {
        selectedLabel = opt.$2;
        break;
      }
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: _isOpen ? cs.primary : cs.outlineVariant,
              width: _isOpen ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (widget.prefixIcon != null) ...[
                Icon(
                  widget.prefixIcon,
                  size: 20,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  selectedLabel ?? widget.hint,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyLarge?.copyWith(
                    color: selectedLabel == null
                        ? cs.onSurface.withValues(alpha: 0.5)
                        : cs.onSurface,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: _isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _isOpen
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
