import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/product.dart';

class ProductRepository {
  static const _assetPath = 'assets/data/products.json';

  List<Product> _products = [];

  /// Lädt alle Produkte aus der JSON-Datei.
  Future<void> loadProducts() async {
    if (_products.isNotEmpty) return;

    final jsonString = await rootBundle.loadString(_assetPath);
    final List<dynamic> jsonList = json.decode(jsonString);

    _products = jsonList
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();

    _products.sort(
          (a, b) => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
    );
  }

  /// Alle Produkte
  List<Product> getAllProducts() {
    return List.unmodifiable(_products);
  }

  /// Suche nach Name oder Keywords
  List<Product> search(String query) {
    final text = query.trim();

    if (text.isEmpty) {
      return getAllProducts();
    }

    return _products.where((product) {
      return product.matches(text);
    }).toList();
  }

  /// Kategorien
  List<String> getCategories() {
    final categories = _products
        .map((e) => e.category)
        .toSet()
        .toList();

    categories.sort();

    return categories;
  }
}