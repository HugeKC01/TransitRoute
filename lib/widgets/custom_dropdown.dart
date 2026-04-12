import 'package:flutter/material.dart';

class CustomInlineDropdown<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final String Function(T?) itemLabel;
  final Widget? Function(T?)? itemLeading;
  final void Function(T?) onChanged;

  const CustomInlineDropdown({
    super.key,
    this.value,
    required this.items,
    required this.itemLabel,
    this.itemLeading,
    required this.onChanged,
  });

  @override
  State<CustomInlineDropdown<T>> createState() =>
      _CustomInlineDropdownState<T>();
}

class _CustomInlineDropdownState<T> extends State<CustomInlineDropdown<T>> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(
              children: [
                if (widget.itemLeading != null &&
                    widget.itemLeading!(widget.value) != null)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: widget.itemLeading!(widget.value)!,
                  ),
                Expanded(
                  child: Text(
                    widget.itemLabel(widget.value),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  title: Text(widget.itemLabel(null)),
                  onTap: () {
                    setState(() => _isExpanded = false);
                    widget.onChanged(null);
                  },
                ),
                ...widget.items.map((item) {
                  return ListTile(
                    leading: widget.itemLeading != null
                        ? widget.itemLeading!(item)
                        : null,
                    title: Text(widget.itemLabel(item)),
                    onTap: () {
                      setState(() => _isExpanded = false);
                      widget.onChanged(item);
                    },
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }
}
