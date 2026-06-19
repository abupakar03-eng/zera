import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/debug_log_service.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'google_register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey          = GlobalKey<FormState>();
  final _phoneController  = TextEditingController();
  final _passController   = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading   = false;
  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.login(
      phone: _phoneController.text.trim(),
      password: _passController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      context.go('/dashboard');
    } else if (auth.error != null) {
      _showError(auth.error!);
      auth.clearError();
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await auth.loginWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    switch (result['status']) {
      case 'logged_in':
        context.go('/dashboard');
        break;
      case 'needs_registration':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => GoogleRegisterScreen(
            googleEmail: result['email'] ?? '',
            googleName:  result['name']  ?? '',
            supabaseToken: result['token'] ?? '',
          ),
        ));
        break;
      case 'cancelled':
        _showError('Google sign-in was cancelled. Please try again.');
        break;
      case 'redirect':
        break;
      default:
        _showError(result['message'] ?? 'Google sign-in failed');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final isWide = size.width > 600; // tablet / web

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen background image ─────────────────────────────────
          Image.asset(
            'assets/images/login_bg.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D1117), Color(0xFF1A2040), Color(0xFF0A0E1A)],
                ),
              ),
            ),
          ),

          // ── Cinematic dark gradient overlay ──────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x55000000), // top: 33% dark
                  Color(0x88000D1A), // mid: 53% teal-dark
                  Color(0xEE000000), // bottom: 93% black
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // ── Subtle teal glow (matches the cart icon color in image) ──────
          Positioned(
            top: isWide ? size.height * 0.05 : size.height * 0.08,
            left: 0, right: 0,
            child: Center(
              child: Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00E5FF).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: isWide
                    ? _buildWideLayout(context)
                    : _buildMobileLayout(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Wide layout (tablet / web): side-by-side ─────────────────────────────
  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        // Left: branding
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BrandLogo(),
                const SizedBox(height: 24),
                const Text(
                  'Your Business.\nOnline. Everywhere.',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sell smarter. Grow faster. ZERA gives\nyour business a powerful online presence.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.65),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                _FeaturePill(icon: Icons.store_rounded, label: 'Custom Online Store'),
                const SizedBox(height: 10),
                _FeaturePill(icon: Icons.bar_chart_rounded, label: 'Sales Analytics'),
                const SizedBox(height: 10),
                _FeaturePill(icon: Icons.payment_rounded, label: 'UPI & COD Payments'),
              ],
            ),
          ),
        ),
        // Right: form card
        Expanded(
          flex: 4,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: _LoginCard(
                  formKey:          _formKey,
                  phoneController:  _phoneController,
                  passController:   _passController,
                  obscurePass:      _obscurePass,
                  isLoading:        _isLoading,
                  onToggleObscure:  () => setState(() => _obscurePass = !_obscurePass),
                  onLogin:          _login,
                  onGoogle:         _loginWithGoogle,
                  onForgot:         () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                  onRegister:       () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  onLongPressLogo: kDebugMode ? () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sharing debug log…')));
                    await DebugLog.shareViaSystem();
                  } : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Mobile layout: stacked ─────────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        // Top branding area
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onLongPress: kDebugMode ? () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sharing debug log…')));
                    await DebugLog.shareViaSystem();
                  } : null,
                  child: _BrandLogo(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ZERA',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your Business. Online.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom card — slides up
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: _LoginCard(
              formKey:         _formKey,
              phoneController: _phoneController,
              passController:  _passController,
              obscurePass:     _obscurePass,
              isLoading:       _isLoading,
              onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
              onLogin:         _login,
              onGoogle:        _loginWithGoogle,
              onForgot: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
              onRegister: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen())),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Brand Logo ──────────────────────────────────────────────────────────────
class _BrandLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        width: 68, height: 68,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
        ),
        child: const Icon(Icons.store_rounded, size: 34, color: Colors.white),
      ),
    ),
  );
}

// ── Feature Pill (wide layout only) ─────────────────────────────────────────
class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF00E5FF), size: 16),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: 14)),
    ],
  );
}

