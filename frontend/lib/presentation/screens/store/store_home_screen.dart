import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/store_provider.dart';
import '../../../data/models/store_models.dart';
import '../../../core/constants/api_constants.dart';

// ── Premium design tokens ─────────────────────────────────────────────────────
const _cream     = Color(0xFFFAF5EF);
const _creamDark = Color(0xFFF0E8DC);
const _ink       = Color(0xFF1A0A00);
const _inkLight  = Color(0xFF5C4033);
const _gold      = Color(0xFF9B7B4E);
const _saleRed   = Color(0xFF8B1A1A);
const _divider   = Color(0xFFDDD0C0);

class StoreHomeScreen extends StatefulWidget {
  final String businessUuid;
  const StoreHomeScreen({super.key, required this.businessUuid});

  @override
  State<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class _StoreHomeScreenState extends State<StoreHomeScreen> {
  final _searchController = TextEditingController();
  final _pageController   = PageController();
  Timer? _bannerTimer;
  int _bannerPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().loadStore(widget.businessUuid);
    });
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _bannerPage++);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  String _img(String? url) =>
      (url == null || url.isEmpty) ? '' : ApiConstants.fullUrl(url);

  @override
  Widget build(BuildContext context) {
    return Consumer<StoreProvider>(
      builder: (context, provider, _) {
        final store = provider.storeInfo;

        if (provider.isLoading && store == null) {
          return Scaffold(
            backgroundColor: _cream,
            body: Center(
              child: CircularProgressIndicator(color: _gold, strokeWidth: 2),
            ),
          );
        }

        if (provider.error != null && store == null) {
          return Scaffold(
            backgroundColor: _cream,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.store_mall_directory_outlined,
                        size: 64, color: _gold.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    Text(provider.error ?? 'Store not found',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _inkLight)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => provider.loadStore(widget.businessUuid),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _ink, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (store == null) {
          return const Scaffold(
            backgroundColor: _cream,
            body: Center(child: CircularProgressIndicator(color: _gold)),
          );
        }

        final banners = <String>[];
        if (store.bannerUrl != null && store.bannerUrl!.isNotEmpty) {
          banners.add(_img(store.bannerUrl));
        }
        for (final u in store.profileImageUrls ?? []) {
          final full = _img(u);
          if (full.isNotEmpty && !banners.contains(full)) banners.add(full);
        }

        final screenW = MediaQuery.of(context).size.width;
        const maxW = 480.0;
        final isWide = screenW > maxW;

        Widget content = Scaffold(
          backgroundColor: _cream,
          body: Column(
            children: [
              _PremiumHeader(
                store: store,
                searchController: _searchController,
                provider: provider,
                businessUuid: widget.businessUuid,
                onTrackOrder: () => _showTrackOrderDialog(context),
                onSearch: (v) {
                  provider.searchProducts(widget.businessUuid, v);
                  setState(() {});
                },
                onClearSearch: () {
                  _searchController.clear();
                  provider.searchProducts(widget.businessUuid, '');
                  setState(() {});
                },
              ),
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Banner
                    if (banners.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _PremiumBanner(
                          images: banners,
                          controller: _pageController,
                          currentPage: _bannerPage,
                          onPageChanged: (i) => setState(() => _bannerPage = i),
                        ),
                      ),

                    // Category pills
                    if (provider.categories.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _CategoryRow(
                          provider: provider,
                          businessUuid: widget.businessUuid,
                        ),
                      ),

                    // Section heading
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'Bestselling ',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            Text(
                              'Pieces',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 22,
                                fontWeight: FontWeight.w400,
                                fontStyle: FontStyle.italic,
                                color: _gold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${provider.products.length} items',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _inkLight,
                                  letterSpacing: 0.3),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Divider
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Divider(color: _divider, height: 1),
                      ),
                    ),

                    // Product Grid
                    if (provider.products.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 56,
                                  color: _gold.withOpacity(0.3)),
                              const SizedBox(height: 12),
                              Text('No products found',
                                  style: TextStyle(
                                      color: _inkLight, fontSize: 15)),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final p = provider.products[i];
                              final imgUrl = _img(
                                (p.imageUrls != null && p.imageUrls!.isNotEmpty)
                                    ? p.imageUrls!.first
                                    : p.imageUrl,
                              );
                              return _PremiumProductCard(
                                product: p,
                                imageUrl: imgUrl,
                                cartQty: provider.cartQuantityFor(p.uuid),
                                onTap: () => context.push(
                                    '/store/${widget.businessUuid}/product/${p.uuid}'),
                                onAdd: () => provider.addToCart(p),
                                onRemove: () => provider.updateQuantity(
                                    p.uuid,
                                    provider.cartQuantityFor(p.uuid) - 1),
                              );
                            },
                            childCount: provider.products.length,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.62,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                        ),
                      ),

                    SliverToBoxAdapter(
                        child: _PremiumFooter(store: store)),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ],
          ),
          bottomSheet: provider.cartItemCount > 0
              ? _CartBar(provider: provider, businessUuid: widget.businessUuid)
              : null,
        );

        if (isWide) {
          return Scaffold(
            backgroundColor: _creamDark,
            body: Center(
              child: SizedBox(width: maxW, child: content),
            ),
          );
        }

        return content;
      },
    );
  }

  void _showTrackOrderDialog(BuildContext context) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Track Order',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700, color: _ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your order number',
                style: TextStyle(color: _inkLight, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: c,
              decoration: InputDecoration(
                hintText: 'e.g. ORD-0001',
                labelText: 'Order Number',
                filled: true,
                fillColor: _cream,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _divider)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _divider)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _gold, width: 1.5)),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: _inkLight))),
          ElevatedButton(
            onPressed: () {
              final num = c.text.trim().toUpperCase();
              if (num.isNotEmpty) {
                Navigator.pop(ctx);
                context.push(
                    '/store/${widget.businessUuid}/order/$num');
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _ink, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Track'),
          ),
        ],
      ),
    );
  }
}

