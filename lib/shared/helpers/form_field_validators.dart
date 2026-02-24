import 'enums/form_field_type.dart';

String? validateField(String? value, FormFieldType type, [String? originalPassword]) {
  final trimmed = value?.trim() ?? '';
  const int passwordLen = 8;

  if (trimmed.isEmpty) {
    if (type == FormFieldType.email) return 'Email is required';
    if (type == FormFieldType.phone) return 'Phone is required';
    if (type == FormFieldType.password) return 'Password is required';
    if (type == FormFieldType.confirmPassword) return 'Confirm password is required';
    if (type == FormFieldType.number) return 'Number is required';
    if (type == FormFieldType.name) return 'Name is required';
    if (type == FormFieldType.dob) return 'Date of birth is required';
    return 'This field is required';
  }

  if (type == FormFieldType.email) {
    final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(trimmed)) return 'Invalid email address';
  } else if (type == FormFieldType.phone) {
    final phoneRegex = RegExp(r'^(1|3|9)\d{8}$');
    if (!phoneRegex.hasMatch(trimmed)) return 'Invalid phone number';
  } else if (type == FormFieldType.password) {
    if (trimmed.length < passwordLen) return 'Password must be at least $passwordLen characters';
    if (!RegExp(r'[a-zA-Z]').hasMatch(trimmed)) return 'Password must contain at least one letter';
    if (!RegExp(r'[0-9]').hasMatch(trimmed)) return 'Password must contain at least one number';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(trimmed)) return 'Password must contain at least one special character';
  } else if (type == FormFieldType.confirmPassword) {
    if (originalPassword != null && trimmed != originalPassword.trim()) return 'Passwords do not match';
  } else if (type == FormFieldType.number) {
    if (double.tryParse(trimmed) == null) return 'Invalid number';
  }

  return null;
}
