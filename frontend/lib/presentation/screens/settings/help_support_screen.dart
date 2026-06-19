import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _whatsappNumber = '919384364069';
  static const _supportEmail = 'contactus@zeramai.com';
  static const _whatsappMessage =
      'Hi, I need help with ZERA. Please assist me.';

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse(
      'https://wa.me/$_whatsappNumber?text=${Uri.encodeComponent(_whatsappMessage)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp could not be opened')),
        );
      }
    }
  }

  Future<void> _openEmail(BuildContext context) async {
    // Build mailto string manually — avoids encoding issues with queryParameters
    final mailtoStr =
        'mailto:$_supportEmail?subject=${Uri.encodeComponent('ZERA Support Request')}'
        '&body=${Uri.encodeComponent('Hi ZERA Team,\n\nI need help with:\n\n')}';
    try {
      final launched = await launchUrl(
        Uri.parse(mailtoStr),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showCopyEmailSnackbar(context);
      }
    } catch (_) {
      if (context.mounted) _showCopyEmailSnackbar(context);
    }
  }

  void _showCopyEmailSnackbar(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: _supportEmail));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Email copied to clipboard: $_supportEmail'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help & Support',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.headset_mic_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'We\'re here to help!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reach out to us anytime. We typically respond within a few hours.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'Contact Us',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // WhatsApp button
            _ContactCard(
              icon: Icons.chat_rounded,
              iconColor: const Color(0xFF25D366),
              iconBg: const Color(0xFF25D366).withOpacity(0.1),
              title: 'Chat on WhatsApp',
              subtitle: '+91 93843 64069',
              badge: 'Fastest Response',
              badgeColor: const Color(0xFF25D366),
              onTap: () => _openWhatsApp(context),
            ),

            const SizedBox(height: 12),

            // Email button
            _ContactCard(
              icon: Icons.email_rounded,
              iconColor: AppColors.primary,
              iconBg: AppColors.primary.withOpacity(0.1),
              title: 'Send an Email',
              subtitle: _supportEmail,
              badge: 'Within 24 hours',
              badgeColor: AppColors.primary,
              onTap: () => _openEmail(context),
            ),

            const SizedBox(height: 28),

            Text(
              'FAQs',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            const _FaqItem(
              question: 'How do I add products?',
              answer:
                  'Go to Products from the menu, tap the + button, fill in the details and save.',
            ),
            const _FaqItem(
              question: 'How do I share my store link?',
              answer:
                  'Open Business Profile, tap "Share Store Link" to copy or share your unique store URL.',
            ),
            const _FaqItem(
              question: 'How do I upgrade to PAID plan?',
              answer:
                  'Go to "PRO Features" from the menu to learn about available plans.',
            ),
            const _FaqItem(
              question: 'How do I download reports?',
              answer:
                  'Go to Reports, select the report type and date range, then tap the Download PDF or CSV button.',
            ),
            const _FaqItem(
              question: 'My OTP is not received, what to do?',
              answer:
                  'Check your network, wait 30 seconds, then tap "Resend OTP". If still not received, contact support.',
            ),

            const SizedBox(height: 28),

            Text(
              'Legal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _ContactCard(
              icon: Icons.privacy_tip_rounded,
              iconColor: const Color(0xFF5C6BC0),
              iconBg: const Color(0xFF5C6BC0).withOpacity(0.1),
              title: 'Privacy Policy',
              subtitle: 'storelink.sbs/privacy',
              badge: 'Required',
              badgeColor: const Color(0xFF5C6BC0),
              onTap: () => launchUrl(
                Uri.parse('https://storelink.sbs/privacy'),
                mode: LaunchMode.externalApplication,
              ),
            ),

            const SizedBox(height: 28),

            // Business hours
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded,
                      color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Support Hours',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mon – Sat, 9:00 AM – 7:00 PM IST',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Contact Card ─────────────────────────────────────────────────────────────
class _ContactCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── FAQ Item ──────────────────────────────────────────────────────────────────
class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                Text(
                  widget.answer,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
