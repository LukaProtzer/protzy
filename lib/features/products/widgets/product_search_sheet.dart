import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';

class ProductSearchSheet extends StatefulWidget {
  const ProductSearchSheet({
    super.key,
    required this.onSelected,
  });

  final ValueChanged<Product> onSelected;

  @override
  State<ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<ProductSearchSheet> {
  final ProductService _service = ProductService();

  final TextEditingController _controller = TextEditingController();

  bool _loading = true;

  List<Product> _results = [];

  @override
  void initState() {
    super.initState();
    _initialize();
    _controller.addListener(_search);
  }

  Future<void> _initialize() async {
    await _service.initialize();

    if (!mounted) return;

    setState(() {
      _results = _service.getAllProducts();
      _loading = false;
    });
  }

  void _search() {
    setState(() {
      _results = _service.searchProducts(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'fleisch':
        return Icons.restaurant;

      case 'milchprodukte':
        return Icons.egg_alt;

      case 'obst':
        return Icons.apple;

      case 'gemüse':
        return Icons.eco;

      case 'getränke':
        return Icons.local_drink;

      default:
        return Icons.shopping_basket;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Produkt suchen...',
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(
                child: CircularProgressIndicator(),
              )
                  : ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final product = _results[index];

                  return ListTile(
                    leading: Icon(
                      _iconForCategory(product.category),
                    ),
                    title: Text(product.name),
                    subtitle: Text(product.category),
                    onTap: () {
                      widget.onSelected(product);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}