import 'package:flutter/cupertino.dart';
import '../../app/theme/colors.dart';
import 'glass_card.dart';

class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    required this.controller,
    this.placeholder,
    this.maxLines = 1,
    this.autofocus = false,
    this.onChanged,
    this.textStyle,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String? placeholder;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextStyle? textStyle;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    return GlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (prefixIcon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Icon(prefixIcon, size: 18, color: AppColors.textSecondary(brightness)),
            ),
          ],
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              maxLines: maxLines,
              autofocus: autofocus,
              onChanged: onChanged,
              decoration: const BoxDecoration(),
              padding: EdgeInsets.zero,
              style: textStyle ??
                  TextStyle(color: AppColors.textPrimary(brightness), fontSize: 16),
              placeholderStyle: TextStyle(color: AppColors.textSecondary(brightness)),
            ),
          ),
        ],
      ),
    );
  }
}
