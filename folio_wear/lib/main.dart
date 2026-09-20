import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:wear/wear.dart';
import 'providers/wear_data_provider.dart';
import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/connecting_screen.dart';
import 'screens/pairing_screen.dart';
import 'screens/wear_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('hu', null);
  runApp(
    ChangeNotifierProvider(
      create: (_) => WearDataProvider(),
      child: const FolioWearApp(),
    ),
  );
}

class FolioWearApp extends StatelessWidget {
  const FolioWearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eFolio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF29B6F6),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const WatchShape(builder: _buildForShape),
    );
  }
}

Widget _buildForShape(BuildContext context, WearShape shape, Widget? child) =>
    const _WearRoot();

// ─────────────────────────────────────────────────────────────────────────────

class _WearRoot extends StatelessWidget {
  const _WearRoot();

  @override
  Widget build(BuildContext context) {
    return Consumer<WearDataProvider>(builder: (context, data, _) {
      final hasData =
          data.lessons.isNotEmpty || data.notifications.isNotEmpty;
      if (!hasData && data.lastSync == null) return const ConnectingScreen();
      if (!data.isPaired) return const PairingScreen();
      return const _WearMainScreen();
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _WearMainScreen extends StatefulWidget {
  const _WearMainScreen();

  @override
  State<_WearMainScreen> createState() => _WearMainScreenState();
}

class _WearMainScreenState extends State<_WearMainScreen> {
  final _pageController = PageController();
  final _scrollCtrls = [
    ScrollController(),
    ScrollController(),
    ScrollController(),
  ];
  int _currentPage = 0;

  static const _pages = 3;
  static const _crownThreshold = 3.0;
  static const _switchCooldown = Duration(milliseconds: 700);

  double _crownOverscroll = 0.0;
  DateTime? _lastSwitch;
  bool _isSwitching = false; // megakadályozza a dupla váltást animáció alatt

  ScrollController get _activeCtrl => _scrollCtrls[_currentPage];

  @override
  void initState() {
    super.initState();
    WearDataProvider.onRotaryInput = _handleRotary;
  }

  @override
  void dispose() {
    WearDataProvider.onRotaryInput = null;
    _pageController.dispose();
    for (final c in _scrollCtrls) c.dispose();
    super.dispose();
  }

  // ── Cooldown guard ─────────────────────────────────────────────────────────

  bool _canSwitch() {
    if (_isSwitching) return false;
    final now = DateTime.now();
    if (_lastSwitch != null &&
        now.difference(_lastSwitch!) < _switchCooldown) return false;
    _lastSwitch = now;
    return true;
  }

  // ── Navigáció ──────────────────────────────────────────────────────────────

  /// dir: +1 = le (előre), -1 = fel (vissza)
  void _switchPage(int dir) {
    final next = _currentPage + dir;
    if (next < 0 || next >= _pages) return;

    HapticFeedback.mediumImpact();
    _isSwitching = true;

    // ── Scroll pozíció előkészítése ──────────────────────────────────────────
    // Ha visszafele megyünk, a céloldal ALULról kezd.
    // Ha előre, FELÜLről. Ha már van kliense, azonnal ugrik (nincs flash).
    final targetCtrl = _scrollCtrls[next];
    if (targetCtrl.hasClients) {
      targetCtrl.jumpTo(
        dir < 0 ? targetCtrl.position.maxScrollExtent : 0.0,
      );
    }

    _pageController
        .animateToPage(
          next,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCirc, // HyperOS-szerű gyors snap
        )
        .then((_) {
          if (!mounted) return;
          _isSwitching = false;

          // Animáció befejezése után utólagos pozíció-igazítás
          // (ha az oldal nem volt még renderelve, ez állítja be)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final ctrl = _scrollCtrls[next];
            if (!ctrl.hasClients) return;
            final target =
                dir < 0 ? ctrl.position.maxScrollExtent : 0.0;
            if ((ctrl.position.pixels - target).abs() > 1.0) {
              ctrl.jumpTo(target);
            }
          });
        });
  }

  // ── Koronás görgetés ───────────────────────────────────────────────────────

  void _handleRotary(double delta) {
    final ctrl = _activeCtrl;
    if (!ctrl.hasClients) {
      if (_canSwitch()) _switchPage(delta > 0 ? 1 : -1);
      return;
    }
    final pos = ctrl.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 0.5;
    final atTop = pos.pixels <= 0.5;

    if (delta > 0 && atBottom) {
      _crownOverscroll += delta;
      if (_crownOverscroll >= _crownThreshold && _canSwitch()) {
        _crownOverscroll = 0;
        _switchPage(1);
      }
      return;
    } else if (delta < 0 && atTop) {
      _crownOverscroll += delta;
      if (_crownOverscroll <= -_crownThreshold && _canSwitch()) {
        _crownOverscroll = 0;
        _switchPage(-1);
      }
      return;
    }
    _crownOverscroll = 0;
    ctrl.jumpTo(
        (pos.pixels + delta * 120.0).clamp(0.0, pos.maxScrollExtent));
  }

  // ── Touch overscroll → lapváltás ──────────────────────────────────────────

  bool _onScrollNotification(ScrollNotification n) {
    // depth > 0: belső CustomScrollView-tól jön (nem a PageView-tól)
    if (n is OverscrollNotification && n.depth > 0) {
      if (n.overscroll > 0 && _canSwitch()) _switchPage(1);
      if (n.overscroll < 0 && _canSwitch()) _switchPage(-1);
    }
    return false;
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<WearDataProvider>(builder: (context, data, _) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          // Oldalak — NeverScrollableScrollPhysics: csak programmatikusan vált,
          // így a belső listák touch-scrollja nem ütközik a PageView-val
          NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: PageView(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (p) => setState(() => _currentPage = p),
              children: [
                HomeScreen(scrollController: _scrollCtrls[0]),
                NotificationsScreen(scrollController: _scrollCtrls[1]),
                WearSettingsScreen(scrollController: _scrollCtrls[2]),
              ],
            ),
          ),

          // Kapcsolat jelző — jobb felső sarok
          Positioned(
            top: 8.0,
            right: 26.0,
            child: _ConnectionDot(connected: data.connected),
          ),

          // Lapozó pontok — alul középen
          Positioned(
            bottom: 9.0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _pages; i++) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: i == _currentPage ? 16.0 : 5.0,
                    height: 5.0,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? cs.primary
                          : Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(3.0),
                    ),
                  ),
                  if (i < _pages - 1) const SizedBox(width: 4.0),
                ],
              ],
            ),
          ),
        ]),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionDot extends StatelessWidget {
  final bool connected;
  const _ConnectionDot({required this.connected});

  @override
  Widget build(BuildContext context) {
    final color =
        connected ? const Color(0xFF69F0AE) : const Color(0xFFFF5252);
    return Container(
      width: 7.0,
      height: 7.0,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 5.0,
              spreadRadius: 1.0),
        ],
      ),
    );
  }
}
