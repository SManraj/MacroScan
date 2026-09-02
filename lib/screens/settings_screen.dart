import 'dart:io' show Platform;
import 'package:dietingapp2026/screens/settings_screens/reset_password.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../providers/theme_notifier.dart';
import '../utils/adaptive_dialogs.dart';
import '../widgets/app_widgets.dart';
import 'package:dietingapp2026/screens/login_screen.dart';
import 'package:dietingapp2026/screens/settings_screens/delete_account.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void popPage() {
    Navigator.pop(context);
  }

  void _showThemePicker() {
    const options = [
      ('System', ThemeMode.system),
      ('Light', ThemeMode.light),
      ('Dark', ThemeMode.dark),
    ];

    if (!kIsWeb && Platform.isIOS) {
      showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          actions: options.map((opt) {
            final isSelected = themeNotifier.themeMode == opt.$2;
            return CupertinoActionSheetAction(
              onPressed: () {
                themeNotifier.setThemeMode(opt.$2);
                Navigator.pop(ctx);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(opt.$1),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check, size: 18),
                  ],
                ],
              ),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) {
          final primary = Theme.of(ctx).colorScheme.primary;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((opt) {
                final isSelected = themeNotifier.themeMode == opt.$2;
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? primary : null,
                    semanticLabel: opt.$1,
                  ),
                  title: Text(opt.$1),
                  onTap: () {
                    themeNotifier.setThemeMode(opt.$2);
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
          );
        },
      );
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Sign Out',
      content: 'Are you sure you want to sign out?',
      confirmText: 'Sign Out',
    );

    if (confirmed) {
      await authService.value.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.value.currentUser;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: [
                  // Account info card
                  AppCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: cs.primaryContainer,
                          child: Text(
                            (user?.email?.isNotEmpty == true)
                                ? user!.email![0].toUpperCase()
                                : 'U',
                            style: tt.titleLarge?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Signed in as',
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? 'User',
                                style: tt.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // const SizedBox(height: AppSpacing.xl),
                  // const SizedBox(height: AppSpacing.sm),

                  // Appearance / theme
                  AppCard(
                    padding: EdgeInsets.zero,
                    onTap: _showThemePicker,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(
                              Icons.brightness_6_rounded,
                              size: 20,
                              semanticLabel: 'Appearance',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Appearance',
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  themeNotifier.label,
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
                            semanticLabel: 'Select appearance',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // const SizedBox(height: AppSpacing.xl),
                  // const SizedBox(height: AppSpacing.sm),

                  // Change Password
                  AppCard(
                    padding: EdgeInsets.zero,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ResetPasswordScreen(),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 20,
                              semanticLabel: 'Change password',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Change Password',
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Update your account password',
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
                            semanticLabel: 'Navigate',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // const SizedBox(height: AppSpacing.xl),
                  // const SizedBox(height: AppSpacing.sm),

                  // Sign Out
                  AppCard(
                    padding: EdgeInsets.zero,
                    onTap: _handleSignOut,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(
                              Icons.logout_rounded,
                              size: 20,
                              semanticLabel: 'Sign out',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sign Out',
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sign out of your account',
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
                            semanticLabel: 'Navigate',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Danger zone at bottom
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DeleteAccountScreen(),
                    ),
                  ),
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    size: 20,
                    semanticLabel: 'Delete account',
                  ),
                  label: const Text('Delete Account'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
