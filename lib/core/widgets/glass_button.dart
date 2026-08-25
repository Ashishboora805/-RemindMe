import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../app/theme/colors.dart';

enum GlassButtonStyle { primary, secondary, destructive }

/// Standard tappable button with haptic feedback and a subtle press animation.
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = GlassButtonStyle.primary,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GlassButtonStyle style;
  final bool expand;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  double _scale = 1;

  Color _bg(Brightness b) {
    switch (widget.style) {
      case GlassButtonStyle.primary:
        return AppColors.projectAccents.first;
      case GlassButtonStyle.destructive:
        return AppColors.danger;
      case GlassButtonStyle.secondary:
        return AppColors.glassFill(b);
    }
  }

  Color _fg(Brightness b) {
    if (widget.style == GlassButtonStyle.secondary) {
      return AppColors.textPrimary(b);
    }
    return CupertinoColors.white;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final child = AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 90),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _bg(brightness),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: _fg(brightness), size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: TextStyle(
                color: _fg(brightness),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTapDown: widget.onPressed == null ? null : (_) => setState(() => _scale = 0.96),
      onTapCancel: widget.onPressed == null ? null : () => setState(() => _scale = 1),
      onTapUp: widget.onPressed == null
          ? null
          : (_) {
              setState(() => _scale = 1);
              HapticFeedback.lightImpact();
              widget.onPressed!();
            },
      child: widget.expand ? SizedBox(width: double.infinity, child: child) : child,
    );
  }
}
