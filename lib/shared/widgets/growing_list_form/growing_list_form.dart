import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../helpers/enums/form_field_type.dart';
import '../../helpers/form_field_validators.dart';
import '../text_form_field/app_text_form_field.dart';

class GrowingListForm extends StatefulWidget {
  final String? title;
  final String? itemLabel;
  final String? valueLabel;
  final bool? isRequired;
  final int itemFlex;
  final int valueFlex;
  final ValueChanged<double>? onTotalChanged;
  final ValueChanged<List<Map<String, dynamic>>>? onItemsChanged;

  const GrowingListForm({
    super.key,
    this.title,
    this.itemLabel,
    this.valueLabel,
    this.isRequired,
    this.itemFlex = 7,
    this.valueFlex = 5,
    this.onTotalChanged,
    this.onItemsChanged,
  });

  @override
  State<GrowingListForm> createState() => _GrowingListFormState();
}

class _GrowingListFormState extends State<GrowingListForm> {
  final List<TextEditingController> _itemControllers = [];
  final List<TextEditingController> _valueControllers = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _addField();
    });
  }

  void _notifyChanges() {
    double total = 0.0;
    final List<Map<String, dynamic>> items = [];

    for (int i = 0; i < _itemControllers.length; i++) {
      final name = _itemControllers[i].text.trim();
      final rawCost = _valueControllers[i].text.trim().replaceAll(',', '');

      final cost = double.tryParse(rawCost) ?? 0.0;

      // If cost is given, include item (even if name is empty -> validation will catch)
      if (cost > 0 || name.isNotEmpty) {
        items.add({'name': name, 'cost': cost});
      }

      total += cost;
    }

    widget.onItemsChanged?.call(items);
    widget.onTotalChanged?.call(total);
  }

  void _addField() {
    setState(() {
      final itemCtrl = TextEditingController();
      final valueCtrl = TextEditingController();

      itemCtrl.addListener(_notifyChanges);
      valueCtrl.addListener(_notifyChanges);

      _itemControllers.add(itemCtrl);
      _valueControllers.add(valueCtrl);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifyChanges();
    });
  }

  void _removeField(int index) {
    setState(() {
      _itemControllers[index].removeListener(_notifyChanges);
      _valueControllers[index].removeListener(_notifyChanges);

      _itemControllers[index].dispose();
      _valueControllers[index].dispose();

      _itemControllers.removeAt(index);
      _valueControllers.removeAt(index);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifyChanges();
    });
  }

  @override
  void dispose() {
    for (final c in _itemControllers) {
      c.removeListener(_notifyChanges);
      c.dispose();
    }
    for (final c in _valueControllers) {
      c.removeListener(_notifyChanges);
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemLabel = widget.itemLabel ?? 'Item';
    final valueLabel = widget.valueLabel ?? 'Val';
    final itemFlex = widget.itemFlex <= 0 ? 1 : widget.itemFlex;
    final valueFlex = widget.valueFlex <= 0 ? 1 : widget.valueFlex;

    return Column(
      children: [
        ListTile(
          contentPadding: .zero,
          title: Text(
            widget.title ?? 'Add growing list',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle),
            onPressed: _addField,
          ),
        ),

        ListView.separated(
          shrinkWrap: true,
          padding: .zero,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, _) => const Divider(height: 10),
          itemCount: _itemControllers.length,
          itemBuilder: (context, index) {
            final isFirstAndOnly = _itemControllers.length == 1 && index == 0;

            return Row(
              children: [
                Expanded(
                  flex: itemFlex,
                  child: AppTextFormField(
                    controller: _itemControllers[index],
                    label: '$itemLabel ${index + 1}',

                    // Requirement: if value is given then item is required
                    validator: (value) {
                      final rawCost = _valueControllers[index].text
                          .trim()
                          .replaceAll(',', '');
                      final cost = double.tryParse(rawCost) ?? 0.0;

                      if (cost > 0 && (value == null || value.trim().isEmpty)) {
                        return 'Item name is required';
                      }

                      if (widget.isRequired == true) {
                        return validateField(value, FormFieldType.general);
                      }

                      return null;
                    },
                  ),
                ),

                const SizedBox(width: 4),

                Expanded(
                  flex: valueFlex,
                  child: AppTextFormField(
                    type: .amount,
                    controller: _valueControllers[index],
                    label: '$valueLabel ${index + 1}',
                    validator: widget.isRequired == true
                        ? (value) => validateField(value, FormFieldType.amount)
                        : (_) => null,
                  ),
                ),

                IconButton(
                  icon: Icon(
                    Icons.remove_circle,
                    color: isFirstAndOnly ? Colors.grey.shade400 : Colors.red,
                  ),
                  onPressed: isFirstAndOnly ? null : () => _removeField(index),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}