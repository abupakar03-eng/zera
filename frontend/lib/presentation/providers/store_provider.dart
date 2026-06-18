import 'package:flutter/foundation.dart';
import '../../data/datasources/store_api_datasource.dart';
import '../../data/models/store_models.dart';

class StoreProvider extends ChangeNotifier {
  final StoreApiDatasource _datasource = StoreApiDatasource();

  StoreInfo? _storeInfo;
  List<StoreProduct> _products = [];
  List<StoreCategory> _categories = [];
  final List<CartItem> _cart = [];
  StoreOrderResult? _lastOrder;

  bool _isLoading = false;
  String? _error;
  String? _selectedCategoryUuid;
  String _searchQuery = '';

  StoreInfo? get storeInfo => _storeInfo;
  List<StoreProduct> get products => _products;
  List<StoreCategory> get categories => _categories;
  List<CartItem> get cart => List.unmodifiable(_cart);
  StoreOrderResult? get lastOrder => _lastOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCategoryUuid => _selectedCategoryUuid;

  int get cartItemCount => _cart.fold(0, (sum, i) => sum + i.quantity);
  double get cartTotal => _cart.fold(0.0, (sum, i) => sum + i.total);

  Future<void> loadStore(String businessUuid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _datasource.getStoreInfo(businessUuid),
        _datasource.getCategories(businessUuid),
        _datasource.getProducts(businessUuid),
      ]);

      _storeInfo = results[0] as StoreInfo;
      _categories = results[1] as List<StoreCategory>;
      _products = results[2] as List<StoreProduct>;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> filterByCategory(String businessUuid, String? categoryUuid) async {
    _selectedCategoryUuid = categoryUuid;
    _isLoading = true;
    notifyListeners();

    try {
      _products = await _datasource.getProducts(
        businessUuid,
        categoryUuid: categoryUuid,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchProducts(String businessUuid, String query) async {
    _searchQuery = query;
    try {
      _products = await _datasource.getProducts(
        businessUuid,
        search: query.isEmpty ? null : query,
        categoryUuid: _selectedCategoryUuid,
      );
    } catch (_) {}
    notifyListeners();
  }

  // ── Cart operations ────────────────────────────────────────────────────────

  void addToCart(StoreProduct product, {String? selectedSize}) {
    final index = _cart.indexWhere(
      (i) => i.product.uuid == product.uuid && i.selectedSize == selectedSize,
    );
    if (index >= 0) {
      if (_cart[index].quantity < product.stockQuantity) {
        _cart[index].quantity++;
      }
    } else {
      _cart.add(CartItem(product: product, quantity: 1, selectedSize: selectedSize));
    }
    notifyListeners();
  }

  void removeFromCart(String productUuid, {String? selectedSize}) {
    _cart.removeWhere(
      (i) => i.product.uuid == productUuid && i.selectedSize == selectedSize,
    );
    notifyListeners();
  }

  int cartQuantityForSize(String productUuid, String? selectedSize) {
    final index = _cart.indexWhere(
      (i) => i.product.uuid == productUuid && i.selectedSize == selectedSize,
    );
    return index >= 0 ? _cart[index].quantity : 0;
  }

  void updateQuantity(String productUuid, int quantity) {
    final index = _cart.indexWhere((i) => i.product.uuid == productUuid);
    if (index >= 0) {
      if (quantity <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  int cartQuantityFor(String productUuid) {
    final index = _cart.indexWhere((i) => i.product.uuid == productUuid);
    return index >= 0 ? _cart[index].quantity : 0;
  }

  // ── Place order ────────────────────────────────────────────────────────────

  Future<StoreOrderResult?> placeOrder({
    required String businessUuid,
    required String customerName,
    required String customerPhone,
    required String paymentMethod,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final items = _cart.map((i) {
        final m = <String, dynamic>{
          'product_uuid': i.product.uuid,
          'quantity': i.quantity,
        };
        if (i.selectedSize != null && i.selectedSize!.isNotEmpty) {
          m['selected_size'] = i.selectedSize;
        }
        return m;
      }).toList();

      final result = await _datasource.placeOrder(
        businessUuid,
        customerName: customerName,
        customerPhone: customerPhone,
        items: items,
        paymentMethod: paymentMethod,
        notes: notes,
      );

      _lastOrder = result;
      clearCart();
      return result;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<StoreOrderResult?> fetchOrderStatus(
    String businessUuid,
    String orderNumber,
  ) async {
    try {
      return await _datasource.getOrderStatus(businessUuid, orderNumber);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return null;
    }
  }

  void resetStore() {
    _storeInfo = null;
    _products = [];
    _categories = [];
    _cart.clear();
    _lastOrder = null;
    _selectedCategoryUuid = null;
    _searchQuery = '';
    _error = null;
    notifyListeners();
  }
}
