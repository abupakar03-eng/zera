import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/biometric_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';

// ── Premium monochrome tokens ─────────────────────────────────────────────────
const _black   = Color(0xFF1A1A1A);
const _charcoal= Color(0xFF2D2D2D);
const _mid     = Color(0xFF6B6B6B);
const _silk    = Color(0xFFF5F4F2);   // warm near-white
const _divLine = Color(0xFFE8E6E2);
const _marble  = Color(0xFFF0EDE8);   // card bg
const _accent  = Color(0xFF9E8F82);   // warm taupe accent

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).loadDashboardStats();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      Provider.of<DashboardProvider>(context, listen: false).loadDashboardStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth      = Provider.of<AuthProvider>(context);
    final dashboard = Provider.of<DashboardProvider>(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _silk,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: _navIndex == 0
                ? _DashboardBody(auth: auth, dashboard: dashboard)
                : const Center(child: CircularProgressIndicator()),
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
        drawer: _buildDrawer(auth),
      ),
    );
  }

  Widget _buildBottomNav() {
    const items = [
      BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded),   label: 'Dashboard'),
      BottomNavigationBarItem(icon: Icon(Icons.warehouse_rounded),    label: 'Inventory'),
      BottomNavigationBarItem(icon: Icon(Icons.category_rounded),     label: 'Categories'),
      BottomNavigationBarItem(icon: Icon(Icons.store_rounded),        label: 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _divLine)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16, offset: const Offset(0, -2)),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) async {
          if (i == 1) {
            await context.push('/inventory');
          } else if (i == 2) {
            await context.push('/categories');
          } else if (i == 3) {
            await context.push('/business-profile');
          } else {
            setState(() => _navIndex = i);
          }
          if (mounted) {
            Provider.of<DashboardProvider>(context, listen: false).loadDashboardStats();
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: _black,
        unselectedItemColor: _mid,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.2),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        elevation: 0,
        items: items,
      ),
    );
  }

  Widget _buildDrawer(AuthProvider auth) {
    final user     = auth.user;
    final business = auth.business;
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 20, right: 20, bottom: 28,
            ),
            color: _black,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  backgroundImage: (business?.logoUrl != null && business!.logoUrl!.isNotEmpty)
                      ? NetworkImage(business.logoUrl!) : null,
                  child: (business?.logoUrl == null || business!.logoUrl!.isEmpty)
                      ? Text(
                          (business?.businessName ?? user?.fullName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                Text(business?.businessName ?? 'ZERA',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(user?.phone ?? '',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    business?.plan.toUpperCase() ?? 'FREE',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerItem(Icons.dashboard_rounded, 'Dashboard', () => Navigator.pop(context)),
                _drawerItem(Icons.inventory_2_rounded, 'Products', () { Navigator.pop(context); context.push('/products'); }),
                _drawerItem(Icons.warehouse_rounded, 'Inventory', () { Navigator.pop(context); context.push('/inventory'); }),
                _drawerItem(Icons.category_rounded, 'Categories', () { Navigator.pop(context); context.push('/categories'); }),
                _drawerItem(Icons.people_rounded, 'Customers', () { Navigator.pop(context); context.push('/customers'); }),
                _drawerItem(Icons.receipt_long_rounded, 'Orders', () { Navigator.pop(context); context.push('/orders'); }),
                _drawerItem(Icons.store_rounded, 'Business Profile', () { Navigator.pop(context); context.push('/business-profile'); }),
                _drawerItem(Icons.bar_chart_rounded, 'Reports', () { Navigator.pop(context); context.push('/reports'); }),
                _drawerItem(Icons.workspace_premium_rounded, 'Upgrade to PRO', () { Navigator.pop(context); context.push('/upgrade'); }, color: _black),
                if (auth.user?.role == 'SUPER_ADMIN') ...[
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider()),
                  _drawerItem(Icons.admin_panel_settings_rounded, 'Admin Portal', () { Navigator.pop(context); context.push('/admin'); }, color: Colors.red.shade700),
                ],
                _drawerItem(Icons.fingerprint_rounded, 'Security', () { Navigator.pop(context); _showBiometricSettings(context); }),
                _drawerItem(Icons.headset_mic_rounded, 'Help & Support', () { Navigator.pop(context); context.push('/help-support'); }),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider()),
                _drawerItem(Icons.logout_rounded, 'Logout', () async {
                  Navigator.pop(context);
                  await auth.logout();
                  if (mounted) context.go('/login');
                }, color: Colors.red.shade600),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final c = color ?? _black;
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: c),
      ),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
    );
  }

  Future<void> _showBiometricSettings(BuildContext context) async {
    final bio = BiometricService();
    final available = await bio.isAvailable();
    if (!context.mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric not available on this device')));
      return;
    }
    final enabled = await bio.isEnabled();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Security'),
          content: SwitchListTile(
            title: const Text('Fingerprint / Face unlock'),
            subtitle: const Text('Use biometrics to unlock the app'),
            value: enabled,
            onChanged: (val) async {
              if (val) { final ok = await bio.authenticate(); if (!ok) return; }
              await bio.setEnabled(val);
              setS(() {});
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      ),
    );
  }
}

