import 'package:flutter/material.dart';
import '../screens/static/colors.dart';

/// Reusable neo-brutalist CTA — a wide muted-teal pill with a dark border and
/// a flat, no-blur drop shadow. Pass the label via [text] so the same widget
/// can be used across screens with different copy.
///
/// Fills the width of its parent — give it tight horizontal constraints
/// (e.g. inside a SliverPadding or Padding) for the full neo-brutalist look.
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double horizontalPadding;
  final double verticalPadding;
  final double fontSize;
  final Color backgroundColor;
  final Color textColor;

  /// Optional explicit width. When null, the button fills whatever bounded width
  /// its parent offers — the inner Center expands under bounded constraints, so
  /// a Center/Padding parent still yields a full-width button. To shrink to the
  /// label, give it an unbounded main axis (e.g. a Row) or set this explicitly.
  final double? width;

  /// Optional leading icon (e.g. a brand logo). Rendered to the left of [text]
  /// with a small gap. Pass a sized widget (Image with width/height, or an
  /// Icon with size) so it fits the button's vertical rhythm.
  final Widget? icon;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.horizontalPadding = 20,
    this.verticalPadding = 10,
    this.fontSize = 18,
    this.width,
    this.icon,
    this.backgroundColor = const Color.fromRGBO(0, 148, 65, 1),
    this.textColor = AppColors.default_button_text_color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onPressed,
        // Outer layer carries the hard offset shadow only — the fill + border
        // are drawn by the inner Container so the shadow sits *behind* the pill
        // instead of being clipped by it.
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(0),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF1A1A1A),
                offset: Offset(0, 5),
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(0),
              border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 10)],
                  Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
