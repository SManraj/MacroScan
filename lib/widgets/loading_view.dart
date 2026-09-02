import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Centered Lottie loading animation used as the standard "page loading"
/// state across the app. Drop this widget into a [Scaffold] body (or any
/// loose-constraint slot) when a screen is waiting on its first data load.
///
/// Example:
/// ```dart
/// if (_loading) return const Scaffold(body: LoadingView());
/// ```
class LoadingView extends StatelessWidget {
  /// Square edge length of the animation. The asset is 500×500 so it scales
  /// down crisply at any reasonable size.
  final double size;

  const LoadingView({super.key, this.size = 160});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        'assets/images/loading_screen.json',
        width: size,
        height: size,
        fit: BoxFit.contain,
        repeat: true,
      ),
    );
  }
}
