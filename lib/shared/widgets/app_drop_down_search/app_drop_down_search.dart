import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppDropdownSearch extends StatefulWidget {
  final List<String> initialItems;
  final String labelText;
  final TextStyle? labelTextStyle;
  final String? hintText;
  final String newItemLabel;
  final String validationText;
  final String dialogTitle;
  final ValueChanged<String?>? onChanged;
  final double dropdownWidth;
  final bool showLabelText;
  final bool showLeadingIcon;
  final bool allowNewItemAddition;
  final bool enabled;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode autoValidateMode;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final Widget? expandedTrailingIcon;
  final TextStyle? hintTextStyle;
  final Color? clearIconColor;

  const AppDropdownSearch({
    super.key,
    this.controller,
    this.initialItems = const ["Apple", "Banana", "Orange", "Grapes", "Mango"],
    this.labelText = "Select an Item",
    this.labelTextStyle,
    this.hintText,
    this.newItemLabel = "Enter new item",
    this.validationText = "Please enter a new item",
    this.dialogTitle = "Add New Item",
    this.onChanged,
    this.dropdownWidth = double.infinity,
    this.showLabelText = true,
    this.showLeadingIcon = true,
    this.allowNewItemAddition = true,
    this.enabled = true,
    this.validator,
    this.autoValidateMode = AutovalidateMode.disabled,
    this.leadingIcon,
    this.trailingIcon,
    this.expandedTrailingIcon,
    this.hintTextStyle,
    this.clearIconColor,
  });

  @override
  State<AppDropdownSearch> createState() => _AppDropdownSearchState();
}

class _AppDropdownSearchState extends State<AppDropdownSearch> {
  late List<String> items;
  String? selectedItem;
  late TextEditingController itemController;
  final TextEditingController newItemController = TextEditingController();
  final FocusNode menuFocusNode = FocusNode();
  final FocusNode newItemFocusNode = FocusNode();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  FormFieldState<String>? _formFieldState;
  String? _lastNotifiedValue;

