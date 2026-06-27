import 'package:extended_text_field/extended_text_field.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

/// 会话内统一输入外观：白底、无描边、小圆角；聚焦无主题描边。
/// 用于主栏输入、表情面板草稿、展开编辑器等，通过参数区分行数/展开按钮等。
class ComposerInlineTextField extends StatelessWidget {
  const ComposerInlineTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.minLines = 1,
    this.maxLines = 4,
    this.expands = false,
    this.enabled = true,
    this.maxLength,
    this.keyboardType,
    this.textAlignVertical,
    this.style = const TextStyle(
      fontSize: 15,
      height: 1.45,
      color: FlareThemeTokens.textPrimary,
    ),
    this.hintFontSize = 15,
    this.specialTextSpanBuilder,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onExpandPressed,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 5,
    ),
    this.borderRadius = 6,
    this.counterText = '',
    this.suffixIconConstraints = const BoxConstraints(
      minWidth: 40,
      minHeight: 0,
      maxHeight: double.infinity,
    ),
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final int? minLines;
  final int? maxLines;
  final bool expands;
  final bool enabled;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextAlignVertical? textAlignVertical;
  final TextStyle? style;
  final double hintFontSize;
  final SpecialTextSpanBuilder? specialTextSpanBuilder;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onExpandPressed;
  final EdgeInsetsGeometry contentPadding;
  final double borderRadius;
  final String? counterText;
  final BoxConstraints? suffixIconConstraints;

  @override
  Widget build(BuildContext context) {
    final expandColor = FlareThemeTokens.textSecondary.withValues(alpha: 0.88);
    final decoration = InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: FlareThemeTokens.textSecondary.withValues(alpha: 0.75),
        fontSize: hintFontSize,
        height: style?.height ?? 1.45,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      isDense: true,
      contentPadding: contentPadding,
      counterText: counterText,
      suffixIcon: onExpandPressed == null
          ? null
          : Align(
              widthFactor: 1,
              heightFactor: 1,
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: '展开输入',
                style: IconButton.styleFrom(
                  foregroundColor: expandColor,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
                ),
                onPressed: onExpandPressed,
                icon: const Icon(Icons.open_in_full_outlined, size: 18),
              ),
            ),
      suffixIconConstraints: suffixIconConstraints,
    );

    final field = expands
        ? ExtendedTextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            expands: true,
            maxLines: null,
            minLines: null,
            maxLength: maxLength,
            keyboardType: keyboardType ?? TextInputType.multiline,
            textAlignVertical: textAlignVertical ?? TextAlignVertical.top,
            style: style,
            specialTextSpanBuilder: specialTextSpanBuilder,
            textInputAction: textInputAction,
            decoration: decoration,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          )
        : ExtendedTextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            minLines: minLines,
            maxLines: maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType,
            textAlignVertical: textAlignVertical,
            style: style,
            specialTextSpanBuilder: specialTextSpanBuilder,
            textInputAction: textInputAction,
            decoration: decoration,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          );

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          isDense: true,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: FlareThemeTokens.bgPrimary,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: field,
      ),
    );
  }
}