// ── Premium Header ─────────────────────────────────────────────────────────────
class _PremiumHeader extends StatelessWidget {
  final StoreInfo store;
  final TextEditingController searchController;
  final StoreProvider provider;
  final String businessUuid;
  final VoidCallback onTrackOrder;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;

  const _PremiumHeader({
    required this.store,
    required this.searchController,
    required this.provider,
    required this.businessUuid,
    required this.onTrackOrder,
    required this.onSearch,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final logoUrl = store.logoUrl != null && store.logoUrl!.isNotEmpty
        ? ApiConstants.fullUrl(store.logoUrl!)
        : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _divider)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _cream,
                      border: Border.all(color: _divider),
                    ),
                    child: logoUrl.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: logoUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Center(
                                child: Text(
                                  store.businessName[0].toUpperCase(),
                                  style: GoogleFonts.playfairDisplay(
                                      fontWeight: FontWeight.w700,
                                      color: _gold,
                                      fontSize: 18),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              store.businessName[0].toUpperCase(),
                              style: GoogleFonts.playfairDisplay(
                                  fontWeight: FontWeight.w700,
                                  color: _gold,
                                  fontSize: 18),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.playfairDisplay(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _ink),
                        ),
                        if (store.city != null && store.city!.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 11, color: _gold),
                              const SizedBox(width: 2),
                              Text(store.city!,
                                  style: TextStyle(
                                      fontSize: 11, color: _inkLight)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  // Cart icon
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => context.push(
                            '/store/$businessUuid/cart'),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _cream,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _divider),
                          ),
                          child: Icon(Icons.shopping_bag_outlined,
                              color: _ink, size: 22),
                        ),
                      ),
                      if (provider.cartItemCount > 0)
                        Positioned(
                          top: -4, right: -4,
                          child: Container(
                            width: 18, height: 18,
                            decoration: const BoxDecoration(
                                color: _saleRed, shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                '${provider.cartItemCount}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onTrackOrder,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _cream,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _divider),
                      ),
                      child: Icon(Icons.receipt_long_rounded,
                          color: _inkLight, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _divider),
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: onSearch,
                  style: TextStyle(color: _ink, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: TextStyle(color: _inkLight.withOpacity(0.5),
                        fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: _inkLight, size: 20),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 18, color: _inkLight),
                            onPressed: onClearSearch,
                          )
                        : null,
                    filled: false,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Banner ────────────────────────────────────────────────────────────────────
class _PremiumBanner extends StatelessWidget {
  final List<String> images;
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  const _PremiumBanner({
    required this.images,
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final count = images.length;
    final current = currentPage % count;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients && count > 1) {
        controller.animateToPage(current,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut);
      }
    });

    return Stack(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: controller,
            itemCount: count,
            onPageChanged: onPageChanged,
            itemBuilder: (_, i) => CachedNetworkImage(
              imageUrl: images[i % count],
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                color: _creamDark,
                child: Center(
                    child: Icon(Icons.storefront_rounded,
                        size: 48, color: _gold.withOpacity(0.3))),
              ),
            ),
          ),
        ),
        if (count > 1)
          Positioned(
            bottom: 10, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(count, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: i == current ? 20 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == current ? _gold : Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
          ),
      ],
    );
  }
}

// ── Category Row ──────────────────────────────────────────────────────────────
class _CategoryRow extends StatelessWidget {
  final StoreProvider provider;
  final String businessUuid;

