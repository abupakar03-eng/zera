import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/download_helper.dart' as helper;
import '../../providers/report_provider.dart';
import '../../providers/auth_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  int _previousTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCurrentReport();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index != _previousTabIndex) {
      _previousTabIndex = _tabController.index;
      _loadCurrentReport();
    }
  }

  void _loadCurrentReport() {
    final provider = Provider.of<ReportProvider>(context, listen: false);
    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

    switch (_tabController.index) {
      case 0:
        provider.loadSalesReport(startDate: startDateStr, endDate: endDateStr);
        break;
      case 1:
        provider.loadProductReport(startDate: startDateStr, endDate: endDateStr);
        break;
      case 2:
        provider.loadCustomerReport(startDate: startDateStr, endDate: endDateStr);
        break;
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadCurrentReport();
    }
  }

  Future<void> _exportReport(String format) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.business?.plan != 'PAID') {
      _showUpgradeDialog();
      return;
    }

    final reportType = ['sales', 'products', 'customers'][_tabController.index];
    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final provider = Provider.of<ReportProvider>(context, listen: false);
    final result = format == 'pdf'
        ? await provider.exportPDF(
            reportType: reportType,
            startDate: startDateStr,
            endDate: endDateStr,
          )
        : await provider.exportCSV(
            reportType: reportType,
            startDate: startDateStr,
            endDate: endDateStr,
          );

    if (mounted) Navigator.pop(context);

    if (result != null) {
      await helper.downloadBytes(result.bytes, result.filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report exported: ${result.filename}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${provider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PRO Feature'),
        content: const Text(
          'Export functionality is available with the PRO plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/upgrade');
            },
            child: const Text('Learn More'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Export'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sales'),
            Tab(text: 'Products'),
            Tab(text: 'Customers'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: _exportReport,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
              const PopupMenuItem(value: 'csv', child: Text('Export CSV')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.date_range, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('MMM dd, yyyy').format(_startDate)} – ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _selectDateRange,
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSalesReport(),
                _buildProductReport(),
                _buildCustomerReport(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadCurrentReport,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildPlanLockedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline, size: 56, color: Colors.amber.shade700),
            ),
            const SizedBox(height: 24),
            const Text(
              'Reports — PRO Feature',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Unlock detailed sales, product, and customer reports by upgrading to the PRO plan.',
              style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/upgrade'),
                icon: const Icon(Icons.rocket_launch),
                label: const Text('Explore PRO Features', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '₹699/month · Unlimited reports & exports',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error, ReportProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCurrentReport,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesReport() {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.isPlanError) return _buildPlanLockedView();
        if (provider.error != null) return _buildErrorView(provider.error!, provider);

        final report = provider.salesReport;
        if (report == null) {
          return const Center(child: Text('No sales data available'));
        }

        final avgOrder = report.totalOrders > 0
            ? report.totalRevenue / report.totalOrders
            : 0.0;

        return RefreshIndicator(
          onRefresh: () async => _loadCurrentReport(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Revenue',
                      '₹${report.totalRevenue.toStringAsFixed(2)}',
                      Icons.attach_money,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Profit',
                      '₹${report.totalProfit.toStringAsFixed(2)}',
                      Icons.trending_up,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Orders',
                      '${report.totalOrders}',
                      Icons.shopping_cart,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Total Tax',
                      '₹${report.totalTax.toStringAsFixed(2)}',
                      Icons.receipt,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (report.orders.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No orders in this date range'),
                ))
              else ...[
                const Text(
                  'Orders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...report.orders.map((item) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.paymentStatus == 'PAID'
                          ? Colors.green.shade100
                          : Colors.grey.shade100,
                      child: Icon(
                        item.paymentStatus == 'PAID'
                            ? Icons.check_circle
                            : Icons.pending,
                        color: item.paymentStatus == 'PAID'
                            ? Colors.green
                            : Colors.grey,
                        size: 20,
                      ),
                    ),
                    title: Text(item.orderNumber,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${item.customerName ?? 'Walk-in'} · ${item.orderDate.substring(0, 10)}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${item.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          item.status,
                          style: TextStyle(
                            fontSize: 11,
                            color: item.status == 'DELIVERED'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductReport() {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.isPlanError) return _buildPlanLockedView();
        if (provider.error != null) return _buildErrorView(provider.error!, provider);

        final report = provider.productReport;
        if (report == null) {
          return const Center(child: Text('No product data available'));
        }

        return RefreshIndicator(
          onRefresh: () async => _loadCurrentReport(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Products Sold',
                      '${report.totalProductsSold}',
                      Icons.inventory,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Total Revenue',
                      '₹${report.totalRevenue.toStringAsFixed(2)}',
                      Icons.account_balance_wallet,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'Profit',
                '₹${report.totalProfit.toStringAsFixed(2)}',
                Icons.trending_up,
                Colors.green,
              ),
              const SizedBox(height: 24),
              if (report.products.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No product sales in this date range'),
                ))
              else ...[
                const Text(
                  'Product Performance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...report.products.map((item) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.shopping_bag, size: 20),
                    ),
                    title: Text(item.productName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${item.categoryName ?? 'Uncategorized'} · ${item.totalQuantitySold} units · ${item.ordersCount} orders\nProfit: ₹${item.totalProfit.toStringAsFixed(2)}',
                    ),
                    trailing: Text(
                      '₹${item.totalRevenue.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                )),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomerReport() {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.isPlanError) return _buildPlanLockedView();
        if (provider.error != null) return _buildErrorView(provider.error!, provider);

        final report = provider.customerReport;
        if (report == null) {
          return const Center(child: Text('No customer data available'));
        }

        final avgOrders = report.totalCustomers > 0
            ? report.customers.fold<int>(0, (s, c) => s + c.totalOrders) /
                report.totalCustomers
            : 0.0;

        return RefreshIndicator(
          onRefresh: () async => _loadCurrentReport(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Customers',
                      '${report.totalCustomers}',
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Total Revenue',
                      '₹${report.totalRevenue.toStringAsFixed(2)}',
                      Icons.attach_money,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Profit',
                      '₹${report.totalProfit.toStringAsFixed(2)}',
                      Icons.trending_up,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Avg Orders / Customer',
                      avgOrders.toStringAsFixed(1),
                      Icons.trending_up,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (report.customers.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No customer data in this date range'),
                ))
              else ...[
                const Text(
                  'Top Customers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...report.customers.map((item) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(item.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${item.customerPhone}${item.customerEmail != null ? ' · ${item.customerEmail}' : ''}'
                      '\n${item.totalOrders} orders${item.lastOrderDate != null ? ' · Last: ${item.lastOrderDate!.substring(0, 10)}' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      '₹${item.totalSpent.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                )),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
