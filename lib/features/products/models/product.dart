class Product {
  final String id;
  final String name;
  final String category;
  final List<String> keywords;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.keywords,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      keywords: List<String>.from(json['keywords'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "category": category,
      "keywords": keywords,
    };
  }

  bool matches(String query) {
    final search = query.trim().toLowerCase();

    if (name.toLowerCase().contains(search)) {
      return true;
    }

    for (final keyword in keywords) {
      if (keyword.toLowerCase().contains(search)) {
        return true;
      }
    }

    return false;
  }
}