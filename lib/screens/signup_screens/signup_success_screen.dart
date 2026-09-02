import 'package:flutter/material.dart';
import 'package:dietingapp2026/screens/signup_screens/profile_info_screen.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/custom_button.dart';

class SignupSuccessScreen extends StatefulWidget {
  const SignupSuccessScreen({super.key});

  @override
  State<SignupSuccessScreen> createState() => _SignupSuccessScreenState();
}

class _SignupSuccessScreenState extends State<SignupSuccessScreen> {
  // One-shot guard so a frantic double-tap during the Navigator transition
  // can't push ProfileInfoScreen twice.
  bool _navigating = false;

  void _goToProfileSetup() {
    if (_navigating) return;
    setState(() => _navigating = true);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ProfileInfoScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Animated success icon
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 56,
                    color: cs.primary,
                    semanticLabel: 'Account created',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              Text(
                'Account Created!',
                textAlign: TextAlign.center,
                style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                "You're almost ready to start tracking your nutrition.\nLet's set up your profile first.",
                textAlign: TextAlign.center,
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                  height: 1.6,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Steps indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepDot(label: '1', done: true, active: false),
                  const _StepLine(),
                  _StepDot(label: '2', done: false, active: true),
                  const _StepLine(),
                  _StepDot(label: '3', done: false, active: false),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _stepLabel('Account', cs, tt, done: true),
                  const SizedBox(width: 36),
                  _stepLabel('Profile', cs, tt, active: true),
                  const SizedBox(width: 36),
                  _stepLabel('Goals', cs, tt),
                ],
              ),

              const Spacer(),

              CustomButton(
                text: 'Set Up Profile',
                width: double.infinity,
                // Gated on _navigating so rapid double-taps don't push the
                // next screen twice during the Navigator transition.
                onPressed: _navigating ? null : _goToProfileSetup,
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepLabel(
    String text,
    ColorScheme cs,
    TextTheme tt, {
    bool done = false,
    bool active = false,
  }) {
    return Text(
      text,
      style: tt.labelSmall?.copyWith(
        color: done || active
            ? cs.primary
            : cs.onSurface.withValues(alpha: 0.35),
        fontWeight: done || active ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool done;
  final bool active;

  const _StepDot({
    required this.label,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Color bg;
    Widget child;
    if (done) {
      bg = cs.primary;
      child = Icon(
        Icons.check_rounded,
        size: 14,
        color: Colors.white,
        semanticLabel: 'Completed step',
      );
    } else if (active) {
      bg = cs.primary;
      child = Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      );
    } else {
      bg = cs.onSurface.withValues(alpha: 0.15);
      child = Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: cs.onSurface.withValues(alpha: 0.4),
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 2,
      color: cs.onSurface.withValues(alpha: 0.15),
    );
  }
}
