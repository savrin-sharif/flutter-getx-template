import 'package:flutter/material.dart';

class AppSearchableDropdown extends StatefulWidget {
  final List<String>? items;
  final String? labelText;
  final String? hintText;
  final double widthFactor;
  final double? menuHeight;
  final String? initialValue;
  final ValueChanged<String?>? onChanged;
  final TextEditingController? controller;
  final bool? enableSearch;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode autoValidateMode;
  final String noItemsText;
  final String noMatchText;
  final FocusNode? focusNode;

  const AppSearchableDropdown({
    super.key,
    this.items,
    this.labelText,
    this.hintText,
    this.widthFactor = 0.8,
    this.menuHeight = 200,
    this.initialValue,
    this.onChanged,
    this.controller,
    this.enableSearch = true,
    this.validator,
    this.autoValidateMode = AutovalidateMode.onUserInteraction,
    this.noItemsText = 'No item found',
    this.noMatchText = 'No match found',
    this.focusNode,
  });

  @override
  State<AppSearchableDropdown> createState() => _AppSearchableDropdownState();
}

class _AppSearchableDropdownState extends State<AppSearchableDropdown> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  String? _selectedValue;

  bool get _hasSelection =>
      _selectedValue != null && _selectedValue!.isNotEmpty;

  bool get enableSearch => widget.enableSearch ?? true;

  List<String> get _items => widget.items ?? const [];

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    if (!enableSearch) {
      _focusNode.canRequestFocus = false;
    }

    _selectedValue = widget.initialValue;
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }

    _controller.addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    if (!mounted || !enableSearch) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant AppSearchableDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.enableSearch != oldWidget.enableSearch) {
      _focusNode.canRequestFocus = enableSearch;
    }

    // If initialValue changes and there is no user selection yet,
    // update selection + controller text
    if (widget.initialValue != oldWidget.initialValue &&
        (_selectedValue == null || _selectedValue!.isEmpty)) {
      final newValue = widget.initialValue;
      if (newValue != null && newValue.isNotEmpty) {
        setState(() {
          _selectedValue = newValue;
          _controller.text = newValue;
        });
      }
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }

    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    super.dispose();
  }

  TextStyle get _emptyTextStyle => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.67,
    letterSpacing: 0.20,
    color: Colors.black54,
  );

  TextStyle get _itemTextStyle => const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.67,
    letterSpacing: 0.20,
  );

  List<DropdownMenuEntry<String>> _buildEntries() {
    final items = _items;

    // Case 1: no items at all
    if (items.isEmpty) {
      return [
        DropdownMenuEntry<String>(
          enabled: false,
          value: '__no_items__',
          label: widget.noItemsText,
          labelWidget: Text(widget.noItemsText, style: _emptyTextStyle),
        )
      ];
    }

    final query = _controller.text.trim().toLowerCase();
    final List<String> filtered = (enableSearch && query.isNotEmpty)
        ? items.where((x) => x.toLowerCase().contains(query)).toList()
        : items;

    // Case 2: search typed but nothing matches
    if (enableSearch && query.isNotEmpty && filtered.isEmpty) {
      return [
        DropdownMenuEntry<String>(
          enabled: false,
          value: '__no_match__',
          label: widget.noMatchText,
          labelWidget: Text(widget.noMatchText, style: _emptyTextStyle),
        )
      ];
    }

    return filtered.map(
      (item) => DropdownMenuEntry<String>(
        value: item,
        label: item,
        labelWidget: Text(item, style: _itemTextStyle),
      ),
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * widget.widthFactor;

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: FormField<String>(
            autovalidateMode: widget.autoValidateMode,
            validator: widget.validator,
            builder: (field) {
              if (_selectedValue != field.value) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  field.didChange(_selectedValue);
                });
              }

              final entries = _buildEntries();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownMenu<String>(
                    width: maxWidth,
                    controller: _controller,
                    focusNode: _focusNode,
                    initialSelection: _selectedValue,
                    enableSearch: enableSearch,
                    enableFilter: false,
                    requestFocusOnTap: enableSearch,
                    label:
                    widget.labelText != null ? Text(widget.labelText!) : null,
                    hintText: widget.hintText,
                    inputDecorationTheme: InputDecorationTheme(
                      labelStyle: const TextStyle(
                        color: Color(0xFF868B8F),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.67,
                        letterSpacing: 0.20,
                      ),
                      floatingLabelStyle: const TextStyle(
                        color: Color(0xFF868B8F),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.67,
                        letterSpacing: 0.20,
                      ),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(
                          width: 1,
                          color: Color(0xFFD8D9DD),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: field.hasError
                              ? Theme.of(context).colorScheme.error
                              : const Color(0xFF868B8F),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: field.hasError
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).primaryColor,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),

                    menuStyle: MenuStyle(
                      maximumSize: WidgetStateProperty.all(
                        Size.fromHeight(widget.menuHeight ?? 200),
                      ),
                      shape: .resolveWith((_) {
                        return RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(
                            color: field.hasError
                              ? Theme.of(context).colorScheme.error
                              : const Color(0xFF868B8F),
                          ),
                        );
                      }),
                    ),

                    onSelected: (String? value) {
                      // Prevent selecting placeholder entries
                      if (value == '__no_items__' || value == '__no_match__') {
                        FocusScope.of(context).unfocus();
                        return;
                      }

                      setState(() {
                        _selectedValue = value;
                      });

                      _controller.text = value ?? '';
                      field.didChange(value);
                      FocusScope.of(context).unfocus();
                      widget.onChanged?.call(value);
                    },

                    trailingIcon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                      child: _hasSelection
                          ? GestureDetector(
                        key: const ValueKey('clear_icon'),
                        onTap: () {
                          setState(() {
                            _selectedValue = null;
                            _controller.clear();
                          });
                          field.didChange(null);
                          FocusScope.of(context).unfocus();
                          widget.onChanged?.call(null);
                        },
                        child: const Icon(Icons.remove_circle),
                      )
                          : const Icon(
                        Icons.arrow_drop_down,
                        key: ValueKey('arrow_icon'),
                      ),
                    ),

                    dropdownMenuEntries: entries,
                  ),

                  if (field.errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        field.errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
