import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/store_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/store_models.dart';

class StoreCartScreen extends StatelessWidget {
  final String businessUuid;
  const StoreCartScreen({super.key, required this.businessUuid});

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

    return Consumer<StoreProvider>(
      builder: (context, provider, _) {
        final cart = provider.cart;

        return Scaffold(
          backgroundColor: const Color(0xFF070B19), // Deep navy
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text('Your Bag (${provider.cartItemCount})', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
            leading: const BackButton(color: Colors.white),
            actions: [
              if (cart.isNotEmpty)
                TextButton(
                  onPressed: () => provider.clearCart(),
                  child: const Text('Clear All', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ),
            ],
          ),
          body: Stack(
            children: [
              // Glows
              Positioned(
                bottom: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.accentBlue.withValues(alpha: 0.1), blurRadius: 150)],
                  ),
                ),
              ),
              
              cart.isEmpty
                  ? _buildEmptyState(context)
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                            itemCount: cart.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final item = cart[index];
                              return _CartItemTile(
                                item: item,
                                fmt: currencyFmt,
                                onUpdate: (qty) => provider.updateQuantity(item.product.uuid, qty),
                              );
                            },
                          ),
                        ),
                        _buildSummary(context, provider, currencyFmt),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), shape: BoxShape.circle),
            child: const Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.white10),
          ),
          const SizedBox(height: 24),
          const Text('Your bag is currently empty', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Looks like you haven\'t added any items yet.', style: TextStyle(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.pop(),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentBlue, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
            child: const Text('Start Shopping', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, StoreProvider provider, NumberFormat fmt) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: const Border(top: BorderSide(color: Colors.white10)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(fmt.format(provider.cartTotal), style: const TextStyle(color: AppColors.accentBlue, fontSize: 24, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push('/store/$businessUuid/checkout'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text('Review Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final NumberFormat fmt;
  final Function(int) onUpdate;

  const _CartItemTile({required this.item, required this.fmt, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 80,
              height: 80,
              child: item.product.imageUrl != null
                  ? CachedNetworkImage(imageUrl: ApiConstants.fullUrl(item.product.imageUrl!), fit: BoxFit.cover)
                  : Container(color: Colors.white.withValues(alpha: 0.02), child: const Icon(Icons.inventory_2_outlined, color: Colors.white10)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(fmt.format(item.product.price), style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.w500, fontSize: 13)),
                    if (item.selectedSize != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.cyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.cyan.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          item.selectedSize!,
                          style: const TextStyle(color: Colors.cyan, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: 100,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _QtyAction(icon: Icons.remove, onTap: () => onUpdate(item.quantity - 1)),
                      Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      _QtyAction(icon: Icons.add, onTap: () => onUpdate(item.quantity + 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(fmt.format(item.total), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
        ],
      ),
    );
  }
}

class _QtyAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 14, color: Colors.white70)));
  }
}
