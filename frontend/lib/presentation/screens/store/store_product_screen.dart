import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/store_provider.dart';
import '../../../core/constants/api_constants.dart';

const _cream     = Color(0xFFFAF5EF);
const _creamDark = Color(0xFFF0E8DC);
const _ink       = Color(0xFF1A0A00);
const _inkLight  = Color(0xFF5C4033);
const _gold      = Color(0xFF9B7B4E);
const _saleRed   = Color(0xFF8B1A1A);
const _divider   = Color(0xFFDDD0C0);

class StoreProductScreen extends StatefulWidget {
  final String businessUuid;
  final String productUuid;

  const StoreProductScreen({
    super.key,
    required this.businessUuid,
    required this.productUuid,
  });

  @override
  State<StoreProductScreen> createState() => _StoreProductScreenState();
}

class _StoreProductScreenState extends State<StoreProductScreen> {
  String? _selectedSize;
  int _imageIndex = 0;
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StoreProvider>();
      if (provider.products.isEmpty && provider.error == null) {
        provider.loadStore(widget.businessUuid);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _img(String? url) =>
      (url == null || url.isEmpty) ? '' : ApiConstants.fullUrl(url);

  @override
  Widget build(BuildContext context) {
    return Consumer<StoreProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.products.isEmpty) {
          return const Scaffold(
            backgroundColor: _cream,
            body: Center(child: CircularProgressIndicator(color: _gold)),
          );
        }

        final product = provider.products
            .where((p) => p.uuid == widget.productUuid)
            .firstOrNull;

        if (product == null) {
          return Scaffold(
            backgroundColor: _cream,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: BackButton(color: _ink),
              title: Text('Product',
                  style: GoogleFonts.playfairDisplay(
                      color: _ink, fontWeight: FontWeight.w700)),
            ),
            body: const Center(
              child: Text('Product not found.',
                  style: TextStyle(color: _inkLight)),
            ),
          );
        }

        final images = <String>[];
        if (product.imageUrls != null && product.imageUrls!.isNotEmpty) {
          for (final u in product.imageUrls!) {
            final f = _img(u);
            if (f.isNotEmpty) images.add(f);
          }
        }
        if (images.isEmpty && product.imageUrl != null) {
          final f = _img(product.imageUrl);
          if (f.isNotEmpty) images.add(f);
        }

        final fmt = NumberFormat.currency(
            symbol: 'Rs. ', locale: 'en_IN', decimalDigits: 2);
        final inCart =
            provider.cartQuantityForSize(product.uuid, _selectedSize);
        final isOut = !product.isAvailable;

