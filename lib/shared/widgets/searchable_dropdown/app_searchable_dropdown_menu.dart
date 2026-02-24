import 'package:flutter/material.dart';

class AppSearchableDropdown extends StatefulWidget {
  final List<String>? items;
  final String? labelText;
  final String? hintText;
  final double widthFactor;
  final String? initialValue;
  final ValueChanged<String?>? onChanged;
  final TextEditingController? controller;
  final bool? enableSearch;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode autoValidateMode;

  const AppSearchableDropdown({
    super.key,
    this.items,
    this.labelText,
    this.hintText,
    this.widthFactor = 0.8,
    this.initialValue,
    this.onChanged,
    this.controller,
    this.enableSearch = true,
    this.validator,
    this.autoValidateMode = AutovalidateMode.onUserInteraction,
  });

  @override
  State<AppSearchableDropdown> createState() => _AppSearchableDropdownState();
}

class _AppSearchableDropdownState extends State<AppSearchableDropdown> {
  late final TextEditingController _controller;
  String? _selectedValue;

  static const List<String> _defaultItems = [
    'Option 1',
    'Option 2',
    'Option 3',
    'Option 4',
    'Option 5',
  ];

  bool get _hasSelection =>
      _selectedValue != null && _selectedValue!.isNotEmpty;

  List<String> get _items =>
      (widget.items == null || widget.items!.isEmpty)
          ? _defaultItems
          : widget.items!;

  bool get enableSearch => widget.enableSearch ?? true;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();

    _selectedValue = widget.initialValue;
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
  }

  @override
  void didUpdateWidget(covariant AppSearchableDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuEntries = _items
        .map(
          (item) => DropdownMenuEntry<String>(
        value: item,
        label: item,
        labelWidget: Text(
          item,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.67,
            letterSpacing: 0.20,
          ),
        ),
      ),
    )
        .toList();

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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownMenu<String>(
                    width: maxWidth,
                    controller: _controller,
                    initialSelection: _selectedValue,
                    enableSearch: enableSearch,
                    enableFilter: enableSearch,
                    requestFocusOnTap: enableSearch,
                    label: widget.labelText != null
                        ? Text(widget.labelText!)
                        : null,
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
                      shape:
                      WidgetStateOutlinedBorder.resolveWith((_) {
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
                      transitionBuilder:
                          (child, animation) => ScaleTransition(
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
                    dropdownMenuEntries: menuEntries,
                  ),
                  if (field.errorText != null)
                    Padding(
                      padding: .only(top: 4, left: 4),
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

