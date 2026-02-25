import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/themes/app_colors.dart';
import '../../helpers/enums/form_field_type.dart';
import '../../helpers/form_field_validators.dart';
import '../../helpers/input_formatter.dart';

class AppTextFormField extends StatefulWidget {
  final String? label;
  final TextEditingController? controller;
  final TextEditingController? matchController;
  final String? initialValue;
  final FormFieldType type;
  final String? hintText;
  final TextStyle? hintStyle;
  final String? helperText;
  final TextStyle? helperStyle;
  final Widget? prefixIcon;
  final bool showIsoCodeOnly;
  final String isoCode;
  final Widget? suffixIcon;
  final Color? prefixIconColor;
  final Color? suffixIconColor;
  final bool obscureText;
  final int? maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final Function(String)? onChanged;
  final Function()? onTap;
  final Function(PointerDownEvent)? onTapOutside;
  final String? Function(String?)? validator;
  final bool showCounter;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool enabled;
  final TextCapitalization textCapitalization;

  const AppTextFormField({
    super.key,
    this.label,
    this.controller,
    this.matchController,
    this.initialValue,
    this.type = FormFieldType.general,
    this.hintText,
    this.hintStyle,
    this.helperText,
    this.helperStyle,
    this.prefixIcon,
    this.showIsoCodeOnly = false,
    this.isoCode = '880',
    this.suffixIcon,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.textInputAction,
    this.onChanged,
    this.onTap,
    this.onTapOutside,
    this.validator,
    this.showCounter = false,
    this.focusNode,
    this.readOnly = false,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIconColor = AppColors.primaryColor,
    this.suffixIconColor = AppColors.primaryColor,
  });

  @override
  State<AppTextFormField> createState() => _AppTextFormFieldState();
}

class _AppTextFormFieldState extends State<AppTextFormField> {
  late bool isObscured;

  @override
  void initState() {
    super.initState();
    isObscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller != null && widget.initialValue != null) {
      throw FlutterError('TheTextFormField cannot have both controller and initialValue.');
    }

    if (widget.type == FormFieldType.readOnlyDisplay) {
      return TextFormField(
        controller: widget.controller,
        readOnly: true,
        style: const TextStyle(
          color: Color(0xFF20262E),
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 1,
          letterSpacing: 0.50,
        ),
        decoration: const InputDecoration(
          border: UnderlineInputBorder(borderSide: BorderSide.none),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide.none),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide.none),
          labelText: '',
          floatingLabelStyle: TextStyle(
            color: Color(0xFF6C7B6F),
            fontSize: 20,
            fontWeight: FontWeight.w400,
            height: 1,
            letterSpacing: 0.50,
          ),
          contentPadding: EdgeInsets.zero,
        ),
      );
    }

    return TextFormField(
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initialValue : null,
      focusNode: widget.focusNode,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      keyboardType: (widget.maxLines != null && widget.maxLines! > 1)
          ? TextInputType.multiline
          : getKeyboardType(widget.type),
      textCapitalization: widget.textCapitalization,
      obscureText: (widget.type == FormFieldType.password || widget.type == FormFieldType.confirmPassword)
          ? isObscured
          : widget.obscureText,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      textInputAction: widget.textInputAction ??
          ((widget.maxLines != null && widget.maxLines! > 1)
              ? TextInputAction.newline
              : TextInputAction.done),
      onChanged: (value) {
        widget.onChanged?.call(value);

        if (widget.type == FormFieldType.phone) {
          final trimmed = value.trim();
          final cleaned = trimmed.startsWith('0') ? trimmed.substring(1) : trimmed;

          if (cleaned != value) {
            widget.controller?.text = cleaned;
            widget.controller?.selection =
                TextSelection.collapsed(offset: cleaned.length);
          }

          final isValidBDPhone = RegExp(r'^(1)[3-9]\d{8}$').hasMatch(cleaned);
          if (isValidBDPhone) FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      onTap: widget.onTap,
      onTapOutside: widget.onTapOutside ?? (_) => FocusManager.instance.primaryFocus?.unfocus(),
      inputFormatters: getInputFormatters(widget.type),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: widget.validator ??
              (value) => validateField(
            value,
            widget.type,
            widget.matchController?.text,
          ),
      buildCounter: widget.showCounter
          ? (context, {required currentLength, required isFocused, maxLength}) => Text(
                '\$currentLength/\${maxLength ?? ""}',
                style: const TextStyle(color: Color(0xFFA2A2A2), fontSize: 14, fontWeight: FontWeight.w400, height: 1.43),
              )
          : null,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w400,
        height: 1,
        letterSpacing: 0.50,
      ),
      decoration: InputDecoration(
        label: widget.label != null
            ? Text(
                widget.label!,
                style: const TextStyle(
                  color: Color(0xFF868B8F),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.67,
                  letterSpacing: 0.20,
                ),
              )
            : null,
        hintText: widget.hintText,
        hintStyle: widget.hintStyle,
        helperText: widget.helperText,
        helperStyle: widget.helperStyle,
        prefixIcon: widget.prefixIcon ?? getDefaultPrefixIcon(widget.type, widget.prefixIconColor),
        suffixIcon: widget.type == FormFieldType.password || widget.type == FormFieldType.confirmPassword
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  icon: Icon(isObscured ? CupertinoIcons.eye : CupertinoIcons.eye_slash, color: widget.suffixIconColor),
                  onPressed: () => setState(() => isObscured = !isObscured),
                ),
              )
            : widget.suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        border: OutlineInputBorder(
          borderSide: const BorderSide(width: 1, color: Color(0xFFD8D9DD)),
          borderRadius: BorderRadius.circular(6),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: const Color(0xFF868B8F),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(width: 2, color: AppColors.primaryColor),
        ),
        floatingLabelStyle: const TextStyle(color: AppColors.primaryColor),
      ),
    );
  }

  TextInputType getKeyboardType(FormFieldType type) {
    switch (type) {
      case FormFieldType.name:
        return TextInputType.name;
      case FormFieldType.phone:
        return TextInputType.phone;
      case FormFieldType.email:
        return TextInputType.emailAddress;
      case FormFieldType.number:
        return TextInputType.number;
      case FormFieldType.amount:
        return TextInputType.numberWithOptions(decimal: true);
      case FormFieldType.percentage:
        return TextInputType.number;
      case FormFieldType.password:
        return TextInputType.visiblePassword;
      default:
        return TextInputType.text;
    }
  }

  Widget? getDefaultPrefixIcon(FormFieldType type, Color? iconColor) {
    switch (type) {
      case FormFieldType.name:
        return Icon(CupertinoIcons.person, color: iconColor);
      case FormFieldType.phone:
        return widget.showIsoCodeOnly
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Text(
                  widget.isoCode,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.29,
                    letterSpacing: 0.16,
                    color: Colors.black54,
                  ),
                ),
              )
            : Icon(CupertinoIcons.phone, color: iconColor);
      case FormFieldType.email:
        return Icon(CupertinoIcons.mail, color: iconColor);
      case FormFieldType.password:
      case FormFieldType.confirmPassword:
        return Icon(CupertinoIcons.lock, color: iconColor);
      case FormFieldType.number:
        return Icon(CupertinoIcons.number, color: iconColor);
      case FormFieldType.amount:
        return Icon(CupertinoIcons.money_pound, color: iconColor);
      case FormFieldType.percentage:
        return Icon(CupertinoIcons.percent, color: iconColor);
      default:
        return null;
    }
  }
}
