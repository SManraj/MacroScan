import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// `true` when running on a real iOS device or simulator (not web).
bool get _isIOS => !kIsWeb && Platform.isIOS;

// ── Confirmation dialog ───────────────────────────────────────────────────────

/// Shows a platform-appropriate confirmation dialog.
///
/// Returns `true` if the user confirmed, `false` if cancelled or dismissed.
///
/// * iOS — [CupertinoAlertDialog]
/// * Android — [AlertDialog]
Future<bool> showAdaptiveConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String cancelText = 'Cancel',
  String confirmText = 'Confirm',
  bool isDestructive = false,
}) async {
  if (_isIOS) {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  } else {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ── Date picker ───────────────────────────────────────────────────────────────

/// Shows a platform-appropriate date picker.
///
/// * iOS — [CupertinoDatePicker] inside a modal bottom sheet with
///   Cancel / Done buttons.
/// * Android — [showDatePicker].
///
/// Returns the selected [DateTime] or `null` if cancelled.
Future<DateTime?> showAdaptiveDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  if (_isIOS) {
    // Mutable outside the builder so the Done callback captures the latest
    // value scrolled to by the user.
    DateTime tempDate = initialDate;

    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.pop(ctx, tempDate),
                  child: const Text('Done'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initialDate,
                minimumDate: firstDate,
                maximumDate: lastDate,
                onDateTimeChanged: (date) => tempDate = date,
              ),
            ),
          ],
        ),
      ),
    );
  } else {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }
}

// ── Activity indicator ────────────────────────────────────────────────────────

/// A platform-appropriate activity indicator widget.
///
/// * iOS — [CupertinoActivityIndicator]
/// * Android — [CircularProgressIndicator]
///
/// Has a `const` constructor so it can be used inside `const` widget trees.
class AdaptiveActivityIndicator extends StatelessWidget {
  final Color? color;

  /// Only used on Android; ignored by [CupertinoActivityIndicator].
  final double strokeWidth;

  const AdaptiveActivityIndicator({
    super.key,
    this.color,
    this.strokeWidth = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    if (_isIOS) {
      return CupertinoActivityIndicator(color: color);
    }
    return CircularProgressIndicator(color: color, strokeWidth: strokeWidth);
  }
}
