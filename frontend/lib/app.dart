import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/google_register_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/business/business_profile_screen.dart';
import 'presentation/screens/reports/reports_screen.dart';
import 'presentation/screens/products/products_list_screen.dart';
import 'presentation/screens/customers/customers_list_screen.dart';
import 'presentation/screens/orders/orders_list_screen.dart';
import 'presentation/screens/categories/categories_list_screen.dart';
import 'presentation/screens/inventory/inventory_list_screen.dart';
import 'presentation/screens/business/upgrade_plan_screen.dart';
import 'presentation/screens/store/store_home_screen.dart';
import 'presentation/screens/store/store_product_screen.dart';
import 'presentation/screens/store/store_cart_screen.dart';
import 'presentation/screens/store/store_checkout_screen.dart';
import 'presentation/screens/store/order_confirmation_screen.dart';
import 'presentation/screens/store/order_status_screen.dart';
import 'presentation/screens/admin/admin_portal_screen.dart';
import 'presentation/screens/settings/help_support_screen.dart';
import 'core/services/biometric_service.dart';
import 'core/services/debug_log_service.dart';
import 'core/utils/web_bridge.dart'
    if (dart.library.html) 'core/utils/web_bridge_web.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/dashboard_provider.dart';
import 'presentation/providers/order_provider.dart';
import 'presentation/providers/store_provider.dart';
import 'data/models/store_models.dart';

class StoreLinkApp extends StatelessWidget {
  const StoreLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ZERA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    // ── Auth / Business owner routes ──────────────────────────────────────
    GoRoute(path: '/', builder: (_, __) => const AuthWrapper()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(
      path: '/auth-callback',
      builder: (context, state) => _GoogleAuthCallbackScreen(deepLinkUri: state.uri),
    ),
    GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/business-profile', builder: (_, __) => const BusinessProfileScreen()),
    GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
    GoRoute(path: '/products', builder: (_, __) => const ProductsListScreen()),
    GoRoute(path: '/customers', builder: (_, __) => const CustomersListScreen()),
    GoRoute(path: '/orders', builder: (_, __) => const OrdersListScreen()),
    GoRoute(path: '/categories', builder: (_, __) => const CategoriesListScreen()),
    GoRoute(path: '/inventory', builder: (_, __) => const InventoryListScreen()),
    GoRoute(path: '/upgrade', builder: (_, __) => const UpgradePlanScreen()),
    GoRoute(path: '/help-support', builder: (_, __) => const HelpSupportScreen()),
    GoRoute(path: '/admin', builder: (_, __) => const AdminPortalScreen()),

    // ── Customer store routes (public, no auth needed) ────────────────────
    ShellRoute(
      builder: (context, state, child) {
        return ChangeNotifierProvider(
          create: (_) => StoreProvider(),
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/store/:businessUuid',
          builder: (context, state) {
            final uuid = state.pathParameters['businessUuid']!;
            return StoreHomeScreen(businessUuid: uuid);
          },
          routes: [
            GoRoute(
              path: 'product/:productUuid',
              builder: (context, state) {
                return StoreProductScreen(
                  businessUuid: state.pathParameters['businessUuid']!,
                  productUuid: state.pathParameters['productUuid']!,
                );
              },
            ),
            GoRoute(
              path: 'cart',
              builder: (context, state) {
                return StoreCartScreen(
                  businessUuid: state.pathParameters['businessUuid']!,
                );
              },
            ),
            GoRoute(
              path: 'checkout',
              builder: (context, state) {
                return StoreCheckoutScreen(
                  businessUuid: state.pathParameters['businessUuid']!,
                );
              },
            ),
            GoRoute(
              path: 'confirmed',
              builder: (context, state) {
                final order = state.extra as StoreOrderResult;
                return OrderConfirmationScreen(
                  businessUuid: state.pathParameters['businessUuid']!,
                  order: order,
                );
              },
            ),
            GoRoute(
              path: 'order/:orderNumber',
              builder: (context, state) {
                return OrderStatusScreen(
                  businessUuid: state.pathParameters['businessUuid']!,
                  orderNumber: state.pathParameters['orderNumber']!,
                );
              },
            ),
          ],
        ),
      ],
    ),
  ],
);

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool _navigated = false;
  bool _appWasInBackground = false;
  bool _isAuthenticating = false;
  final _bio = BiometricService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).checkAuthStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _appWasInBackground = true;
    } else if (state == AppLifecycleState.resumed && _appWasInBackground) {
      _appWasInBackground = false;
      _triggerBiometricOnResume();
    }
  }

  Future<void> _triggerBiometricOnResume() async {
    if (_isAuthenticating) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) return;
    final bioEnabled = await _bio.isEnabled();
    if (!mounted) return;
    if (bioEnabled) {
      _isAuthenticating = true;
      final ok = await _bio.authenticate();
      _appWasInBackground = false;
      _isAuthenticating = false;
      if (!mounted) return;
      if (!ok) {
        await authProvider.logout();
        if (mounted) context.go('/login');
        return;
      }
    }
    // Refresh key data after returning to foreground so the UI is up to date
    _refreshDataOnResume();
  }

  void _refreshDataOnResume() {
    if (!mounted) return;
    try {
      Provider.of<DashboardProvider>(context, listen: false).refreshStats();
    } catch (_) {}
    try {
      Provider.of<OrderProvider>(context, listen: false).loadOrders(refresh: true);
    } catch (_) {}
  }

  Future<void> _handleAuthenticated(BuildContext ctx) async {
    if (_isAuthenticating) return;

    final bioEnabled = await _bio.isEnabled();
    if (!mounted) return;
    if (!bioEnabled) {
      ctx.go('/dashboard');
      return;
    }

    _isAuthenticating = true;
    _appWasInBackground = false;
    final ok = await _bio.authenticate();
    _appWasInBackground = false;
    _isAuthenticating = false;

    if (!mounted) return;
    if (ok) {
      ctx.go('/dashboard');
    } else {
      // Biometric failed — fall back to login
      final authProvider = Provider.of<AuthProvider>(ctx, listen: false);
      await authProvider.logout();
      if (!mounted) return;
      ctx.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show loading splash while checking
        if (authProvider.status == AuthStatus.loading ||
            authProvider.status == AuthStatus.initial) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6C63FF), Color(0xFF3B3ACF)],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          );
        }

        // Redirect after frame so go_router navigation stack is ready
        if (!_navigated) {
          _navigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;

            // Check if the deep-link target is a public store route.
            // On web, GoRouterState.uri reflects the matched route ('/'), not
            // the browser URL when the app first loads at /store/<uuid>.
            // Use Uri.base.path on web to read the actual browser URL.
            final location = kIsWeb
                ? Uri.base.path
                : GoRouterState.of(context).uri.toString();
            if (location.startsWith('/store/')) {
              // Navigate to the store — GoRouter will pick up the path.
              if (mounted) context.go(location);
              return;
            }

            if (authProvider.status == AuthStatus.authenticated) {
              await _handleAuthenticated(context);
            } else {
              context.go('/login');
            }
          });
        }

        // Blank while redirect happens
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