  @override
  void initState() {
    super.initState();
    items = List<String>.from(widget.initialItems);
    itemController = widget.controller ?? TextEditingController();
    itemController.addListener(_syncSelectedItemWithController);
    selectedItem = itemController.text.isNotEmpty ? itemController.text : null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyFormField());
  }

  @override
  void didUpdateWidget(covariant AppDropdownSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.initialItems, widget.initialItems)) {
      setState(() {
        items = List<String>.from(widget.initialItems);
        if (selectedItem == null || !items.contains(selectedItem)) {
          selectedItem = null;
          itemController.clear();
        }
      });
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_syncSelectedItemWithController);
      itemController = widget.controller ?? TextEditingController();
      itemController.addListener(_syncSelectedItemWithController);
      setState(() => selectedItem = itemController.text.isNotEmpty ? itemController.text : null);
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyFormField());
    }
  }

  void _syncSelectedItemWithController() {
    final text = itemController.text;
    if (text.isEmpty && selectedItem != null) {
      setState(() => selectedItem = null);
    } else if (text.isNotEmpty && selectedItem != text) {
      setState(() => selectedItem = text);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyFormField());
  }

  void _notifyFormField() {
    if (_formFieldState != null && selectedItem != _lastNotifiedValue) {
      _formFieldState!.didChange(selectedItem);
      _lastNotifiedValue = selectedItem;
    }
  }

  void showAddNewItemDialog() {
    showDialog(
      context: context,
      useSafeArea: true,
      builder: (context) => AlertDialog(
        title: Text(widget.dialogTitle),
        content: SizedBox(
          height: 200,
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: newItemController,
                  focusNode: newItemFocusNode,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Enter new item',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? widget.validationText
                      : null,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onTapOutside: (_) => newItemFocusNode.unfocus(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() { selectedItem = null; itemController.clear(); });
              newItemController.clear();
              menuFocusNode.unfocus();
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newItem = newItemController.text.trim();
                if (newItem.isNotEmpty) {
                  setState(() {
                    items.add(newItem);
                    selectedItem = newItem;
                    itemController.text = newItem;
                  });
                  widget.onChanged?.call(selectedItem);
                  newItemController.clear();
                  menuFocusNode.unfocus();
                  Navigator.pop(context);
                }
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    itemController.removeListener(_syncSelectedItemWithController);
    if (widget.controller == null) itemController.dispose();
    newItemController.dispose();
    menuFocusNode.dispose();
    newItemFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<DropdownMenuEntry<String>> baseEntries = [
      if (widget.allowNewItemAddition)
        const DropdownMenuEntry(value: "new", label: "Add New Item", leadingIcon: Icon(Icons.add)),
      ...items.map((value) => DropdownMenuEntry(value: value, label: value)),
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: FormField<String>(
        autovalidateMode: widget.autoValidateMode,
        validator: widget.validator,
        builder: (FormFieldState<String> field) {
          _formFieldState = field;

          if (selectedItem != field.value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                field.didChange(selectedItem);
                _lastNotifiedValue = selectedItem;
              }
            });
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownMenu<String>(
                width: widget.dropdownWidth,
                controller: itemController,
                focusNode: menuFocusNode,
                label: widget.showLabelText
                    ? Text(
                        widget.labelText,
                        style: const TextStyle(
                          color: Color(0xFF868B8F),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.67,
                          letterSpacing: 0.20,
                        ),
                      )
                    : null,
                textStyle: widget.labelTextStyle,
                hintText: widget.hintText,
                enableSearch: true,
                enableFilter: true,
                requestFocusOnTap: true,
                filterCallback: (entries, filter) {
                  final trimmed = filter.trim().toLowerCase();
                  final filtered = entries
                      .where((entry) => entry.value != "new" && entry.label.toLowerCase().contains(trimmed))
                      .toList();

                  if (trimmed.isEmpty) return entries;

                  if (filtered.isEmpty) {
                    return [
                      if (widget.allowNewItemAddition) entries.firstWhere((e) => e.value == "new"),
                      const DropdownMenuEntry<String>(value: "no-match", label: "No match found", enabled: false),
                    ];
                  }

                  return [
                    if (widget.allowNewItemAddition) entries.firstWhere((e) => e.value == "new"),
                    ...filtered,
                  ];
                },
                inputDecorationTheme: InputDecorationTheme(
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                  hintStyle: widget.hintTextStyle,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: field.hasError ? Theme.of(context).colorScheme.error : const Color(0xFFD8D9DD),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: field.hasError ? Theme.of(context).colorScheme.error : const Color(0xFFD8D9DD),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: field.hasError ? Theme.of(context).colorScheme.error : Theme.of(context).primaryColor,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                menuStyle: MenuStyle(
                  elevation: WidgetStateProperty.all(0),
                  maximumSize: WidgetStateProperty.all(const Size.fromHeight(200)),
                  alignment: Alignment.bottomLeft,
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: Colors.black),
                    ),
                  ),
                ),
                onSelected: (item) {
                  if (item == "new") {
                    setState(() => selectedItem = null);
                    menuFocusNode.unfocus();
                    showAddNewItemDialog();
                  } else {
                    setState(() {
                      selectedItem = item;
                      itemController.text = item!;
                    });
                    field.didChange(item);
                    menuFocusNode.unfocus();
                    widget.onChanged?.call(item);
                  }
                },
                leadingIcon: widget.leadingIcon ?? (widget.showLeadingIcon ? const Icon(Icons.search) : null),
                trailingIcon: (itemController.text.isNotEmpty)
                    ? GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedItem = null;
                            itemController.clear();
                          });
                          field.didChange(null);
                          menuFocusNode.unfocus();
                          widget.onChanged?.call(null);
                        },
                        child: Icon(Icons.remove_circle_outline, color: widget.clearIconColor),
                      )
                    : widget.trailingIcon,
                selectedTrailingIcon: widget.expandedTrailingIcon,
                dropdownMenuEntries: baseEntries,
                enabled: widget.enabled,
              ),
              SizedBox(
                height: 20,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: field.errorText != null
                      ? Text(field.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12))
                      : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
