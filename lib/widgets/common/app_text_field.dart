import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.keyboardType,
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
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
    );
  }
}
