import '../../domain/entities/report_entity.dart';

class SalesReportModel extends SalesReportEntity {
  const SalesReportModel({
    required super.businessName,
    super.fromDate,
    super.toDate,
    required super.totalOrders,
    required super.totalRevenue,
    required super.totalProfit,
    required super.totalTax,
    required super.totalDiscount,
    required super.orders,
  });

  factory SalesReportModel.fromJson(Map<String, dynamic> json) {
    return SalesReportModel(
      businessName: json['business_name'] as String? ?? '',
      fromDate: json['from_date'] as String?,
      toDate: json['to_date'] as String?,
      totalOrders: json['total_orders'] as int? ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (json['total_profit'] as num?)?.toDouble() ?? 0.0,
      totalTax: (json['total_tax'] as num?)?.toDouble() ?? 0.0,
      totalDiscount: (json['total_discount'] as num?)?.toDouble() ?? 0.0,
      orders: ((json['orders'] as List?) ?? [])
          .map((item) => SalesOrderItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SalesOrderItemModel extends SalesOrderItem {
  const SalesOrderItemModel({
    required super.orderNumber,
    super.customerName,
    required super.orderDate,
    required super.status,
    required super.paymentStatus,
    required super.subtotal,
    required super.taxAmount,
    required super.discountAmount,
    required super.totalAmount,
  });

  factory SalesOrderItemModel.fromJson(Map<String, dynamic> json) {
    return SalesOrderItemModel(
      orderNumber: json['order_number'] as String? ?? '',
      customerName: json['customer_name'] as String?,
      orderDate: json['order_date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      paymentStatus: json['payment_status'] as String? ?? '',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ProductReportModel extends ProductReportEntity {
  const ProductReportModel({
    required super.businessName,
    super.fromDate,
    super.toDate,
    required super.totalProductsSold,
    required super.totalRevenue,
    required super.totalProfit,
    required super.products,
  });

  factory ProductReportModel.fromJson(Map<String, dynamic> json) {
    return ProductReportModel(
      businessName: json['business_name'] as String? ?? '',
      fromDate: json['from_date'] as String?,
      toDate: json['to_date'] as String?,
      totalProductsSold: json['total_products_sold'] as int? ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (json['total_profit'] as num?)?.toDouble() ?? 0.0,
      products: ((json['products'] as List?) ?? [])
          .map((item) => ProductReportItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProductReportItemModel extends ProductReportItem {
  const ProductReportItemModel({
    required super.productName,
    super.productSku,
    super.categoryName,
    required super.totalQuantitySold,
    required super.totalRevenue,
    required super.totalProfit,
    required super.ordersCount,
  });

  factory ProductReportItemModel.fromJson(Map<String, dynamic> json) {
    return ProductReportItemModel(
      productName: json['product_name'] as String? ?? '',
      productSku: json['product_sku'] as String?,
      categoryName: json['category_name'] as String?,
      totalQuantitySold: json['total_quantity_sold'] as int? ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (json['total_profit'] as num?)?.toDouble() ?? 0.0,
      ordersCount: json['orders_count'] as int? ?? 0,
    );
  }
}

class CustomerReportModel extends CustomerReportEntity {
  const CustomerReportModel({
    required super.businessName,
    super.fromDate,
    super.toDate,
    required super.totalCustomers,
    required super.totalRevenue,
    required super.totalProfit,
    required super.customers,
  });

  factory CustomerReportModel.fromJson(Map<String, dynamic> json) {
    return CustomerReportModel(
      businessName: json['business_name'] as String? ?? '',
      fromDate: json['from_date'] as String?,
      toDate: json['to_date'] as String?,
      totalCustomers: json['total_customers'] as int? ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (json['total_profit'] as num?)?.toDouble() ?? 0.0,
      customers: ((json['customers'] as List?) ?? [])
          .map((item) => CustomerReportItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CustomerReportItemModel extends CustomerReportItem {
  const CustomerReportItemModel({
    required super.customerName,
    required super.customerPhone,
    super.customerEmail,
    required super.totalOrders,
    required super.totalSpent,
    super.lastOrderDate,
  });

  factory CustomerReportItemModel.fromJson(Map<String, dynamic> json) {
    return CustomerReportItemModel(
      customerName: json['customer_name'] as String? ?? '',
      customerPhone: json['customer_phone'] as String? ?? '',
      customerEmail: json['customer_email'] as String?,
      totalOrders: json['total_orders'] as int? ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0.0,
      lastOrderDate: json['last_order_date'] as String?,
    );
  }
}
