import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../progress_loader/progress_loader.dart';

enum IconPosition { left, right }

enum LoadingStyle { simple, morphing }

class AppMaterialButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final double height;
  final double width;
  final double elevation;
  final double borderRadius;
  final ShapeBorder? shape;
  final Color? backgroundColor;
  final Color? disabledColor;
  final Color? textColor;
  final Widget? child;

  final Widget? icon;
  final IconPosition iconPosition;
  final double? spacerWidth;
  final LoadingStyle loadingStyle;

  const AppMaterialButton({
    super.key,
    this.label = 'Material Button',
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.height = 52,
    this.width = double.infinity,
    this.elevation = 0,
    this.borderRadius = 8,
    this.shape,
    this.backgroundColor,
    this.disabledColor,
    this.textColor = Colors.white,
    this.child,
    this.icon,
    this.iconPosition = IconPosition.left,
    this.spacerWidth,
    this.loadingStyle = LoadingStyle.morphing,
  });

  factory AppMaterialButton.icon({
    Key? key,
    required String label,
    required Widget icon,
    double spacerWidth = 8,
    VoidCallback? onPressed,
    IconPosition iconPosition = IconPosition.left,
    bool isLoading = false,
    bool isDisabled = false,
    double height = 48,
    double width = double.infinity,
    double elevation = 0,
    double borderRadius = 8,
    ShapeBorder? shape,
    Color? backgroundColor,
    Color? disabledColor,
    Color? textColor = Colors.white,
    LoadingStyle loadingStyle = LoadingStyle.morphing,
  }) {
    return AppMaterialButton(
      key: key,
      label: label,
      icon: icon,
      spacerWidth: spacerWidth,
      iconPosition: iconPosition,
      onPressed: onPressed,
      isLoading: isLoading,
      isDisabled: isDisabled,
      height: height,
      width: width,
      elevation: elevation,
      borderRadius: borderRadius,
      shape: shape,
      backgroundColor: backgroundColor,
      disabledColor: disabledColor,
      textColor: textColor,
      loadingStyle: loadingStyle,
    );
  }

  // Computed property: button is disabled if either isDisabled or isLoading is true
  bool get _isEffectivelyDisabled => isDisabled || isLoading;

  @override
  Widget build(BuildContext context) {
    if (loadingStyle == LoadingStyle.morphing) {
      return _buildMorphingButton(context);
    }
    return _buildSimpleButton(context);
  }

  Widget _buildSimpleButton(BuildContext context) {
    final effectiveOnPressed = _isEffectivelyDisabled ? null : (onPressed ?? () {});

    final labelWidget = Text(
      label,
      style: GoogleFonts.inter(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.34),
    );

    final content = isLoading
      ? SizedBox(width: 24, height: 24, child: showLoader(progressColor: Colors.white))
      : _buildAlignedContent(labelWidget);

    return MaterialButton(
      onPressed: effectiveOnPressed,
      elevation: elevation,
      color: backgroundColor ?? Theme.of(context).primaryColor,
      disabledColor: disabledColor ?? Theme.of(context).primaryColor,
      shape: shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius)),
      height: height,
      minWidth: width,
      child: child ?? content,
    );
  }

  Widget _buildMorphingButton(BuildContext context) {
    final effectiveOnPressed = _isEffectivelyDisabled ? null : (onPressed ?? () {});

    final labelWidget = Text(
      label,
      style: GoogleFonts.inter(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.34),
    );

    final content = _buildAlignedContent(labelWidget);

    return LayoutBuilder(
      builder: (context, constraints) {
        final actualWidth =
        width == double.infinity ? constraints.maxWidth : width;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: isLoading ? height : actualWidth,
          height: height,
          child: MaterialButton(
            onPressed: effectiveOnPressed,
            elevation: elevation,
            color: backgroundColor ?? Theme.of(context).primaryColor,
            disabledColor: disabledColor ?? Theme.of(context).primaryColor,
            shape: shape ??
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  isLoading ? height / 2 : borderRadius,
                ),
              ),
            padding: EdgeInsets.zero,
            minWidth: 0,
            height: height,
            child: child ??
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder:
                    (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                  );
                },
                child: isLoading
                    ? SizedBox(
                  key: const ValueKey('loader'),
                  width: 24,
                  height: 24,
                  child: showLoader(progressColor: Colors.white),
                )
                    : SizedBox(
                  key: const ValueKey('content'),
                  child: content,
                ),
              ),
          ),
        );
      },
    );
  }

  Widget _buildAlignedContent(Widget labelWidget) {
    if (icon == null) return labelWidget;

    final spacing = spacerWidth ?? 8;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: iconPosition == IconPosition.left
          ? [
        icon!,
        SizedBox(width: spacing),
        labelWidget,
      ]
          : [
        labelWidget,
        SizedBox(width: spacing),
        icon!,
      ],
    );
  }
}
