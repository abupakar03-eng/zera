import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/store_models.dart';
import '../../../core/theme/app_theme.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final String businessUuid;
  final StoreOrderResult order;

  const OrderConfirmationScreen({
    super.key,
    required this.businessUuid,
    required this.order,
  });

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _shareOnWhatsApp() async {
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');

    final itemLines = widget.order.items.map((i) {
      final skuPart = (i.productSku != null && i.productSku!.isNotEmpty)
          ? ' [${i.productSku}]' : '';
      return '  • ${i.productName}$skuPart x${i.quantity}';
    }).join('\n');

    final message = '''
🛍️ *Order Confirmation*

Order No: *${widget.order.orderNumber}*
Status: ${widget.order.status}
Total: ₹${fmt.format(widget.order.totalAmount)}

*Items:*
$itemLines

Thank you for shopping with us!
''';

    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
       Share.share(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFF070B19),
      body: Stack(
        children: [
          // Ambient Glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.accentBlue.withValues(alpha: 0.1), blurRadius: 150)]),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  const Spacer(),
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.1)),
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: AppColors.accentBlue, size: 100),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text('Order Confirmed!', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Text(
                    'Your order #${widget.order.orderNumber} has been placed successfully. We are processing it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 48),

                  // Detail Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          children: [
                            _DetailRow(label: 'Order ID', value: widget.order.orderNumber, isLink: true),
                            const Divider(color: Colors.white12, height: 32),
                            // Items list with variant/SKU
                            ...widget.order.items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.productName,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13)),
                                        if (item.productSku != null && item.productSku!.isNotEmpty)
                                          Text('SKU: ${item.productSku}',
                                              style: TextStyle(
                                                  color: AppColors.accentBlue.withValues(alpha: 0.8),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  Text('×${item.quantity}  ${currencyFmt.format(item.totalPrice)}',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            )),
                            const Divider(color: Colors.white12, height: 24),
                            _DetailRow(label: 'Total Amount', value: currencyFmt.format(widget.order.totalAmount), isBold: true),
                            const SizedBox(height: 16),
                            _DetailRow(label: 'Payment', value: widget.order.paymentMethod),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _shareOnWhatsApp,
                          icon: const Icon(Icons.share_rounded, size: 20),
                          label: const Text('Share Receipt'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white10),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => context.go('/store/${widget.businessUuid}'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accentBlue,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Go Home', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isLink;

  const _DetailRow({required this.label, required this.value, this.isBold = false, this.isLink = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            color: isBold ? AppColors.accentBlue : (isLink ? AppColors.accentBlue : Colors.white),
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            fontSize: isBold ? 18 : 14,
          ),
        ),
      ],
    );
  }
}