/// Handles the redirect back from Supabase Google OAuth.
/// On web: the browser redirects here after OAuth.
/// On mobile: GoRouter navigates here when the deep link fires
/// (com.storelink.app://auth-callback?code=xxx). We manually exchange
/// the PKCE code because app_links may not receive the URI when GoRouter
/// has already consumed the navigation intent.
class _GoogleAuthCallbackScreen extends StatefulWidget {
  final Uri? deepLinkUri;
  const _GoogleAuthCallbackScreen({this.deepLinkUri});

  @override
  State<_GoogleAuthCallbackScreen> createState() => _GoogleAuthCallbackScreenState();
}

class _GoogleAuthCallbackScreenState extends State<_GoogleAuthCallbackScreen> {
  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final deepLinkUri = widget.deepLinkUri;

    // ── Web-to-app bridge path ────────────────────────────────────────────────
    // When com.storelink.app://auth-callback arrives with access_token instead
    // of a PKCE code, it came from the web app bridging us the Supabase token.
    if (!kIsWeb &&
        deepLinkUri != null &&
        deepLinkUri.queryParameters.containsKey('access_token')) {
      DebugLog.i('GoogleAuth', 'callback-screen: branch=web-token-bridge');
      final accessToken = deepLinkUri.queryParameters['access_token']!;
      final result = await authProvider.handleWebRedirectToken(accessToken);
      if (!mounted) return;
      DebugLog.i('GoogleAuth', 'callback-screen: web-token-bridge result=${result['status']}');
      _routeFromResult(result, fallbackToken: accessToken);
      return;
    }

