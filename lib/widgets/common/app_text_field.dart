import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_keyboard_dismiss.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscureText = false,
    this.maxLines = 1,
    this.onChanged,
    this.validator,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        suffixIcon: suffixIcon,
      ),
      keyboardType: keyboardType,
      textInputAction:
          textInputAction ??
          (maxLines == 1 ? TextInputAction.done : TextInputAction.newline),
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      onFieldSubmitted: maxLines == 1 ? (_) => dismissAppKeyboard() : null,
      onTapOutside: (_) => dismissAppKeyboard(),
      onEditingComplete: maxLines == 1 ? dismissAppKeyboard : null,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
    );
  }
}
