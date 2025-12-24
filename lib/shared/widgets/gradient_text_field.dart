import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GradientTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;

  const GradientTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
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
    final borderRadius = BorderRadius.circular(18);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: _isFocused ? null : AppColors.border,
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: const Color(0xFF9B5DE5).withOpacity(0.22),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: const Color(0xFFF47C7C).withOpacity(0.12),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
        gradient: _isFocused
            ? const LinearGradient(
                colors: [
                  Color(0xFF7B2FF7),
                  Color(0xFF9B5DE5),
                  Color(0xFFC65BF0),
                  Color(0xFFF26CA7),
                  Color(0xFFFF7AA2),
                  Color(0xFFB66DFF),
                  Color(0xFF7B2FF7),
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
          decoration: InputDecoration(
            hintText: widget.label,
            prefixIcon: Icon(widget.prefixIcon),
            suffixIcon: widget.suffixIcon,
            filled: true,
            fillColor: AppColors.inputFill,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            hintStyle: const TextStyle(color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}
