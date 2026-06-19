import '../../domain/entities/product_entity.dart';
import '../../core/constants/api_constants.dart';

class ProductModel extends ProductEntity {
  const ProductModel({
    required super.uuid,
    required super.businessId,
    super.categoryId,
    required super.name,
    super.description,
    super.sku,
    required super.price,
    super.costPrice,
    required super.stockQuantity,
    super.unit,
    super.imageUrl,
    super.imageUrls,
    super.sizes,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      uuid: json['uuid'] as String,
      businessId: json['business_id'] as int,
      categoryId: json['category_id'] as int?,
      name: json['name'] as String,
      description: json['description'] as String?,
      sku: json['sku'] as String?,
      price: (json['price'] is String)
          ? double.parse(json['price'] as String)
          : (json['price'] as num).toDouble(),
      costPrice: json['cost_price'] != null
          ? (json['cost_price'] is String)
              ? double.parse(json['cost_price'] as String)
              : (json['cost_price'] as num).toDouble()
          : null,
      stockQuantity: json['stock_quantity'] as int,
      unit: json['unit'] as String?,
      imageUrl: json['image_url'] != null
          ? ApiConstants.fullUrl(json['image_url'] as String)
          : null,
      imageUrls: (json['image_urls'] as List<dynamic>?)
          ?.map((e) => ApiConstants.fullUrl(e as String))
          .toList(),
      sizes: (json['sizes'] as List<dynamic>?)?.map((e) => e as String).toList(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'business_id': businessId,
      if (categoryId != null) 'category_id': categoryId,
      'name': name,
      if (description != null) 'description': description,
      if (sku != null) 'sku': sku,
      'price': price,
      if (costPrice != null) 'cost_price': costPrice,
      'stock_quantity': stockQuantity,
      if (unit != null) 'unit': unit,
      if (imageUrl != null) 'image_url': imageUrl,
      if (imageUrls != null) 'image_urls': imageUrls,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ProductCreateRequest {
  final int? categoryId;
  final String name;
  final String? description;
  final String? sku;
  final double price;
  final double? costPrice;
  final int stockQuantity;
  final String? unit;
  final List<String>? imageUrls;
  final List<String>? sizes;
  final bool isActive;

  const ProductCreateRequest({
    this.categoryId,
    required this.name,
    this.description,
    this.sku,
    required this.price,
    this.costPrice,
    this.stockQuantity = 0,
    this.unit,
    this.imageUrls,
    this.sizes,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (categoryId != null) data['category_id'] = categoryId;
    data['name'] = name;
    if (description != null && description!.isNotEmpty) {
      data['description'] = description;
    }
    if (sku != null && sku!.isNotEmpty) data['sku'] = sku;
    data['price'] = price;
    if (costPrice != null) data['cost_price'] = costPrice;
    data['stock_quantity'] = stockQuantity;
    if (unit != null && unit!.isNotEmpty) data['unit'] = unit;
    if (imageUrls != null) data['image_urls'] = imageUrls;
    if (sizes != null) data['sizes'] = sizes;
    data['is_active'] = isActive;
    return data;
  }
}

class ProductUpdateRequest {
  final int? categoryId;
  final String? name;
  final String? description;
  final String? sku;
  final double? price;
  final double? costPrice;
  final int? stockQuantity;
  final String? unit;
  final List<String>? imageUrls;
  final List<String>? sizes;
  final bool? isActive;

  const ProductUpdateRequest({
    this.categoryId,
    this.name,
    this.description,
    this.sku,
    this.price,
    this.costPrice,
    this.stockQuantity,
    this.unit,
    this.imageUrls,
    this.sizes,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (categoryId != null) data['category_id'] = categoryId;
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (sku != null) data['sku'] = sku;
    if (price != null) data['price'] = price;
    if (costPrice != null) data['cost_price'] = costPrice;
    if (stockQuantity != null) data['stock_quantity'] = stockQuantity;
    if (unit != null) data['unit'] = unit;
    if (imageUrls != null) data['image_urls'] = imageUrls;
    if (sizes != null) data['sizes'] = sizes;
    if (isActive != null) data['is_active'] = isActive;
    return data;
  }
}
