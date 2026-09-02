import 'package:flutter/material.dart';
import '/widgets/app_widgets.dart'; // for AppSpacing, AppRadius etc if needed

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
    required this.onChanged,
    this.hint = 'Select an option',
    this.prefixIcon,
  });

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;
  bool _isOpen = false;

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _removeOverlay();
    _ctrl.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() => _isOpen = false);
  }

  void _toggleDropdown(BuildContext ctx) {
    if (_isOpen) {
      _removeOverlay();
      return;
    }

    final renderBox = ctx.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 2),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Material(
                  elevation: 8,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.zero,
                  child: SizedBox(
                    width: size.width,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.options.map((opt) {
                        final isSelected = widget.value == opt.$1;
                        return InkWell(
                          onTap: () {
                            widget.onChanged(opt.$1);
                            _removeOverlay();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            color: isSelected
                                ? Theme.of(ctx).colorScheme.primaryContainer
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 36),
                                Expanded(
                                  child: Text(
                                    opt.$2,
                                    style: Theme.of(ctx).textTheme.bodyLarge
                                        ?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Theme.of(
                                                  ctx,
                                                ).colorScheme.primary
                                              : Theme.of(
                                                  ctx,
                                                ).colorScheme.onSurface,
                                        ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: Theme.of(ctx).colorScheme.primary,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(ctx).insert(_overlay!);
    _ctrl.forward(from: 0);
    setState(() => _isOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final selectedLabel = widget.options
        .where((o) => o.$1 == widget.value)
        .map((o) => o.$2)
        .firstOrNull;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Builder(
        builder: (ctx) => GestureDetector(
          onTap: () => _toggleDropdown(ctx),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
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
                    style: tt.bodyLarge?.copyWith(
                      color: selectedLabel != null
                          ? cs.onSurface
                          : cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
