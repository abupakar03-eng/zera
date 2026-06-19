import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/shimmer_loading.dart';
import 'product_form_screen.dart';
import 'product_detail_screen.dart';

// ── Premium monochrome tokens ─────────────────────────────────────────────────
const _black    = Color(0xFF1A1A1A);
const _charcoal = Color(0xFF2D2D2D);
const _mid      = Color(0xFF6B6B6B);
const _silk     = Color(0xFFF5F4F2);
const _divLine  = Color(0xFFE8E6E2);

class ProductsListScreen extends StatefulWidget {
  const ProductsListScreen({super.key});
  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  final _scrollController  = ScrollController();
  final _searchController  = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).loadProducts(refresh: true);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      final p = Provider.of<ProductProvider>(context, listen: false);
      if (!p.isLoading && p.hasMore) p.loadProducts();
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        onFilter: (isActive) {
          final p = Provider.of<ProductProvider>(context, listen: false);
          isActive == null ? p.clearFilters() : p.setFilters(isActive: isActive);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _silk,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor: _black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: Colors.white54, size: 22),
                onPressed: _showFilterSheet,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text('Products',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -0.5)),
              background: Container(color: _black),
            ),
          ),

          // ── Search bar ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: StatefulBuilder(
                builder: (ctx, setS) => TextField(
                  controller: _searchController,
                  onChanged: (v) {
                    Provider.of<ProductProvider>(context, listen: false).searchProducts(v);
                    setS(() {});
                  },
                  style: const TextStyle(color: _black, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: TextStyle(color: _mid.withValues(alpha: 0.6), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: _mid, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: _mid),
                            onPressed: () {
                              _searchController.clear();
                              Provider.of<ProductProvider>(context, listen: false).searchProducts('');
                              setS(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: _silk,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _divLine)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _divLine)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _black, width: 1.5)),
                  ),
                ),
              ),
            ),
          ),

          // ── Upgrade nudge ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Consumer2<AuthProvider, ProductProvider>(
              builder: (context, auth, products, _) {
                if (auth.isPro) return const SizedBox.shrink();
                final total = products.products.length;
                if (total < 8) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => context.push('/upgrade'),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: _black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_rounded, color: Colors.white54, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "$total/10 products used — Go PRO for unlimited",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Learn More →',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Product list ─────────────────────────────────────────────────────
          Consumer<ProductProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading && provider.products.isEmpty) {
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: ShimmerListTile()),
                    childCount: 6,
                  ),
                );
              }

              if (provider.error != null && provider.products.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 48, color: _mid),
                        const SizedBox(height: 12),
                        Text(provider.error!,
                            style: const TextStyle(color: _mid),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => provider.loadProducts(refresh: true),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _black, foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (provider.products.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _divLine),
                          ),
                          child: const Icon(Icons.inventory_2_rounded, size: 36, color: _mid),
                        ),
                        const SizedBox(height: 16),
                        const Text('No products yet',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _black)),
                        const SizedBox(height: 6),
                        const Text('Add your first product to get started',
                            style: TextStyle(fontSize: 13, color: _mid)),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    if (i == provider.products.length) {
                      if (provider.isLoading && provider.hasMore) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator(color: _black, strokeWidth: 2)),
                        );
                      }
                      return const SizedBox.shrink();
                    }
                    final product = provider.products[i];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _ProductCard(
                        product: product,
                        onTap: () async {
                          await Navigator.push(ctx, MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(productUuid: product.uuid)));
                          if (!ctx.mounted) return;
                          provider.loadProducts(refresh: true);
                        },
                        onOptions: () => _showOptionsSheet(ctx, product.uuid),
                      ),
                    );
                  },
                  childCount: provider.products.length + (provider.hasMore ? 1 : 0),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
              context, MaterialPageRoute(builder: (_) => const ProductFormScreen()));
          if (!mounted) return;
          if (result == true) {
            // ignore: use_build_context_synchronously
            Provider.of<ProductProvider>(context, listen: false).loadProducts(refresh: true);
          }
        },
        backgroundColor: _black,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }

  void _showOptionsSheet(BuildContext ctx, String uuid) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: _divLine, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            _OptionTile(
              icon: Icons.edit_rounded, label: 'Edit Product', color: _black,
              onTap: () async {
                Navigator.pop(ctx);
                final result = await Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => ProductFormScreen(productUuid: uuid)));
                if (!ctx.mounted) return;
                if (result == true) {
                  Provider.of<ProductProvider>(ctx, listen: false).loadProducts(refresh: true);
                }
              },
            ),
            _OptionTile(
              icon: Icons.toggle_on_rounded, label: 'Toggle Active / Inactive',
              color: const Color(0xFF2D7A4F),
              onTap: () async {
                Navigator.pop(ctx);
                final p = Provider.of<ProductProvider>(ctx, listen: false);
                final ok = await p.toggleProductStatus(uuid);
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text(ok ? 'Status updated' : p.error ?? 'Error'),
                  backgroundColor: ok ? const Color(0xFF2D7A4F) : const Color(0xFF9B3030),
                ));
              },
            ),
            _OptionTile(
              icon: Icons.delete_rounded, label: 'Delete Product',
              color: const Color(0xFF9B3030),
              onTap: () { Navigator.pop(ctx); _confirmDelete(ctx, uuid); },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, String uuid) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Product',
            style: TextStyle(fontWeight: FontWeight.w700, color: _black)),
        content: const Text('This product will be permanently deleted. Are you sure?',
            style: TextStyle(color: _mid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _mid)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B3030), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(ctx);
              final p = Provider.of<ProductProvider>(ctx, listen: false);
              final ok = await p.deleteProduct(uuid);
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text(ok ? 'Product deleted' : p.error ?? 'Error'),
                backgroundColor: ok ? _black : const Color(0xFF9B3030),
              ));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Product Card ──────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final dynamic product;
  final VoidCallback onTap;
  final VoidCallback onOptions;
  const _ProductCard({required this.product, required this.onTap, required this.onOptions});

  @override
  Widget build(BuildContext context) {
    final isOut  = product.isOutOfStock as bool;
    final isLow  = product.isLowStock as bool;
    final isActive = product.isActive as bool;

    final stockLabel = isOut ? 'Out of Stock' : isLow ? 'Low Stock' : 'In Stock';
    final stockColor = isOut
        ? const Color(0xFF9B3030)
        : isLow
            ? const Color(0xFF8A6A2A)
            : const Color(0xFF2D7A4F);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _divLine),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
              child: SizedBox(
                width: 88, height: 88,
                child: () {
                  final imgUrl = (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                      ? product.imageUrl!
                      : (product.imageUrls != null && product.imageUrls!.isNotEmpty)
                          ? product.imageUrls!.first
                          : null;
                  return imgUrl != null
                      ? Image.network(imgUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _Placeholder())
                      : _Placeholder();
                }(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name.isNotEmpty ? product.name : '(No name)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: _black),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900, color: _black),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Chip(label: 'Stock: ${product.stockQuantity}',
                            color: stockColor),
                        const SizedBox(width: 6),
                        _Chip(
                          label: isActive ? 'Active' : 'Inactive',
                          color: isActive ? _charcoal : _mid,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: _mid, size: 20),
              onPressed: onOptions,
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF0EDE8),
    child: const Center(child: Icon(Icons.inventory_2_rounded, color: _mid, size: 28)),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}

// ── Filter Sheet ──────────────────────────────────────────────────────────────
class _FilterSheet extends StatelessWidget {
  final void Function(bool? isActive) onFilter;
  const _FilterSheet({required this.onFilter});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: _divLine, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          const Text('Filter Products',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _black)),
          const SizedBox(height: 14),
          _FilterOption(
            icon: Icons.all_inclusive_rounded, label: 'All Products',
            onTap: () { Navigator.pop(context); onFilter(null); },
          ),
          _FilterOption(
            icon: Icons.check_circle_outline_rounded, label: 'Active Only',
            color: const Color(0xFF2D7A4F),
            onTap: () { Navigator.pop(context); onFilter(true); },
          ),
          _FilterOption(
            icon: Icons.cancel_outlined, label: 'Inactive Only',
            color: const Color(0xFF9B3030),
            onTap: () { Navigator.pop(context); onFilter(false); },
          ),
        ],
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _FilterOption({required this.icon, required this.label,
      this.color = _black, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    ),
    title: Text(label,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}

// ── Option Tile ───────────────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OptionTile({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    ),
    title: Text(label,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}