// ── Dashboard Body ────────────────────────────────────────────────────────────
class _DashboardBody extends StatelessWidget {
  final AuthProvider auth;
  final DashboardProvider dashboard;
  const _DashboardBody({required this.auth, required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final business = auth.business;
    final stats    = dashboard.stats;
    final hour     = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';

    return RefreshIndicator(
      onRefresh: () => dashboard.refreshStats(),
      color: _black,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: _black,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(greeting,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13, letterSpacing: 0.3)),
                            const SizedBox(height: 4),
                            Text(
                              business?.businessName ?? 'Store',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 6),
                            Row(children: [
                              Container(
                                width: 6, height: 6,
                                decoration: const BoxDecoration(
                                    color: Color(0xFF7CFC00), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('EEEE, d MMM').format(DateTime.now()),
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 12),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Builder(builder: (ctx) => GestureDetector(
                            onTap: () => Scaffold.of(ctx).openDrawer(),
                            child: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                              ),
                              child: ClipOval(
                                child: (business?.logoUrl != null && business!.logoUrl!.isNotEmpty)
                                    ? Image.network(business.logoUrl!, fit: BoxFit.cover)
                                    : Center(
                                        child: Text(
                                          (business?.businessName ?? 'U')[0].toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18),
                                        ),
                                      ),
                              ),
                            ),
                          )),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => dashboard.refreshStats(),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.refresh_rounded,
                                  color: Colors.white.withValues(alpha: 0.6), size: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (dashboard.status == DashboardStatus.loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _black, strokeWidth: 2)),
            )
          else if (dashboard.status == DashboardStatus.error)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 48, color: _mid),
                    const SizedBox(height: 16),
                    Text(dashboard.error ?? 'Something went wrong',
                        style: const TextStyle(color: _mid, fontSize: 14)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => dashboard.refreshStats(),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _black, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  ],
                ),
              ),
            )
          else if (stats != null) ...[

            // ── Stat cards ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    _StatCard(
                      label: 'Products',
                      value: stats.products.total.toString(),
                      sub: '${stats.products.active} active',
                      icon: Icons.inventory_2_rounded,
                      accentColor: const Color(0xFF4A4A8A),
                      route: '/products',
                    ),
                    _StatCard(
                      label: 'Orders',
                      value: stats.orders.total.toString(),
                      sub: '${stats.orders.completed} done',
                      icon: Icons.receipt_long_rounded,
                      accentColor: const Color(0xFF2D7A4F),
                      route: '/orders',
                    ),
                    _StatCard(
                      label: 'Customers',
                      value: stats.customers.total.toString(),
                      sub: '${stats.customers.active} active',
                      icon: Icons.people_rounded,
                      accentColor: const Color(0xFF8A5A2A),
                      route: '/customers',
                    ),
                    _StatCard(
                      label: 'Revenue',
                      value: '₹${_compact(stats.revenue.total)}',
                      sub: 'Total earned',
                      icon: Icons.currency_rupee_rounded,
                      accentColor: const Color(0xFF7A2D2D),
                      route: '/reports',
                    ),
                  ],
                ),
              ),
            ),

            // ── Subscription ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _SubscriptionCard(business: business),
              ),
            ),

            // ── Store share ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _StoreShareCard(business: business),
              ),
            ),

            // ── Low stock warning ────────────────────────────────────────────
            if (stats.products.lowStock > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: GestureDetector(
                    onTap: () => context.push('/inventory'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF5E4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE8CC88)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFB8860B), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${stats.products.lowStock} products running low on stock',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: Color(0xFF7A5300)),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFFB8860B), size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Section label ────────────────────────────────────────────────
            if (stats.dailySales != null && stats.dailySales!.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: _SectionLabel(title: 'Sales', sub: 'Last 30 days'),
                ),
              ),

            if (stats.dailySales != null && stats.dailySales!.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _RevenueChart(dailySales: stats.dailySales!),
                ),
              ),

            // ── Top Products ─────────────────────────────────────────────────
            if (stats.topProducts != null && stats.topProducts!.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: _SectionLabel(
                      title: 'Top Products',
                      action: 'See all',
                      onAction: () => context.push('/products')),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final p = stats.topProducts![i];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _TopProductTile(rank: i + 1, name: p.productName,
                          sold: p.quantitySold, revenue: p.revenue),
                    );
                  },
                  childCount: stats.topProducts!.length.clamp(0, 5),
                ),
              ),
            ],

            // ── Recent Orders ────────────────────────────────────────────────
            if (stats.recentOrders != null && stats.recentOrders!.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: _SectionLabel(
                      title: 'Recent Orders',
                      action: 'See all',
                      onAction: () => context.push('/orders')),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final o = stats.recentOrders![i];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _RecentOrderTile(
                          number: o.orderNumber, status: o.status, amount: o.totalAmount),
                    );
                  },
                  childCount: stats.recentOrders!.length.clamp(0, 5),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ],
      ),
    );
  }

  String _compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String title;
  final String? sub;
  final String? action;
  final VoidCallback? onAction;
  const _SectionLabel({required this.title, this.sub, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: _black, letterSpacing: -0.3)),
        if (sub != null) ...[
          const SizedBox(width: 8),
          Text(sub!,
              style: const TextStyle(fontSize: 12, color: _mid)),
        ],
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: const TextStyle(
                    fontSize: 13, color: _mid,
                    fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color accentColor;
  final String? route;
  const _StatCard({required this.label, required this.value, required this.sub,
      required this.icon, required this.accentColor, this.route});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: route != null ? () => context.push(route!) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 17, color: accentColor),
                ),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 10, color: _mid, fontWeight: FontWeight.w500)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900, color: _black, letterSpacing: -0.5)),
                const SizedBox(height: 1),
                Text(label,
                    style: const TextStyle(fontSize: 12, color: _mid, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subscription Card ─────────────────────────────────────────────────────────
class _SubscriptionCard extends StatelessWidget {
  final dynamic business;
  const _SubscriptionCard({required this.business});

  @override
  Widget build(BuildContext context) {
    final isPaid       = (business?.plan as String?)?.toUpperCase() == 'PAID';
    final expiryDate   = business?.planExpiryDate as DateTime?;
    final subType      = business?.subscriptionType as String?;
    int? daysRemaining;
    if (expiryDate != null) {
      daysRemaining = expiryDate.difference(DateTime.now()).inDays.clamp(0, 99999);
    }

    if (isPaid && daysRemaining != null && daysRemaining > 0) {
      final maxDays = subType == 'monthly' ? 30 : 365;
      final progress = (daysRemaining / maxDays).clamp(0.0, 1.0);
      final planLabel = subType == 'monthly' ? 'PRO Monthly' : 'PRO Yearly';

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(planLabel,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7CFC00).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('ACTIVE',
                          style: TextStyle(color: Color(0xFF7CFC00),
                              fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('$daysRemaining days remaining',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      color: const Color(0xFF7CFC00),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // FREE plan nudge
    return GestureDetector(
      onTap: () => context.push('/upgrade'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _divLine),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.rocket_launch_rounded, color: _black, size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upgrade to PRO',
                      style: TextStyle(
                          color: _black, fontSize: 14, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Unlimited products & analytics from ₹699/mo',
                      style: TextStyle(color: _mid, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Upgrade',
                  style: TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Store Share Card ──────────────────────────────────────────────────────────
class _StoreShareCard extends StatelessWidget {
  final dynamic business;
  const _StoreShareCard({required this.business});

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _share(String url, String name) async {
    final text = Uri.encodeComponent('Shop at $name!\n$url');
    final wa = Uri.parse('whatsapp://send?text=$text');
    if (await canLaunchUrl(wa)) {
      await launchUrl(wa);
    } else {
      await Share.share('Shop at $name!\n$url');
    }
  }

  void _showQr(String url, String name, BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: _divLine, borderRadius: BorderRadius.circular(2))),
            const Text('Store QR Code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _black)),
            const SizedBox(height: 4),
            const Text('Customers can scan to open your store',
                style: TextStyle(color: _mid, fontSize: 12)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _silk,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _divLine),
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 200,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _black),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square, color: _black),
              ),
            ),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(color: _black, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(url, style: const TextStyle(color: _mid, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(context); Share.share('Shop at $name!\n$url'); },
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share QR', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _black, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uuid = business?.uuid as String?;
    if (uuid == null || uuid.isEmpty) return const SizedBox.shrink();
    final url  = ApiConstants.storeUrl(uuid, storeSlug: business?.storeSlug);
    final name = business?.businessName as String? ?? 'our store';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divLine),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded, color: _black, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Customer Store',
                        style: TextStyle(color: _black, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('Share this link with your customers',
                        style: TextStyle(color: _mid, fontSize: 11)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _open(url),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _silk,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _divLine),
                  ),
                  child: const Icon(Icons.open_in_new_rounded, color: _mid, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _open(url),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _silk,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _divLine),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, color: _mid, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(url,
                        style: const TextStyle(color: _charcoal, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const Icon(Icons.arrow_outward_rounded, color: _mid, size: 13),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StoreBtn(icon: Icons.visibility_rounded, label: 'Preview',
                  onTap: () => _open(url)),
              const SizedBox(width: 8),
              _StoreBtn(icon: Icons.copy_rounded, label: 'Copy', onTap: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Store link copied!'),
                        duration: Duration(seconds: 2)));
              }),
              const SizedBox(width: 8),
              _StoreBtn(icon: Icons.share_rounded, label: 'Share',
                  onTap: () => _share(url, name)),
              const SizedBox(width: 8),
              _StoreBtn(icon: Icons.qr_code_rounded, label: 'QR',
                  onTap: () => _showQr(url, name, context), filled: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoreBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  const _StoreBtn({required this.icon, required this.label, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: filled ? _black : _silk,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: filled ? _black : _divLine),
          ),
          child: Column(
            children: [
              Icon(icon, size: 15, color: filled ? Colors.white : _charcoal),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: filled ? Colors.white : _charcoal)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Revenue Chart ─────────────────────────────────────────────────────────────
class _RevenueChart extends StatelessWidget {
  final List<dynamic> dailySales;
  const _RevenueChart({required this.dailySales});

  @override
  Widget build(BuildContext context) {
    final max = dailySales.map((e) => e.revenue as double).reduce((a, b) => a > b ? a : b) * 1.25;

    return Container(
      height: 190,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divLine),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: max,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: _black,
              getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                '₹${rod.toY.toStringAsFixed(0)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (val, meta) {
                  final i = val.toInt();
                  if (i % 7 != 0 || i >= dailySales.length) return const SizedBox();
                  final d = DateTime.parse(dailySales[i].date as String);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(DateFormat('dd/MM').format(d),
                        style: const TextStyle(fontSize: 9, color: _mid)),
                  );
                },
              ),
            ),
            leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: _divLine, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: dailySales.asMap().entries.map((e) => BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.revenue as double,
                width: 5,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                color: _charcoal,
              ),
            ],
          )).toList(),
        ),
      ),
    );
  }
}

