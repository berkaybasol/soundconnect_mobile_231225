import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class GradientTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  const GradientTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  State<GradientTextField> createState() => _GradientTextFieldState();
}

class _GradientTextFieldState extends State<GradientTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    final borderColor = theme.dividerColor;
    final mutedColor =
        theme.inputDecorationTheme.hintStyle?.color ??
        theme.colorScheme.onSurfaceVariant;
    final borderRadius = BorderRadius.circular(18);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: _isFocused ? null : borderColor,
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppColors.neonPurpleGradient[1].withValues(
                    alpha: 0.22,
                  ),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: AppColors.coral.withValues(alpha: 0.12),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
        gradient: _isFocused
            ? LinearGradient(
                colors: [
                  AppColors.neonPurpleGradient[0],
                  AppColors.neonPurpleGradient[1],
                  AppColors.neonPurpleGradient[2],
                  AppColors.neonPurpleGradient[3],
                  AppColors.neonPurpleGradient[4],
                  AppColors.neonPurpleGradient[5],
                  AppColors.neonPurpleGradient[0],
                ],
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: TextField(
          focusNode: _focusNode,
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          inputFormatters: widget.inputFormatters,
          onSubmitted: widget.onSubmitted,
          enabled: widget.enabled,
          decoration: InputDecoration(
            hintText: widget.label,
            prefixIcon: Icon(widget.prefixIcon),
            suffixIcon: widget.suffixIcon,
            filled: true,
            fillColor: fillColor,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            hintStyle: TextStyle(color: mutedColor),
          ),
        ),
      ),
    );
  }
}