  const _CategoryRow({required this.provider, required this.businessUuid});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          itemCount: provider.categories.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              final sel = provider.selectedCategoryUuid == null;
              return _CategoryPill(
                  label: 'All',
                  selected: sel,
                  onTap: () =>
                      provider.filterByCategory(businessUuid, null));
            }
            final cat = provider.categories[i - 1];
            final sel = provider.selectedCategoryUuid == cat.uuid;
            return _CategoryPill(
                label: cat.name,
                selected: sel,
                onTap: () =>
                    provider.filterByCategory(businessUuid, cat.uuid));
          },
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryPill(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? _ink : _cream,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? _ink : _divider),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _inkLight,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Premium Product Card ──────────────────────────────────────────────────────
class _PremiumProductCard extends StatelessWidget {
  final StoreProduct product;
  final String imageUrl;
  final int cartQty;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _PremiumProductCard({
    required this.product,
    required this.imageUrl,
    required this.cartQty,
    required this.onTap,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
        symbol: 'Rs. ', locale: 'en_IN', decimalDigits: 2);
    final isOut = !product.isAvailable;
    final hasSale = false; // Could be extended with original price later

    return GestureDetector(
      onTap: isOut ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: _creamDark),
                            errorWidget: (_, __, ___) => Container(
                              color: _creamDark,
                              child: Icon(Icons.shopping_bag_outlined,
                                  color: _gold.withOpacity(0.3), size: 32),
                            ),
                          )
                        : Container(
                            color: _creamDark,
                            child: Icon(Icons.shopping_bag_outlined,
                                color: _gold.withOpacity(0.3), size: 32),
                          ),
                  ),
                  // SALE badge
                  if (!isOut && product.stockQuantity > 0)
                    Positioned(
                      top: 0, left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        color: _saleRed,
                        child: const Text(
                          'SALE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  if (isOut)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      child: const Center(
                        child: Text('SOLD OUT',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 1.5)),
                      ),
                    ),
                  // Cart qty badge
                  if (cartQty > 0)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        width: 24, height: 24,
                        decoration: const BoxDecoration(
                            color: _ink, shape: BoxShape.circle),
                        child: Center(
                          child: Text('$cartQty',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Info
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                        height: 1.3,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fmt.format(product.price),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (!isOut)
                          SizedBox(
                            width: double.infinity,
                            height: 28,
                            child: cartQty == 0
                                ? OutlinedButton(
                                    onPressed: () {
                                      if (product.sizes.isNotEmpty) {
                                        onTap();
                                      } else {
                                        onAdd();
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _ink,
                                      side: BorderSide(color: _divider),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Text('Add to Bag',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                            color: _ink)),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: _ink,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        InkWell(
                                          onTap: onRemove,
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            child: Icon(Icons.remove,
                                                size: 12,
                                                color: Colors.white),
                                          ),
                                        ),
                                        Text('$cartQty',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13)),
                                        InkWell(
                                          onTap: onAdd,
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            child: Icon(Icons.add,
                                                size: 12,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cart Bar ──────────────────────────────────────────────────────────────────
class _CartBar extends StatelessWidget {
  final StoreProvider provider;
  final String businessUuid;

  const _CartBar({required this.provider, required this.businessUuid});

  @override
  Widget build(BuildContext context) {
    final fmt =
        NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);
    return GestureDetector(
      onTap: () => context.push('/store/$businessUuid/cart'),
      child: Container(
        height: 68,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${provider.cartItemCount}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Text('View Bag',
                style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            const Spacer(),
            Text(fmt.format(provider.cartTotal),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white54, size: 14),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────
class _PremiumFooter extends StatelessWidget {
  final StoreInfo store;
  const _PremiumFooter({required this.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 20, 12, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final phone = store.phone.replaceAll(RegExp(r'[^0-9]'), '');
              final dialCode = phone.length == 10 ? '91$phone' : phone;
              final msg =
                  'Hello ${store.businessName}, I would like to share my feedback: ';
              final uri = Uri.parse(
                  'whatsapp://send?phone=$dialCode&text=${Uri.encodeComponent(msg)}');
              await launchUrl(uri, mode: LaunchMode.externalApplication)
                  .catchError((_) => false);
            },
            icon: const Icon(Icons.chat_rounded, size: 16),
            label: const Text('Send Feedback on WhatsApp',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF25D366),
              side: const BorderSide(color: Color(0xFF25D366)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: _divider, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storefront_rounded, size: 12, color: _inkLight.withOpacity(0.4)),
              const SizedBox(width: 5),
              Text('Powered by ',
                  style: TextStyle(
                      color: _inkLight.withOpacity(0.4), fontSize: 11)),
              Text('ZERA',
                  style: TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}