        return Scaffold(
          backgroundColor: _cream,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 1,
            shadowColor: _divider,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: _ink, size: 20),
              onPressed: () => context.pop(),
            ),
            title: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _ink),
            ),
            actions: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_bag_outlined, color: _ink),
                    onPressed: () =>
                        context.push('/store/${widget.businessUuid}/cart'),
                  ),
                  if (provider.cartItemCount > 0)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(
                            color: _saleRed, shape: BoxShape.circle),
                        child: Center(
                          child: Text('${provider.cartItemCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Image gallery ─────────────────────────────────────
                      Stack(
                        children: [
                          SizedBox(
                            height: 360,
                            child: images.isNotEmpty
                                ? PageView.builder(
                                    controller: _pageController,
                                    itemCount: images.length,
                                    onPageChanged: (i) =>
                                        setState(() => _imageIndex = i),
                                    itemBuilder: (_, i) =>
                                        CachedNetworkImage(
                                      imageUrl: images[i],
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: _creamDark,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                              color: _gold, strokeWidth: 2),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: _creamDark,
                                        child: Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 64,
                                            color: _gold.withValues(alpha: 0.3)),
                                      ),
                                    ),
                                  )
                                : Container(
                                    height: 360,
                                    color: _creamDark,
                                    child: Icon(Icons.shopping_bag_outlined,
                                        size: 80,
                                        color: _gold.withValues(alpha: 0.2)),
                                  ),
                          ),
                          // SALE badge
                          if (!isOut)
                            Positioned(
                              top: 0, left: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                color: _saleRed,
                                child: const Text('SALE',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5)),
                              ),
                            ),
                          // Sold out overlay
                          if (isOut)
                            Container(
                              height: 360,
                              color: Colors.black.withValues(alpha: 0.4),
                              child: const Center(
                                child: Text('SOLD OUT',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        letterSpacing: 3)),
                              ),
                            ),
                          // Dots
                          if (images.length > 1)
                            Positioned(
                              bottom: 14, left: 0, right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(images.length, (i) =>
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: i == _imageIndex ? 20 : 6,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      decoration: BoxDecoration(
                                        color: i == _imageIndex
                                            ? _gold
                                            : Colors.white
                                                .withValues(alpha: 0.6),
                                        borderRadius:
                                            BorderRadius.circular(3),
                                      ),
                                    )),
                              ),
                            ),
                        ],
                      ),

                      // ── Product info ──────────────────────────────────────
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.categoryName != null &&
                                product.categoryName!.isNotEmpty)
                              Text(
                                product.categoryName!.toUpperCase(),
                                style: TextStyle(
                                    color: _gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              product.name,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  fmt.format(product.price),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: _ink,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isOut
                                        ? Colors.grey.shade200
                                        : _saleRed.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isOut ? 'Out of Stock' : 'In Stock',
                                    style: TextStyle(
                                      color: isOut
                                          ? Colors.grey.shade500
                                          : _saleRed,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── Description ───────────────────────────────────────
                      if (product.description != null &&
                          product.description!.isNotEmpty)
                        Container(
                          color: Colors.white,
                          padding:
                              const EdgeInsets.fromLTRB(20, 18, 20, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Description',
                                  style: GoogleFonts.playfairDisplay(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _ink)),
                              const SizedBox(height: 10),
                              Divider(color: _divider, height: 1),
                              const SizedBox(height: 12),
                              Text(
                                product.description!,
                                style: const TextStyle(
                                    color: _inkLight,
                                    fontSize: 14,
                                    height: 1.65),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),

                      // ── Size selector ─────────────────────────────────────
                      if (product.sizes.isNotEmpty)
                        Container(
                          color: Colors.white,
                          padding:
                              const EdgeInsets.fromLTRB(20, 18, 20, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Select Size',
                                      style: GoogleFonts.playfairDisplay(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: _ink)),
                                  const Spacer(),
                                  if (_selectedSize != null)
                                    Text(_selectedSize!,
                                        style: TextStyle(
                                            color: _gold,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Divider(color: _divider, height: 1),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: product.sizes.map((size) {
                                  final sel = _selectedSize == size;
                                  return GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedSize = size),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: sel ? _ink : _cream,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        border: Border.all(
                                          color:
                                              sel ? _ink : _divider,
                                          width: 1.5,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        size,
                                        style: TextStyle(
                                          color: sel
                                              ? Colors.white
                                              : _inkLight,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),

                      // ── Details ───────────────────────────────────────────
                      Container(
                        color: Colors.white,
                        padding:
                            const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Details',
                                style: GoogleFonts.playfairDisplay(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _ink)),
                            const SizedBox(height: 10),
                            Divider(color: _divider, height: 1),
                            const SizedBox(height: 12),
                            _DetailRow('Unit',
                                product.unit ?? 'Piece'),
                            _DetailRow('Availability',
                                product.isAvailable
                                    ? 'In Stock'
                                    : 'Sold Out'),
                            _DetailRow('Available Qty',
                                '${product.stockQuantity} items'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),

              // ── Sticky bottom bar ─────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: _divider)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, -3)),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    12 +
                        MediaQuery.of(context).padding.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (product.sizes.isNotEmpty && _selectedSize == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Please select a size to continue',
                          style: TextStyle(
                              color: _saleRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    Row(
                      children: [
                        if (inCart > 0) ...[
                          _QtyButton(
                            icon: Icons.remove,
                            onTap: () => provider.removeFromCart(
                                product.uuid,
                                selectedSize: _selectedSize),
                          ),
                          Container(
                            width: 44,
                            alignment: Alignment.center,
                            child: Text('$inCart',
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900)),
                          ),
                          _QtyButton(
                            icon: Icons.add,
                            onTap: () => provider.addToCart(product,
                                selectedSize: _selectedSize),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isOut
                                  ? null
                                  : () {
                                      if (product.sizes.isNotEmpty &&
                                          _selectedSize == null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content: Text(
                                              'Please select a size first'),
                                          backgroundColor: _saleRed,
                                          duration:
                                              Duration(seconds: 2),
                                        ));
                                        return;
                                      }
                                      if (inCart == 0) {
                                        provider.addToCart(product,
                                            selectedSize: _selectedSize);
                                      } else {
                                        context.push(
                                            '/store/${widget.businessUuid}/cart');
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isOut
                                    ? Colors.grey.shade300
                                    : _ink,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(6)),
                              ),
                              child: Text(
                                isOut
                                    ? 'Currently Unavailable'
                                    : inCart > 0
                                        ? 'View Bag'
                                        : 'Add to Bag',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    color: _inkLight, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _cream,
          border: Border.all(color: _divider),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: _ink),
      ),
    );
  }
}
