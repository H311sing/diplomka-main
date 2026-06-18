import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

/// Styled text input used on the auth screens. Wraps a [TextFormField]
/// so it can be plugged into a `Form` with a [validator] — the error
/// message shows up under the field (red, in the standard Flutter
/// position).
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final AutovalidateMode autovalidateMode;
  final TextInputAction? textInputAction;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.suffix,
    this.validator,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        color: Colors.white.withOpacity(0.05),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        autovalidateMode: autovalidateMode,
        textInputAction: textInputAction,
        style: GoogleFonts.inter(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white38),
          prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          errorStyle: GoogleFonts.inter(
              color: Colors.redAccent.shade100,
              fontSize: 11,
              fontWeight: FontWeight.w500),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }
}

/// Common validators — reusable across forms.
class Validators {
  static String? notEmpty(String? v, {String label = 'This field'}) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? minLength(String? v, int min,
      {String label = 'This field'}) {
    if (v == null || v.isEmpty) return '$label is required';
    if (v.length < min) return '$label must be at least $min characters';
    return null;
  }

  static String? name(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter your name';
    if (v.trim().length < 2) return 'Name is too short';
    if (v.trim().length > 50) return 'Name is too long';
    return null;
  }

  static final _emailRegex =
      RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter your email';
    if (!_emailRegex.hasMatch(v.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Please enter a password';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? loginPassword(String? v) {
    if (v == null || v.isEmpty) return 'Please enter your password';
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    if (v == null || v.isEmpty) return 'Please repeat your password';
    if (v != original) return 'Passwords do not match';
    return null;
  }

  static String? positiveNumberInRange(
    String? v, {
    required double min,
    required double max,
    required String label,
    bool allowEmpty = true,
  }) {
    if (v == null || v.trim().isEmpty) {
      return allowEmpty ? null : '$label is required';
    }
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null) return 'Enter a number';
    if (n < min || n > max) {
      return '$label must be between ${_fmt(min)} and ${_fmt(max)}';
    }
    return null;
  }

  static String? positiveIntInRange(
    String? v, {
    required int min,
    required int max,
    required String label,
    bool allowEmpty = true,
  }) {
    if (v == null || v.trim().isEmpty) {
      return allowEmpty ? null : '$label is required';
    }
    final n = int.tryParse(v.trim());
    if (n == null) return 'Enter a whole number';
    if (n < min || n > max) {
      return '$label must be between $min and $max';
    }
    return null;
  }

  static String _fmt(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}
