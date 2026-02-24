import 'package:flutter/material.dart';

import '../../../core/themes/app_colors.dart';

enum LoaderType { circular, linear }

Widget showLoader({
  LoaderType type = LoaderType.circular,
  double? value,
  Color progressColor = AppColors.primaryColor,
  Color? backgroundColor,
  double strokeWidth = 2.0,
  Color? triangleColor,
  double triangleSize = 12,
}) {
  switch (type) {
    case LoaderType.linear:
      return LinearProgressIndicator(
        value: value,
        backgroundColor: backgroundColor ?? Colors.grey.shade300,
        color: progressColor,
      );
    case LoaderType.circular:
      return CircularProgressIndicator(
        value: value,
        color: progressColor,
        strokeWidth: strokeWidth,
      );
  }
}
