import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'help_screen.dart';

// ─── Notifications ────────────────────────────────────────
final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _notifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    ),
  );
  runApp(const PostnikApp());
}

// ─── Model ────────────────────────────────────────────────
class FastRecord {
  final DateTime startTime;
  final Duration elapsed;
  final Duration target;
  final bool completed;

  const FastRecord({
    required this.startTime,
    required this.elapsed,
    required this.target,
    required this.completed,
  });

  Map<String, dynamic> toJson() => {
        'startTime': startTime.millisecondsSinceEpoch,
        'elapsed': elapsed.inSeconds,
        'target': target.inSeconds,
        'completed': completed,
      };

  factory FastRecord.fromJson(Map<String, dynamic> json) => FastRecord(
        startTime:
            DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
        elapsed: Duration(seconds: json['elapsed'] as int),
        target: Duration(seconds: json['target'] as int),
        completed: json['completed'] as bool,
      );
}

// ─── History Service ──────────────────────────────────────
class HistoryService {
  static const _key = 'fast_history';

  static Future<List<FastRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => FastRecord.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  static Future<void> add(FastRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(jsonEncode(record.toJson()));
    await prefs.setStringList(_key, raw);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

// ─── App ──────────────────────────────────────────────────
class PostnikApp extends StatefulWidget {
  const PostnikApp({super.key});

  @override
  State<PostnikApp> createState() => _PostnikAppState();
}

class _PostnikAppState extends State<PostnikApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark') ?? true;
    if (mounted) {
      setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
    }
  }

  void _toggleTheme() async {
    final newIsDark = _themeMode != ThemeMode.dark;
    setState(() => _themeMode = newIsDark ? ThemeMode.dark : ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark', newIsDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Postnik',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF0EEFF),
        fontFamily: 'Poppins',
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        fontFamily: 'Poppins',
        useMaterial3: true,
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _showSplash
            ? SplashScreen(
                key: const ValueKey('splash'),
                onDone: () => setState(() => _showSplash = false),
              )
            : MainScreen(
                key: const ValueKey('main'),
                onToggleTheme: _toggleTheme,
              ),
      ),
    );
  }
}

// ─── Splash Screen ────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onDone,
  });
  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _iconFade;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.65, curve: Curves.elasticOut),
      ),
    );
    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.5, 0.9, curve: Curves.easeIn),
      ),
    );

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0F0F1A) : const Color(0xFFF0EEFF);
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _iconFade,
                child: ScaleTransition(
                  scale: _scale,
                  child: SvgPicture.asset(
                    'assets/images/icon_org-01.svg',
                    width: 120,
                    height: 120,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF6C63FF),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _textFade,
                child: const Text(
                  'POSTNIK',
                  style: TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Gradient Icon Helper ─────────────────────────────────
class _GradientIcon extends StatelessWidget {
  const _GradientIcon(this.icon, {super.key, this.size = 24});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFD4CFFF), Color(0xFF6C63FF), Color(0xFF3D35CC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

// ─── Main Screen (Bottom Nav) ─────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.onToggleTheme,
  });

  final VoidCallback onToggleTheme;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  int _historyRefreshKey = 0;

  void _onTabChanged(int tab) {
    setState(() => _tab = tab);
    if (tab == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _historyRefreshKey++);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final navBg = dark ? const Color(0xFF1A1A2E) : const Color(0xFFE8E0FF);
    final labelColor = dark ? Colors.white54 : Colors.black45;

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          FastingScreen(onToggleTheme: widget.onToggleTheme),
          HistoryScreen(refreshKey: _historyRefreshKey),
          SettingsScreen(onToggleTheme: widget.onToggleTheme),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: navBg,
        indicatorColor: const Color(0xFF6C63FF).withValues(alpha: 0.18),
        selectedIndex: _tab,
        onDestinationSelected: _onTabChanged,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined, color: labelColor),
            selectedIcon: _GradientIcon(Icons.local_fire_department),
            label: 'Postnik',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined, color: labelColor),
            selectedIcon: _GradientIcon(Icons.bar_chart),
            label: 'Zgodovina',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: labelColor),
            selectedIcon: _GradientIcon(Icons.settings),
            label: 'Nastavitve',
          ),
        ],
      ),
    );
  }
}

