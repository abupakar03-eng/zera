class SalesReportEntity {
  final String businessName;
  final String? fromDate;
  final String? toDate;
  final int totalOrders;
  final double totalRevenue;
  final double totalProfit;
  final double totalTax;
  final double totalDiscount;
  final List<SalesOrderItem> orders;

  const SalesReportEntity({
    required this.businessName,
    this.fromDate,
    this.toDate,
    required this.totalOrders,
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalTax,
    required this.totalDiscount,
    required this.orders,
  });
}

class SalesOrderItem {
  final String orderNumber;
  final String? customerName;
  final String orderDate;
  final String status;
  final String paymentStatus;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;

  const SalesOrderItem({
    required this.orderNumber,
    this.customerName,
    required this.orderDate,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
  });
}

class ProductReportEntity {
  final String businessName;
  final String? fromDate;
  final String? toDate;
  final int totalProductsSold;
  final double totalRevenue;
  final double totalProfit;
  final List<ProductReportItem> products;

  const ProductReportEntity({
    required this.businessName,
    this.fromDate,
    this.toDate,
    required this.totalProductsSold,
    required this.totalRevenue,
    required this.totalProfit,
    required this.products,
  });
}

class ProductReportItem {
  final String productName;
  final String? productSku;
  final String? categoryName;
  final int totalQuantitySold;
  final double totalRevenue;
  final double totalProfit;
  final int ordersCount;

  const ProductReportItem({
    required this.productName,
    this.productSku,
    this.categoryName,
    required this.totalQuantitySold,
    required this.totalRevenue,
    required this.totalProfit,
    required this.ordersCount,
  });
}

class CustomerReportEntity {
  final String businessName;
  final String? fromDate;
  final String? toDate;
  final int totalCustomers;
  final double totalRevenue;
  final double totalProfit;
  final List<CustomerReportItem> customers;

  const CustomerReportEntity({
    required this.businessName,
    this.fromDate,
    this.toDate,
    required this.totalCustomers,
    required this.totalRevenue,
    required this.totalProfit,
    required this.customers,
  });
}

class CustomerReportItem {
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final int totalOrders;
  final double totalSpent;
  final String? lastOrderDate;

  const CustomerReportItem({
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.totalOrders,
    required this.totalSpent,
    this.lastOrderDate,
  });
}
