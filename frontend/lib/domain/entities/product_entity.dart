class ProductEntity {
  final String uuid;
  final int businessId;
  final int? categoryId;
  final String name;
  final String? description;
  final String? sku;
  final double price;
  final double? costPrice;
  final int stockQuantity;
  final String? unit;
  final String? imageUrl;
  final List<String>? imageUrls;
  final List<String>? sizes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductEntity({
    required this.uuid,
    required this.businessId,
    this.categoryId,
    required this.name,
    this.description,
    this.sku,
    required this.price,
    this.costPrice,
    required this.stockQuantity,
    this.unit,
    this.imageUrl,
    this.imageUrls,
    this.sizes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  double? get profitMargin {
    if (costPrice == null || costPrice == 0) return null;
    return ((price - costPrice!) / costPrice!) * 100;
  }

  bool get isLowStock => stockQuantity <= 10;
  
  bool get isOutOfStock => stockQuantity <= 0;
}
