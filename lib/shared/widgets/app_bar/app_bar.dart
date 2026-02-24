import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TheAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Key? appKey;
  final String? title;
  final Widget? titleWidget;
  final bool centerTitle;
  final bool isMultiSelectionMode;
  final int selectedCount;
  final List<Widget>? actions;
  final VoidCallback? onSelectAll;
  final VoidCallback? onDeselectAll;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool showBackArrow;
  final Color? arrowBackColor;
  final Widget? leadingWidget;
  final bool forceMaterialTransparency;
  final Color? backgroundColor;
  final double? toolbarHeight;
  final double? leadingWidth;
  final double? titleSpacing;
  final TextStyle? titleTextStyle;

  const TheAppBar({
    super.key,
    this.appKey,
    this.title,
    this.titleWidget,
    this.centerTitle = true,
    this.isMultiSelectionMode = false,
    this.selectedCount = 0,
    this.actions,
    this.onSelectAll,
    this.onDeselectAll,
    this.onDelete,
    this.onEdit,
    this.showBackArrow = true,
    this.arrowBackColor,
    this.leadingWidget,
    this.forceMaterialTransparency = true,
    this.backgroundColor,
    this.toolbarHeight,
    this.leadingWidth,
    this.titleSpacing,
    this.titleTextStyle,
  });

  TextStyle get defaultTitleStyle => GoogleFonts.lexend(
        color: const Color(0xFF1F1F1F),
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 0.67,
        letterSpacing: 0.40,
      );

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      key: appKey,
      title: isMultiSelectionMode
          ? Text('$selectedCount Selected', style: titleTextStyle ?? defaultTitleStyle)
          : (titleWidget ?? Text(title ?? '', style: titleTextStyle ?? defaultTitleStyle)),
      centerTitle: isMultiSelectionMode ? false : centerTitle,
      automaticallyImplyLeading: false,
      leading: showBackArrow
          ? IconButton(
              onPressed: () {
                if (isMultiSelectionMode) {
                  onDeselectAll?.call();
                } else {
                  Navigator.pop(context);
                }
              },
              icon: Icon(Icons.arrow_back, color: arrowBackColor ?? Colors.black),
            )
          : leadingWidget,
      forceMaterialTransparency: forceMaterialTransparency,
      backgroundColor: backgroundColor,
      toolbarHeight: toolbarHeight ?? 80,
      leadingWidth: leadingWidth,
      titleSpacing: titleSpacing,
      actions: isMultiSelectionMode && selectedCount > 0
          ? <Widget>[
              if (onSelectAll != null) IconButton(onPressed: onSelectAll, icon: const Icon(Icons.select_all)),
              if (onDeselectAll != null) IconButton(onPressed: onDeselectAll, icon: const Icon(Icons.deselect)),
              if (onDelete != null) IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_forever, color: Colors.red)),
              if (selectedCount == 1 && onEdit != null) IconButton(onPressed: onEdit, icon: const Icon(Icons.edit)),
            ]
          : actions,
    );
  }
}
