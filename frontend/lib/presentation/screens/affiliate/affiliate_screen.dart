import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/affiliate_api_datasource.dart';
import '../../../data/models/affiliate_model.dart';
import '../../widgets/modern_scaffold.dart';
import '../../widgets/modern_card.dart';

class AffiliateScreen extends StatefulWidget {
  const AffiliateScreen({super.key});

  @override
  State<AffiliateScreen> createState() => _AffiliateScreenState();
}

class _AffiliateScreenState extends State<AffiliateScreen> {
  AffiliateStats? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final sl = ServiceLocator();
      final ds = AffiliateApiDatasource(sl.dio, sl.tokenService);
      final stats = await ds.getMyCode();
      if (mounted) setState(() => _stats = stats);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyCode() {
    if (_stats == null) return;
    Clipboard.setData(ClipboardData(text: _stats!.referralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.cardDark,
        content: Text('Referral code copied!', style: TextStyle(color: Colors.white)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareWhatsApp() {
    if (_stats == null) return;
    final msg = '🎉 Manage your business easily with ZERA!\n'
        'Use my referral code when you register:\n\n'
        '👉 ${_stats!.referralCode}\n\n'
        'Refer 3 friends and get 1 month FREE!\n'
        'Download: https://zeramai.com';
    Share.share(msg);
  }

  @override
  Widget build(BuildContext context) {
    return ModernScaffold(
      title: 'Affiliate Program',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_error ?? 'Failed to load',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _load,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final s = _stats!;
    return RefreshIndicator(
      color: AppColors.accentBlue,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero ────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accentBlue, Color(0xFF1E3C72)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentBlue.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, size: 40, color: Colors.black),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Refer & Earn Pro',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Get 1 month of FREE access for every\n3 referrals who upgrade to Pro!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.black54, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Referral code card ───────────────────────────────────────────
            ModernCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SHARE YOUR CODE',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: Colors.white30),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          s.referralCode,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: _copyCode,
                          icon: const Icon(Icons.copy_rounded, color: AppColors.accentBlue),
                          tooltip: 'Copy code',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _shareWhatsApp,
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share Code via WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlue,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Stats ────────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _statModernCard('Network', '${s.totalReferrals}',
                      Icons.groups_rounded, AppColors.accentBlue)),
                const SizedBox(width: 12),
                Expanded(
                  child: _statModernCard('Pro Users', '${s.rewardedReferrals}',
                      Icons.verified_rounded, Colors.tealAccent)),
                const SizedBox(width: 12),
                Expanded(
                  child: _statModernCard('Waitlist', '${s.pendingReferrals}',
                      Icons.hourglass_empty_rounded, Colors.orangeAccent)),
              ],
            ),
            const SizedBox(height: 12),
            ModernCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentMagenta.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_today_rounded, color: AppColors.accentMagenta, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Rewards Earned',
                          style: TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${s.totalDaysEarned} Days Free Credit',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── How it works ─────────────────────────────────────────────────
            const Text(
              'HOW IT WORKS',
              style: TextStyle(
                color: Colors.white30,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ModernCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _buildStep(
                      '1',
                      'Propagate Code',
                      'Distribute your unique referral code to fellow entrepreneurs.',
                      AppColors.accentBlue),
                  _buildStep(
                      '2',
                      'Account Activation',
                      'Recipients must apply your code during the registration process.',
                      AppColors.accentMagenta),
                  _buildStep(
                      '3',
                      'Harvest Rewards',
                      'Instantly gain 1 month of Pro access once 3 referrals attain Pro status.',
                      Colors.tealAccent, isLast: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statModernCard(String label, String value, IconData icon, Color color) {
    return ModernCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color.withValues(alpha: 0.6), size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildStep(String num, String title, String desc, Color color, {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: Text(
              num,
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 12, color: Colors.white38, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
