import '../models/product.dart';
import '../repositories/product_repository.dart';

class ProductService {
  final ProductRepository _repository = ProductRepository();

  Future<void> initialize() async {
    await _repository.loadProducts();
  }

  List<Product> getAllProducts() {
    return _repository.getAllProducts();
  }

  List<Product> searchProducts(String query) {
    return _repository.search(query);
  }

  List<String> getCategories() {
    return _repository.getCategories();
  }

  bool productExists(String name) {
    return _repository
        .getAllProducts()
        .any((product) => product.name.toLowerCase() == name.toLowerCase());
  }
}