// ─── Fasting Screen ───────────────────────────────────────
class FastingScreen extends StatefulWidget {
  const FastingScreen({super.key, required this.onToggleTheme});
  final VoidCallback onToggleTheme;

  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen> {
  Duration _targetDuration = const Duration(hours: 16);
  Duration _elapsed = Duration.zero;
  Duration _pausedElapsed = Duration.zero;
  DateTime? _startTime;
  Timer? _timer;
  bool _isRunning = false;
  bool _timeSelected = false;
  bool _sessionSaved = false;

  static const _accent = Color(0xFF6C63FF);

  bool _dark = true;
  Color get _onBg => _dark ? Colors.white : Colors.black87;
  Color get _onBgSubtle => _dark ? Colors.white38 : Colors.black38;
  Color get _progressBg => _dark ? Colors.white10 : Colors.black12;
  Color get _presetUnselectedBg => _dark
      ? const Color.fromRGBO(255, 255, 255, 0.06)
      : const Color.fromRGBO(108, 99, 255, 0.07);
  Color get _presetUnselectedBorder => _dark ? Colors.white24 : Colors.black12;
  Color get _presetUnselectedText => _dark ? Colors.white54 : Colors.black54;
  Color get _outlineBorderColor => _dark ? Colors.white30 : Colors.black26;
  Color get _outlineTextColor => _dark ? Colors.white54 : Colors.black45;

  @override
  void initState() {
    super.initState();
    _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dark = Theme.of(context).brightness == Brightness.dark;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_enabled') ?? true)) return;
    final soundEnabled = prefs.getBool('sound_enabled') ?? true;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        soundEnabled ? 'postnik_done_sound' : 'postnik_done_silent',
        soundEnabled ? 'Konec posta (zvok)' : 'Konec posta (tiho)',
        channelDescription: 'Obvestilo ob zaključku posta',
        importance: soundEnabled ? Importance.high : Importance.low,
        priority: soundEnabled ? Priority.high : Priority.low,
        playSound: soundEnabled,
        enableVibration: soundEnabled,
        silent: !soundEnabled,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: soundEnabled,
      ),
    );
    await _notifications.show(
        1, 'Post je zaključen.', 'Čas je za zavesten obrok.', details);
  }

  void _showDoneDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor:
            _dark ? const Color(0xFF1A1A2E) : const Color(0xFFEDE9FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Post je zaključen.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: Text('Čas je za zavesten obrok.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _onBgSubtle)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zapri',
                style: TextStyle(color: Color(0xFF6C63FF))),
          ),
        ],
      ),
    );
  }

  Future<void> _startStop() async {
    if (_isRunning) {
      _timer?.cancel();
      setState(() {
        _pausedElapsed = _elapsed;
        _isRunning = false;
      });
      if (_elapsed > Duration.zero && !_sessionSaved) {
        await HistoryService.add(_buildRecord(completed: false));
        _sessionSaved = true;
      }
    } else {
      _startTime = DateTime.now();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
        setState(() =>
            _elapsed = _pausedElapsed + DateTime.now().difference(_startTime!));
        if (_elapsed >= _targetDuration) {
          _timer?.cancel();
          setState(() => _isRunning = false);
          await HistoryService.add(_buildRecord(completed: true));
          _sessionSaved = true;
          await _sendNotification();
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _showDoneDialog());
        }
      });
      setState(() => _isRunning = true);
    }
  }

  // Shrani in ponastavi (gumb Ponastavi)
  Future<void> _saveAndReset() async {
    if (_elapsed > Duration.zero && !_sessionSaved) {
      await HistoryService.add(_buildRecord(completed: false));
    }
    _timer?.cancel();
    setState(() {
      _elapsed = Duration.zero;
      _pausedElapsed = Duration.zero;
      _isRunning = false;
      _startTime = null;
      _timeSelected = false;
      _sessionSaved = false;
    });
  }

  // Tiho ponastavi (menjava preset/picker)
  void _resetSilently({Duration? newTarget, bool select = false}) {
    _timer?.cancel();
    setState(() {
      _elapsed = Duration.zero;
      _pausedElapsed = Duration.zero;
      _isRunning = false;
      _startTime = null;
      _sessionSaved = false;
      if (newTarget != null) _targetDuration = newTarget;
      if (select) _timeSelected = true;
    });
  }

  FastRecord _buildRecord({required bool completed}) {
    return FastRecord(
      startTime: _startTime ?? DateTime.now().subtract(_elapsed),
      elapsed: _elapsed,
      target: _targetDuration,
      completed: completed,
    );
  }

  double get _progress => _targetDuration.inSeconds == 0
      ? 0
      : (_elapsed.inSeconds / _targetDuration.inSeconds).clamp(0.0, 1.0);

  bool get _isDone => _elapsed >= _targetDuration;

  String _fmt(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _targetDuration - _elapsed;
    return Scaffold(
      backgroundColor: _dark ? const Color(0xFF0F0F1A) : const Color(0xFFF0EEFF),
      body: Column(
        children: [
          // Header – seže do samega vrha ekrana
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              color: _dark ? const Color(0xFF1A1A2E) : const Color(0xFFE8E0FF),
              border: Border(
                bottom: BorderSide(
                  color: _dark ? Colors.white12 : Colors.black12,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFD4CFFF), Color(0xFF6C63FF), Color(0xFF3D35CC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: SvgPicture.asset(
                    'assets/images/icon_org-01.svg',
                    width: 52,
                    height: 52,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFB8AEFF), Color(0xFF6C63FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'POST',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        TextSpan(
                          text: 'NIK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 3,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                  child: _GradientIcon(
                    _dark ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                    size: 20,
                    key: ValueKey(_dark),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onToggleTheme,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: 52,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      color: _dark
                          ? const Color(0xFF3A3560)
                          : const Color(0xFFD0CAFF),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: _dark
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFB8AEFF), Color(0xFF6C63FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          // Vsebina pod headerjem
          Expanded(
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availH = constraints.maxHeight;
                  final availW = constraints.maxWidth;
                  final timerSize = math.min(availH * 0.43, availW * 0.84).clamp(120.0, 270.0);
                  final sp1 = (availH * 0.025).clamp(4.0, 28.0);
                  final sp2 = (availH * 0.018).clamp(3.0, 22.0);
                  final sp3 = (availH * 0.012).clamp(2.0, 14.0);
                  final btnPadV = (availH * 0.020).clamp(8.0, 15.0);
                  final presetPadV = (availH * 0.026).clamp(7.0, 13.0);
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: availH),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTimer(remaining, timerSize),
                          SizedBox(height: sp1),
                          _buildPresets(presetPadV: presetPadV),
                          SizedBox(height: sp2),
                          _buildTimePickerButton(btnPadV: btnPadV),
                          SizedBox(height: sp3),
                          _buildButtons(btnPadV: btnPadV),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimer(Duration remaining, double size) {
    final cx = size / 2;
    final cy = size / 2;
    final stroke = (size * 0.076).clamp(16.0, 24.0);
    final r = size / 2 - stroke / 2;
    const startAngle = 3 * math.pi / 4;
    const sweepAngle = 3 * math.pi / 2;

    final elapsedH = _elapsed.inHours;
    final elapsedM = _elapsed.inMinutes % 60;
    final remH = remaining.inHours.clamp(0, 99);
    final remM = remaining.inMinutes % 60;

    final timeFontSz  = (size * 0.117).clamp(14.0, 36.0);
    final secFontSz   = (size * 0.045).clamp(7.0, 14.0);
    final subFontSz   = (size * 0.055).clamp(9.0, 18.0);
    final labelFontSz = (size * 0.082).clamp(8.0, 12.0);
    final iconSz      = (size * 0.193).clamp(28.0, 60.0);
    final doneFontSz  = (size * 0.062).clamp(11.0, 20.0);
    final innerSp     = (size * 0.018).clamp(1.0, 6.0);
    final divIndent   = (size * 0.14).clamp(16.0, 28.0);

    // Milestone markers na obroču (pike)
    final ms = (size * 0.059).clamp(11.0, 19.0);
    final arcColors = [
      const Color(0xFFE91E8C),
      const Color(0xFFAA44C8),
      const Color(0xFF9B59B6),
      const Color(0xFF6C63FF),
      const Color(0xFF29B6F6),
    ];
    final milestones = <Widget>[];
    for (int i = 0; i < 5; i++) {
      final f = i / 4.0;
      final angle = startAngle + f * sweepAngle;
      final mx = cx + r * math.cos(angle);
      final my = cy + r * math.sin(angle);
      final achieved = _progress >= f - 0.001;
      final dotColor = achieved ? arcColors[i] : (_dark ? const Color(0xFF2A2A40) : const Color(0xFFBBB8E8));
      milestones.add(Positioned(
        left: mx - ms / 2,
        top: my - ms / 2,
        child: Container(
          width: ms,
          height: ms,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            border: Border.all(
              color: achieved ? Colors.white.withValues(alpha: 0.6) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: achieved
                ? [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.7),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        ),
      ));
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Analogna številčnica
          CustomPaint(
            size: Size(size, size),
            painter: _DialPainter(isDark: _dark),
          ),
          // Lok z gradientom
          CustomPaint(
            size: Size(size, size),
            painter: _FastArcPainter(
              progress: _progress,
              trackColor: _progressBg,
              isDark: _dark,
            ),
          ),
          // Milestone ikone
          ...milestones,
          // Center vsebina
          Align(
            alignment: Alignment.center,
            child: _isDone
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/images/icon_org-01.svg',
                        width: iconSz,
                        height: iconSz,
                        colorFilter: const ColorFilter.mode(
                          Colors.greenAccent,
                          BlendMode.srcIn,
                        ),
                      ),
                      SizedBox(height: innerSp),
                      Text('Zaključeno!',
                          style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: doneFontSz,
                              fontWeight: FontWeight.w600)),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isRunning ? 'Preostalo' : 'Cilj posta',
                        style: TextStyle(
                            color: _onBgSubtle,
                            fontSize: labelFontSz,
                            letterSpacing: 0.5),
                      ),
                      SizedBox(height: innerSp * 0.5),
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFD4CFFF), Color(0xFF7B9CFF), Color(0xFF4A6FEF)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(bounds),
                        child: Text(
                          _isRunning
                              ? '${remH} ur ${remM} min'
                              : '${_targetDuration.inHours} ur',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: timeFontSz,
                              fontWeight: FontWeight.w700,
                              height: 1.1),
                        ),
                      ),
                      Visibility(
                        visible: _isRunning,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: Text(
                          '${remaining.inSeconds % 60}s',
                          style: TextStyle(
                              color: _onBgSubtle, fontSize: secFontSz, height: 1.1),
                        ),
                      ),
                      SizedBox(height: innerSp),
                      Divider(
                        color: _onBg.withValues(alpha: 0.15),
                        thickness: 0.6,
                        indent: divIndent,
                        endIndent: divIndent,
                      ),
                      SizedBox(height: innerSp * 0.4),
                      Text('V postu',
                          style:
                              TextStyle(color: _onBgSubtle, fontSize: labelFontSz)),
                      SizedBox(height: innerSp * 0.3),
                      Text(
                        _isRunning ? '${elapsedH} ur ${elapsedM} min' : '─',
                        style: TextStyle(
                            color: _onBg.withValues(alpha: 0.8),
                            fontSize: subFontSz,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresets({double presetPadV = 13}) {
    final items = [8, 16, 24];
    final buttons = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      final h = items[i];
      final selected = _targetDuration == Duration(hours: h) && _timeSelected;
      buttons.add(Expanded(
        child: GestureDetector(
          onTap: () => _resetSilently(newTarget: Duration(hours: h), select: true),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.symmetric(vertical: presetPadV),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF7B9CFF) : _presetUnselectedBg,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: selected ? const Color(0xFF7B9CFF) : _presetUnselectedBorder,
              ),
              boxShadow: null,
            ),
            child: selected
                ? Text('${h} ur',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF0F0F2E),
                        fontWeight: FontWeight.w800,
                        fontSize: 16))
                : ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFD4CFFF), Color(0xFF6C63FF), Color(0xFF3D35CC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$h',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const TextSpan(
                            text: ' ur',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ));
      if (i < items.length - 1) buttons.add(const SizedBox(width: 12));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFD4CFFF), Color(0xFF6C63FF), Color(0xFF3D35CC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'Izberi čas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          Row(children: buttons),
        ],
      ),
    );
  }

  void _showTimePicker() {
    int tempDays = _targetDuration.inDays;
    int tempHours = _targetDuration.inHours % 24;
    int tempMinutes = _targetDuration.inMinutes % 60;

    final textColor = _dark ? Colors.white : Colors.black87;
    final labelColor = _dark ? Colors.white54 : Colors.black45;
    final bg = _dark ? const Color(0xFF1A1A2E) : const Color(0xFFEDE9FF);

    Widget pickerCol(
      int initial,
      int count,
      String label,
      void Function(int) onChanged,
    ) {
      return Expanded(
        child: Column(
          children: [
            Expanded(
              child: CupertinoPicker(
                scrollController:
                    FixedExtentScrollController(initialItem: initial),
                itemExtent: 44,
                looping: true,
                selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
                  background: Color(0x1A7B9CFF),
                ),
                onSelectedItemChanged: onChanged,
                children: List.generate(
                  count,
                  (i) => Center(
                    child: Text(
                      i.toString().padLeft(2, '0'),
                      style: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w400),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: labelColor, fontSize: 12)),
            const SizedBox(height: 10),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _dark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Po meri',
                style: TextStyle(color: labelColor, fontSize: 16)),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  pickerCol(tempDays, 8, 'dni', (i) => tempDays = i),
                  pickerCol(tempHours, 24, 'ur', (i) => tempHours = i),
                  pickerCol(tempMinutes, 60, 'min', (i) => tempMinutes = i),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: ElevatedButton(
                onPressed: () {
                  final total = Duration(
                    days: tempDays,
                    hours: tempHours,
                    minutes: tempMinutes,
                  );
                  _resetSilently(
                    newTarget: total == Duration.zero
                        ? const Duration(minutes: 30)
                        : total,
                    select: true,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B9CFF),
                  foregroundColor: const Color(0xFF0F0F2E),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                  elevation: 0,
                ),
                child: const Text('Potrdi',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glossyButton({
    required String label,
    required VoidCallback? onTap,
    IconData? icon,
    bool outline = false,
    double vertPad = 15,
    bool iconOnly = false,
  }) {
    const btnColor = Color(0xFF7B9CFF);
    const textDark = Color(0xFF0F0F2E);
    final disabled = onTap == null;
    const gradient = LinearGradient(
      colors: [Color(0xFFB8AEFF), Color(0xFF7B9CFF), Color(0xFF4A6FEF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.35 : 1.0,
        child: Container(
          padding: iconOnly
              ? EdgeInsets.all(vertPad)
              : EdgeInsets.symmetric(horizontal: 32, vertical: vertPad),
          decoration: BoxDecoration(
            gradient: outline ? null : gradient,
            color: outline ? Colors.transparent : null,
            border: Border.all(
              color: btnColor,
              width: outline ? 1.5 : 0,
            ),
            borderRadius: BorderRadius.circular(50),
            boxShadow: null,
          ),
          child: iconOnly
              ? Icon(icon, size: 22, color: outline ? btnColor : textDark)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 22, color: outline ? btnColor : textDark),
                      const SizedBox(width: 8),
                    ],
                    Text(label,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: outline ? btnColor : textDark,
                            letterSpacing: 0.3)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTimePickerButton({double btnPadV = 15}) {
    return _glossyButton(
      label: 'Nastavi čas',
      icon: Icons.schedule,
      onTap: _isRunning ? null : _showTimePicker,
      outline: true,
      vertPad: btnPadV,
    );
  }

  Widget _buildButtons({double btnPadV = 15}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_elapsed > Duration.zero && !_isRunning) ...[
          _glossyButton(
              label: 'Ponastavi',
              icon: Icons.refresh_rounded,
              onTap: _saveAndReset,
              outline: true,
              vertPad: btnPadV,
              iconOnly: true),
          const SizedBox(width: 12),
        ],
        _glossyButton(
          label: _isDone ? 'Znova' : _isRunning ? 'Ustavi' : 'Začni',
          icon: _isDone
              ? Icons.play_arrow_rounded
              : _isRunning
                  ? Icons.stop_rounded
                  : Icons.play_arrow_rounded,
          onTap: _isDone
              ? () {
                  setState(() => _timeSelected = false);
                  _resetSilently();
                }
              : _startStop,
          vertPad: btnPadV,
        ),
      ],
    );
  }
}

// ─── History Screen ───────────────────────────────────────
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.refreshKey});
  final int refreshKey;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<FastRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await HistoryService.load();
    if (mounted) setState(() { _records = records; _loading = false; });
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).brightness == Brightness.dark
            ? const Color(0xFF1A1A2E)
            : const Color(0xFFEDE9FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Izbriši zgodovino?',
            textAlign: TextAlign.center),
        content: const Text('Vsi zapisi bodo trajno izbrisani.',
            textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Prekliči',
                  style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Izbriši',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      await HistoryService.clear();
      _load();
    }
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m} min';
    if (m == 0) return '${h} ur';
    return '${h} ur ${m} min';
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'Danes, $time';
    if (diff == 1) return 'Včeraj, $time';
    return '${dt.day}.${dt.month}.${dt.year}, $time';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0F0F1A) : const Color(0xFFF0EEFF);
    final cardBg = dark ? const Color(0xFF1A1A2E) : const Color(0xFFEDE9FF);
    final textColor = dark ? Colors.white : Colors.black87;
    final subtleColor = dark ? Colors.white38 : Colors.black38;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('Zgodovina',
            style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 20,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5)),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: textColor.withValues(alpha: 0.5)),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history,
                          size: 64, color: subtleColor),
                      const SizedBox(height: 16),
                      Text('Še ni zapisov',
                          style: TextStyle(color: subtleColor, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _records.length,
                    itemBuilder: (_, i) {
                      final r = _records[i];
                      final pct = (r.elapsed.inSeconds /
                              math.max(1, r.target.inSeconds))
                          .clamp(0.0, 1.0);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: CircularProgressIndicator(
                                    value: pct,
                                    strokeWidth: 4,
                                    backgroundColor:
                                        dark ? Colors.white12 : Colors.black12,
                                    color: r.completed
                                        ? Colors.greenAccent
                                        : const Color(0xFF6C63FF),
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                                Icon(
                                  r.completed
                                      ? Icons.check
                                      : Icons.pause,
                                  size: 20,
                                  color: r.completed
                                      ? Colors.greenAccent
                                      : subtleColor,
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.completed
                                        ? 'Zaključen post'
                                        : 'Nedokončan post',
                                    style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_fmtDuration(r.elapsed)} / ${_fmtDuration(r.target)}',
                                    style: TextStyle(
                                        color: subtleColor, fontSize: 13),
                                  ),
                                  Text(
                                    _fmtDate(r.startTime),
                                    style: TextStyle(
                                        color: subtleColor, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ─── Settings Screen ──────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.onToggleTheme});
  final VoidCallback onToggleTheme;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      });
    }
  }

  Future<void> _setNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
  }

  Future<void> _setSound(bool value) async {
    setState(() => _soundEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', value);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0F0F1A) : const Color(0xFFF0EEFF);
    final cardBg = dark ? const Color(0xFF1A1A2E) : const Color(0xFFEDE9FF);
    final textColor = dark ? Colors.white : Colors.black87;
    final subtleColor = dark ? Colors.white54 : Colors.black54;

    Widget tile({
      required IconData icon,
      required String title,
      String? subtitle,
      required Widget trailing,
      VoidCallback? onTap,
      double tilePadV = 14,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: tilePadV),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6C63FF), size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 15)),
                  if (subtitle != null)
                    Text(subtitle,
                        style:
                            TextStyle(color: subtleColor, fontSize: 12)),
                ],
              ),
            ),
            trailing,
          ],
        ),
       ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('Nastavitve',
            style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 20,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availH = constraints.maxHeight;
          final tilePadV = (availH * 0.018).clamp(8.0, 14.0);
          final sectionGap = (availH * 0.020).clamp(8.0, 16.0);
          final labelGap = (availH * 0.010).clamp(4.0, 8.0);
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Videz',
                        style: TextStyle(
                            color: subtleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1)),
                    SizedBox(height: labelGap),
                    tile(
                      icon: dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      title: 'Tema',
                      subtitle: dark ? 'Temna tema' : 'Svetla tema',
                      tilePadV: tilePadV,
                      trailing: Switch(
                        value: dark,
                        onChanged: (_) => widget.onToggleTheme(),
                        activeColor: const Color(0xFF6C63FF),
                      ),
                    ),
                    SizedBox(height: sectionGap),
                    Text('Obvestila',
                        style: TextStyle(
                            color: subtleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1)),
                    SizedBox(height: labelGap),
                    tile(
                      icon: Icons.notifications_outlined,
                      title: 'Obvestila na zaslonu',
                      subtitle: _notificationsEnabled ? 'Vklopljeno' : 'Izklopljeno',
                      tilePadV: tilePadV,
                      trailing: Switch(
                        value: _notificationsEnabled,
                        onChanged: _setNotifications,
                        activeColor: const Color(0xFF6C63FF),
                      ),
                    ),
                    tile(
                      icon: Icons.volume_up_outlined,
                      title: 'Zvočno obvestilo',
                      subtitle: _soundEnabled ? 'Vklopljeno' : 'Izklopljeno',
                      tilePadV: tilePadV,
                      trailing: Switch(
                        value: _soundEnabled,
                        onChanged: _notificationsEnabled ? _setSound : null,
                        activeColor: const Color(0xFF6C63FF),
                      ),
                    ),
                    SizedBox(height: sectionGap),
                    Text('Pomoč',
                        style: TextStyle(
                            color: subtleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1)),
                    SizedBox(height: labelGap),
                    tile(
                      icon: Icons.help_outline_rounded,
                      title: 'Navodila za uporabo',
                      subtitle: 'Razlaga funkcij in PDF izvoz',
                      tilePadV: tilePadV,
                      trailing: Icon(Icons.chevron_right, color: subtleColor),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HelpScreen(),
                        ),
                      ),
                    ),
                    SizedBox(height: sectionGap * 1.5),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'developed by\n',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Poppins',
                            letterSpacing: 1,
                          ),
                        ),
                        WidgetSpan(
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFD4CFFF), Color(0xFF6C63FF), Color(0xFF3D35CC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: const Text(
                              'PROJEKTNI INŽENIRJI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Custom arc painter ───────────────────────────────────
class _FastArcPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final bool isDark;

  const _FastArcPainter({
    required this.progress,
    required this.trackColor,
    required this.isDark,
  });

  static const double _start = 3 * math.pi / 4;
  static const double _sweep = 3 * math.pi / 2;
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final stroke = (size.width * 0.076).clamp(16.0, 24.0);
    final r = math.min(cx, cy) - stroke / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Background track
    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = trackColor,
    );

    if (progress <= 0) return;

    // Progress arc z gradientom
    // Lok gre od 135° do 405° (preseka 360°/0° mejo).
    // Uporabimo full-circle gradient (0–2π) z barvami pozicioniranimi po kotih:
    //   135° (stop 0.375) = roza (začetek loka)
    //   229° (stop 0.638) = vijolična
    //   324° (stop 0.900) = zelena
    //    45° (stop 0.125) = svetlo zelena (konec loka)
    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: [
          Color(0xFF00E676), // 0°   – svetlo zelena
          Color(0xFF00E676), // 45°  – konec loka
          Color(0xFFE91E8C), // 135° – začetek loka (roza)
          Color(0xFFB44FD4), // 229° – vijolična
          Color(0xFF4CAF50), // 324° – zelena
          Color(0xFF00E676), // 360° – svetlo zelena
        ],
        stops: [0.0, 0.125, 0.375, 0.638, 0.900, 1.0],
      ).createShader(rect);

    canvas.drawArc(rect, _start, _sweep * progress, false, gradientPaint);
  }

  @override
  bool shouldRepaint(_FastArcPainter old) =>
      old.progress != progress || old.trackColor != trackColor;
}

