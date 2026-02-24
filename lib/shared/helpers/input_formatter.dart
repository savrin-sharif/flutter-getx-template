import 'package:flutter/services.dart';

import 'enums/form_field_type.dart';

List<TextInputFormatter>? getInputFormatters(FormFieldType type) {
  switch (type) {
    case FormFieldType.name:
      return [FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]"))];
    case FormFieldType.phone:
      return [FilteringTextInputFormatter.digitsOnly];
    case FormFieldType.email:
      return [FilteringTextInputFormatter.deny(RegExp(r"\s"))];
    case FormFieldType.number || FormFieldType.amount || FormFieldType.percentage:
      return [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    case FormFieldType.password:
    case FormFieldType.confirmPassword:
      return null;
    case FormFieldType.dob:
      return [FilteringTextInputFormatter.allow(RegExp(r'[0-9/-]'))];
    case FormFieldType.general:
      return null;
    case FormFieldType.readOnlyDisplay:
      throw UnimplementedError();
  }
}
