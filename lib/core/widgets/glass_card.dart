import 'dart:ui';
import 'package:flutter/cupertino.dart';
import '../../app/theme/colors.dart';

/// Translucent, blurred card used everywhere in the app: project cards,
/// note cards, reminder cards, bottom sheets, dialogs.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.blurSigma = 24,
    this.onTap,
    this.margin,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final fill = AppColors.glassFill(brightness);
    final border =
        accent?.withValues(alpha: 0.35) ?? AppColors.glassBorder(brightness);

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: border, width: 1),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withValues(
                  alpha: brightness == Brightness.dark ? 0.35 : 0.06,
                ),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      return Padding(padding: margin!, child: _tappable(card));
    }
    return _tappable(card);
  }

  Widget _tappable(Widget child) {
    if (onTap == null) return child;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
