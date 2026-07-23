import 'package:flutter/material.dart';

import '../shopping_item.dart';

class ShoppingTile extends StatelessWidget {
  const ShoppingTile({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
    required this.onFavorite,
    required this.onTap,
  });

  final ShoppingItem item;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  String get _formattedQuantity {
    if (item.quantity == item.quantity.roundToDouble()) {
      return item.quantity.toInt().toString();
    }

    return item.quantity.toString().replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      decoration:
      item.done ? TextDecoration.lineThrough : TextDecoration.none,
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: IconButton(
          icon: Icon(
            item.favorite ? Icons.star : Icons.star_border,
            color: item.favorite ? Colors.amber : Colors.grey,
          ),
          tooltip: item.favorite ? 'Favorit entfernen' : 'Als Favorit markieren',
          onPressed: onFavorite,
        ),
        title: Text(
          item.name,
          style: textStyle.copyWith(
            fontWeight: item.favorite ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            item.note.trim().isEmpty
                ? '$_formattedQuantity ${item.unit}'
                : '$_formattedQuantity ${item.unit} • ${item.note}',
            style: textStyle,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: item.done,
              onChanged: onChanged,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Artikel löschen',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}