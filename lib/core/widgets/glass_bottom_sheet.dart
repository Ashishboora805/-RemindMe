import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;
import 'package:flutter/services.dart';
import '../../app/theme/colors.dart';

/// Presents [child] as a translucent, blurred modal bottom sheet with a
/// grabber handle. Use for "+" create actions, note options, etc.
Future<T?> showGlassBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
}) {
  HapticFeedback.mediumImpact();
  final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: _transparent,
    barrierColor: const Color(0x66000000),
    builder: (ctx) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassFill(brightness).withValues(
              alpha: brightness == Brightness.dark ? 0.85 : 0.9,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: AppColors.glassBorder(brightness)),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color:
                          AppColors.textSecondary(brightness).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  builder(ctx),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// Declared locally so this file needs no Material import beyond
// showModalBottomSheet itself.
const Color _transparent = Color(0x00000000);
