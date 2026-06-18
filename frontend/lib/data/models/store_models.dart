class StoreInfo {
  final String uuid;
  final String businessName;
  final String phone;
  final String? logoUrl;
  final List<String>? profileImageUrls;
  final String? bannerUrl;
  final String? upiId;
  final String? address;
  final String? city;
  final String? state;

  const StoreInfo({
    required this.uuid,
    required this.businessName,
    required this.phone,
    this.logoUrl,
    this.profileImageUrls,
    this.bannerUrl,
    this.upiId,
    this.address,
    this.city,
    this.state,
  });

  factory StoreInfo.fromJson(Map<String, dynamic> json) {
    return StoreInfo(
      uuid: json['uuid'] as String,
      businessName: json['business_name'] as String,
      phone: json['phone'] as String,
      logoUrl: json['logo_url'] as String?,
      profileImageUrls: json['profile_image_urls'] != null ? List<String>.from(json['profile_image_urls'] as List) : null,
      bannerUrl: json['banner_url'] as String?,
      upiId: json['upi_id'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
    );
  }

  String get displayLocation {
    final parts = [city, state].where((p) => p != null && p.isNotEmpty).toList();
    return parts.join(', ');
  }
}


class StoreCategory {
  final String uuid;
  final String name;

  const StoreCategory({required this.uuid, required this.name});

  factory StoreCategory.fromJson(Map<String, dynamic> json) {
    return StoreCategory(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
    );
  }
}


class StoreProduct {
  final String uuid;
  final String name;
  final String? description;
  final double price;
  final String? unit;
  final String? imageUrl;
  final List<String>? imageUrls;
  final List<String> sizes;
  final int stockQuantity;
  final String? categoryName;
  final bool isAvailable;

  const StoreProduct({
    required this.uuid,
    required this.name,
    this.description,
    required this.price,
    this.unit,
    this.imageUrl,
    this.imageUrls,
    this.sizes = const [],
    required this.stockQuantity,
    this.categoryName,
    required this.isAvailable,
  });

  factory StoreProduct.fromJson(Map<String, dynamic> json) {
    return StoreProduct(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      unit: json['unit'] as String?,
      imageUrl: json['image_url'] as String?,
      imageUrls: json['image_urls'] != null ? List<String>.from(json['image_urls'] as List) : null,
      sizes: json['sizes'] != null ? List<String>.from(json['sizes'] as List) : const [],
      stockQuantity: json['stock_quantity'] as int,
      categoryName: json['category_name'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }
}


class CartItem {
  final StoreProduct product;
  int quantity;
  final String? selectedSize;

  CartItem({required this.product, this.quantity = 1, this.selectedSize});

  double get total => product.price * quantity;
}


class StoreOrderItemResponse {
  final String productName;
  final String? productSku;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const StoreOrderItemResponse({
    required this.productName,
    this.productSku,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory StoreOrderItemResponse.fromJson(Map<String, dynamic> json) {
    return StoreOrderItemResponse(
      productName: json['product_name'] as String,
      productSku: json['product_sku'] as String?,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
    );
  }
}


class StoreOrderResult {
  final String orderNumber;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final double subtotal;
  final double totalAmount;
  final List<StoreOrderItemResponse> items;
  final DateTime createdAt;
  final String? notes;

  const StoreOrderResult({
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.subtotal,
    required this.totalAmount,
    required this.items,
    required this.createdAt,
    this.notes,
  });

  factory StoreOrderResult.fromJson(Map<String, dynamic> json) {
    return StoreOrderResult(
      orderNumber: json['order_number'] as String,
      status: json['status'] as String,
      paymentStatus: json['payment_status'] as String,
      paymentMethod: json['payment_method'] as String? ?? 'COD',
      subtotal: (json['subtotal'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      items: (json['items'] as List<dynamic>)
          .map((e) => StoreOrderItemResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      notes: json['notes'] as String?,
    );
  }
}