// ── Top Product Tile ──────────────────────────────────────────────────────────
class _TopProductTile extends StatelessWidget {
  final int rank;
  final String name;
  final int sold;
  final double revenue;
  const _TopProductTile({required this.rank, required this.name, required this.sold, required this.revenue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _divLine),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Text('#$rank',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w900,
                  color: rank == 1 ? const Color(0xFFB8860B) : _mid)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _black)),
                Text('$sold sold', style: const TextStyle(fontSize: 11, color: _mid)),
              ],
            ),
          ),
          Text('₹${revenue.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _black)),
        ],
      ),
    );
  }
}

// ── Recent Order Tile ─────────────────────────────────────────────────────────
class _RecentOrderTile extends StatelessWidget {
  final String number, status;
  final double amount;
  const _RecentOrderTile({required this.number, required this.status, required this.amount});

  @override
  Widget build(BuildContext context) {
    final info = _statusInfo(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _divLine),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: info.$2.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long_rounded, size: 16, color: info.$2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(number,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _black)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: info.$2.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(info.$1,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: info.$2)),
                ),
              ],
            ),
          ),
          Text('₹${amount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _black)),
        ],
      ),
    );
  }

  (String, Color) _statusInfo(String s) {
    switch (s.toUpperCase()) {
      case 'DELIVERED':  return ('Delivered',  Color(0xFF2D7A4F));
      case 'CANCELLED':  return ('Cancelled',  Color(0xFF9B3030));
      case 'PROCESSING': return ('Processing', Color(0xFF3A5A9B));
      case 'SHIPPED':    return ('Shipped',    Color(0xFF6B4A9B));
      default:           return ('Pending',    Color(0xFF8A6A2A));
    }
  }
}
