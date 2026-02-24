import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/themes/app_colors.dart';

enum SnackBarStatus { success, warning, error, connected, disconnected, general }

void showSnack({
  String? content = 'This functionality is under development',
  SnackBarStatus status = SnackBarStatus.warning,
  bool showCloseIcon = true,
  Duration duration = const Duration(seconds: 5),
  double bottomMargin = 50,
  SnackBarAction? action,
}) {
  final BuildContext? context = Get.context;
  final behavior = SnackBarBehavior.floating;

  if (context == null) return;

  Color backgroundColor;
  switch (status) {
    case SnackBarStatus.success:
      backgroundColor = AppColors.snackSuccessColor;
      break;
    case SnackBarStatus.warning:
      backgroundColor = AppColors.snackWarningColor;
      break;
    case SnackBarStatus.error:
      backgroundColor = AppColors.snackErrorColor;
      break;
    case SnackBarStatus.general:
      backgroundColor = AppColors.snackGeneralColor;
      break;
    case SnackBarStatus.connected:
      backgroundColor = Colors.green.shade100;
      break;
    case SnackBarStatus.disconnected:
      backgroundColor = Colors.blueGrey;
      break;
  }

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      elevation: 0,
      content: Text(
        content!,
        style: TextStyle(color: status == SnackBarStatus.disconnected ? Colors.white : Colors.black),
      ),
      backgroundColor: backgroundColor,
      behavior: behavior,
      margin: behavior == SnackBarBehavior.floating ? EdgeInsets.only(left: 16, right: 16, bottom: bottomMargin) : null,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      duration: action != null ? Duration.zero : duration,
      dismissDirection: DismissDirection.horizontal,
      showCloseIcon: showCloseIcon,
      closeIconColor: status == SnackBarStatus.disconnected ? Colors.white : Colors.black,
      action: action,
    ),
  );
}