    // ── Passive path ─────────────────────────────────────────────────────────
    // loginWithGoogle() is still running — just wait for it to resolve.
    if (!kIsWeb && authProvider.isProcessingGoogleCallback) {
      DebugLog.i('GoogleAuth', 'callback-screen: branch=passive, awaiting completer');
      final result = await authProvider.googleCallbackFuture!.timeout(
        const Duration(seconds: 60),
        onTimeout: () => {'status': 'error', 'message': 'Timed out'},
      );
      if (!mounted) return;
      DebugLog.i('GoogleAuth', 'callback-screen: passive result=${result['status']}');
      _routeFromResult(result, fallbackToken: '');
      return;
    }

    // ── Cold-start / web path ─────────────────────────────────────────────────
    // App was killed and re-opened via deep link (mobile), or this is a web
    // callback after redirect.
    DebugLog.i('GoogleAuth', 'callback-screen: branch=cold-start kIsWeb=$kIsWeb');
    final supabase = Supabase.instance.client;

    Session? session = supabase.auth.currentSession;

    // On web with PKCE: explicitly call getSessionFromUrl() so we don't depend
    // on auto-detection inside initialize(), which fires signedIn BEFORE our
    // listener is attached (race condition on broadcast stream).
    if (session == null && kIsWeb) {
      final callbackUri = Uri.base;
      if (callbackUri.queryParameters.containsKey('code')) {
        DebugLog.i('GoogleAuth', 'callback-screen: web explicit getSessionFromUrl');
        try {
          final authResponse = await supabase.auth.getSessionFromUrl(callbackUri);
          session = authResponse.session;
          DebugLog.i('GoogleAuth', 'callback-screen: getSessionFromUrl ok');
        } catch (e) {
          // Code may already have been consumed by initialize()'s auto-detection.
          // Fall back: wait briefly for the signedIn event it would have emitted.
          DebugLog.i('GoogleAuth', 'callback-screen: getSessionFromUrl threw: $e');
          try {
            final event = await supabase.auth.onAuthStateChange
                .where((ev) =>
                    ev.event == AuthChangeEvent.signedIn ||
                    ev.event == AuthChangeEvent.tokenRefreshed)
                .first
                .timeout(const Duration(seconds: 8));
            session = event.session;
          } catch (_) {
            session = supabase.auth.currentSession;
          }
        }
      }
    }

    // Mobile cold-start: wait for supabase_flutter to exchange the deep-link code.
    if (session == null && !kIsWeb) {
      try {
        final event = await supabase.auth.onAuthStateChange
            .where((e) =>
                e.event == AuthChangeEvent.signedIn ||
                e.event == AuthChangeEvent.tokenRefreshed)
            .first
            .timeout(const Duration(seconds: 20));
        session = event.session;
      } catch (_) {
        session = supabase.auth.currentSession;
      }
    }

    if (!mounted) return;

    if (session == null) {
      DebugLog.i('GoogleAuth', 'callback-screen: no session, going to /login');
      context.go('/login');
      return;
    }

    DebugLog.i('GoogleAuth', 'callback-screen: session obtained, kIsWeb=$kIsWeb');

    // On web running on Android: pass tokens to the native app via deep link.
    // The native app will call handleWebRedirectToken and navigate to dashboard.
    // We also continue the web flow below as a fallback in case the app doesn't open.
    if (kIsWeb) {
      tryOpenMobileApp(session.accessToken, session.refreshToken ?? '');
      // Brief wait so the intent has time to fire before we also navigate on web.
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
    }

    final result = await authProvider.loginWithGoogleToken(session.accessToken);
    if (!mounted) return;
    DebugLog.i('GoogleAuth', 'callback-screen: route-decision ${result['status']}');
    _routeFromResult(result, fallbackToken: session.accessToken);
  }

  void _routeFromResult(Map<String, dynamic> result, {required String fallbackToken}) {
    switch (result['status']) {
      case 'logged_in':
        context.go('/dashboard');
        break;
      case 'needs_registration':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => GoogleRegisterScreen(
            supabaseToken: result['token'] ?? fallbackToken,
            googleEmail: result['email'] ?? '',
            googleName: result['name'] ?? '',
          ),
        ));
        break;
      default:
        context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
