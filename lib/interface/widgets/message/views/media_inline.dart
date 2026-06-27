import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

// 内联媒体不可用占位（各 View 共用）。
class MediaInlineUnsupported extends StatelessWidget {
  final double width;
  final double height;
  final IconData icon;
  final String label;

  const MediaInlineUnsupported({
    super.key,
    required this.width,
    required this.height,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FlareThemeTokens.bgHover,
        borderRadius: BorderRadius.circular(FlareThemeTokens.radiusLg),
        border: Border.all(color: FlareThemeTokens.borderPrimary),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: FlareThemeTokens.textSecondary),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: FlareThemeTokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