// ── Login Card (frosted glass) ───────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController passController;
  final bool obscurePass;
  final bool isLoading;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;
  final VoidCallback onGoogle;
  final VoidCallback onForgot;
  final VoidCallback onRegister;
  final VoidCallback? onLongPressLogo;

  const _LoginCard({
    required this.formKey,
    required this.phoneController,
    required this.passController,
    required this.obscurePass,
    required this.isLoading,
    required this.onToggleObscure,
    required this.onLogin,
    required this.onGoogle,
    required this.onForgot,
    required this.onRegister,
    this.onLongPressLogo,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
          ),
          padding: const EdgeInsets.all(28),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign in to your account',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 28),

                // Phone
                _glassLabel('Phone Number'),
                const SizedBox(height: 8),
                _GlassField(
                  controller: phoneController,
                  hint: '10-digit mobile number',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Phone number required';
                    if (v.length < 10) return 'Enter 10-digit number';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Password
                _glassLabel('Password'),
                const SizedBox(height: 8),
                _GlassField(
                  controller: passController,
                  hint: 'Enter your password',
                  icon: Icons.lock_rounded,
                  obscureText: obscurePass,
                  suffix: IconButton(
                    icon: Icon(
                      obscurePass ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: onToggleObscure,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password required';
                    if (v.length < 8) return 'Minimum 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Forgot
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: onForgot,
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                // Sign In button
                _GlassButton(label: 'Sign In', isLoading: isLoading, onPressed: onLogin),
                const SizedBox(height: 14),

                // Divider
                Row(children: [
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                ]),
                const SizedBox(height: 14),

                // Google Sign-In
                _GoogleButton(onPressed: isLoading ? null : onGoogle),
                const SizedBox(height: 24),

                // Register row
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("New to ZERA? ",
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
                          GestureDetector(
                            onTap: isLoading ? null : onRegister,
                            child: const Text('Create Account',
                                style: TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFF00E5FF),
                                )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '🎉 Free for 1 month — No credit card needed',
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Footer
                _LegalFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassLabel(String text) => Text(
    text,
    style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.8)),
  );
}

// ── Glass Input Field ─────────────────────────────────────────────────────────
class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _GlassField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    style: const TextStyle(color: Colors.white, fontSize: 15),
    validator: validator,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5)),
      errorStyle: const TextStyle(color: Color(0xFFFF9090)),
    ),
  );
}

// ── Sign In Button ─────────────────────────────────────────────────────────────
class _GlassButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  const _GlassButton({required this.label, required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
            blurRadius: 20, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: isLoading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: 0.5)),
      ),
    ),
  );
}

// ── Google Button ──────────────────────────────────────────────────────────────
class _GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _GoogleButton({this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: Image.network(
        'https://developers.google.com/identity/images/g-logo.png',
        height: 20, width: 20,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.login, size: 18, color: Colors.white),
      ),
      label: const Text('Continue with Google'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
  );
}

// ── Legal Footer ───────────────────────────────────────────────────────────────
class _LegalFooter extends StatelessWidget {
  void _showSheet(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, maxChildSize: 0.92, minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Text(title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(24),
                child: Text(content,
                    style: const TextStyle(fontSize: 14, height: 1.7,
                        color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.15), thickness: 1),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6, runSpacing: 4,
          children: [
            _FooterLink(label: 'Privacy Policy',
              onTap: () => _showSheet(context, 'Privacy Policy',
                'ZERA ("we", "our", "us") is committed to protecting your privacy.\n\n'
                '1. Information We Collect\nWe collect your phone number, business name, and transaction data to provide our services.\n\n'
                '2. How We Use It\nYour data is used to operate the app, process orders, and improve our services. We never sell your personal data.\n\n'
                '3. Data Security\nAll data is encrypted in transit (TLS) and at rest. We use industry-standard security practices.\n\n'
                '4. Your Rights\nYou can request deletion of your account and data at any time by contacting contactus@zeramai.com.\n\n'
                '5. Cookies\nWe use minimal cookies for session management only.\n\nLast updated: April 2026',
              ),
            ),
            Text('·', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
            _FooterLink(label: 'Terms of Use',
              onTap: () => _showSheet(context, 'Terms of Use',
                'By using ZERA, you agree to the following terms:\n\n'
                '1. Eligibility\nYou must be 18 years or older and a registered business owner.\n\n'
                '2. Acceptable Use\nYou agree not to misuse the platform for fraudulent, illegal, or harmful activities.\n\n'
                '3. Payments\nAll payment transactions are processed securely.\n\n'
                '4. Intellectual Property\nAll content, trademarks, and logos within ZERA are owned by ZERA Pvt. Ltd.\n\n'
                '5. Termination\nWe reserve the right to suspend accounts that violate these terms.\n\nLast updated: April 2026',
              ),
            ),
            Text('·', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
            _FooterLink(label: 'Contact Us',
              onTap: () => _showSheet(context, 'Contact & Support',
                '📧  Email: contactus@zeramai.com\n\n'
                '📞  Phone: 9080537845, 9384364069\n\n'
                '🌐  Website: www.zeramai.com\n\n'
                '📍  Office:\n     1st Floor, Covai Tech Park,\n'
                '     Near Viswasapuram Bus Stop,\n'
                '     Sathy Road, Saravanampatti,\n'
                '     Coimbatore – 641035, TN\n\n'
                'We typically respond within 24 business hours.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '© 2026 ZERA. All rights reserved.',
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Text(label,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.5),
          decoration: TextDecoration.underline,
          decorationColor: Colors.white.withValues(alpha: 0.3),
        )),
  );
}