// ─── Dial Painter ─────────────────────────────────────────
class _DialPainter extends CustomPainter {
  final bool isDark;
  const _DialPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final tickR = size.width * 0.586;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: tickR);
    final gradientShader = const SweepGradient(
      colors: [
        Color(0x66E91E8C),
        Color(0x669B59B6),
        Color(0x666C63FF),
        Color(0x6629B6F6),
        Color(0x66E91E8C),
      ],
      stops: [0.0, 0.25, 0.55, 0.85, 1.0],
    ).createShader(rect);

    // Vrzel: od π/4 do 3π/4 (spodaj)
    const gapStart = math.pi / 4;
    const gapEnd = 3 * math.pi / 4;

    for (int i = 0; i < 60; i++) {
      final angle = i * 2 * math.pi / 60 - math.pi / 2;
      // Normaliziramo na [0, 2π]
      final norm = (angle % (2 * math.pi) + 2 * math.pi) % (2 * math.pi);
      // Preskoči tike v vrzeli
      if (norm >= gapStart && norm <= gapEnd) continue;

      final isMajor = i % 5 == 0;
      final tickLen = isMajor ? size.width * 0.048 : size.width * 0.024;
      final strokeW = isMajor ? 2.2 : 1.1;

      final outerX = cx + tickR * math.cos(angle);
      final outerY = cy + tickR * math.sin(angle);
      final innerX = cx + (tickR - tickLen) * math.cos(angle);
      final innerY = cy + (tickR - tickLen) * math.sin(angle);

      final paint = Paint()
        ..shader = gradientShader
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(innerX, innerY), Offset(outerX, outerY), paint);
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.isDark != isDark;
}
