import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/growmate_theme.dart';

/// Premium animated splash screen — Swiggy / Zomato-level polish.
/// Orchestrates logo animation, particle effects, status text cycle,
/// and a progress bar while the backend warms up in the background.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ─── Master Controllers ───────────────────────────────────────────────────
  late AnimationController _logoCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _progressCtrl;
  late AnimationController _fadeOutCtrl;
  late AnimationController _textCycleCtrl;
  late AnimationController _leafCtrl;

  // ─── Animations ───────────────────────────────────────────────────────────
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;
  late Animation<double> _progressValue;
  late Animation<double> _fadeOutOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _logoSlide;

  // ─── Status text carousel ─────────────────────────────────────────────────
  int _currentTextIndex = 0;
  final List<_StatusLine> _statusLines = const [
    _StatusLine(Icons.cloud_sync_outlined, 'Waking up the farm brain…'),
    _StatusLine(Icons.satellite_alt_outlined, 'Fetching weather data…'),
    _StatusLine(Icons.eco_outlined, 'Preparing crop intelligence…'),
    _StatusLine(Icons.water_drop_outlined, 'Analyzing soil & rainfall…'),
    _StatusLine(Icons.auto_graph_outlined, 'Loading market prices…'),
    _StatusLine(Icons.tips_and_updates_outlined, 'Building your advisory…'),
  ];

  bool _serverReady = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A3D0A),
    ));
    _initAnimations();
    _warmUpAndNavigate();
  }

  void _initAnimations() {
    // 1. Logo entrance — scale + opacity + slide
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic),
    );

    // 2. Pulse ring behind logo
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _pulseScale = Tween<double>(begin: 0.8, end: 1.6).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );

    // 3. Particle background (floating leaves / dots)
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // 4. Progress bar
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _progressValue = Tween<double>(begin: 0.0, end: 0.85).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut),
    );

    // 5. Fade out
    _fadeOutCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeOutOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutCtrl, curve: Curves.easeInCubic),
    );

    // 6. Text cycle
    _textCycleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCycleCtrl, curve: Curves.easeInOut),
    );

    // 7. Spinning leaf accent
    _leafCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Start sequence
    _logoCtrl.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _progressCtrl.forward();
    });
    _textCycleCtrl.forward();
    _startTextCycle();
  }

  void _startTextCycle() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || _navigating) return;
      _textCycleCtrl.reverse().then((_) {
        if (!mounted || _navigating) return;
        setState(() {
          _currentTextIndex =
              (_currentTextIndex + 1) % _statusLines.length;
        });
        _textCycleCtrl.forward().then((_) => _startTextCycle());
      });
    });
  }

  Future<void> _warmUpAndNavigate() async {
    // Start backend warmup + token check concurrently
    final stopwatch = Stopwatch()..start();

    final results = await Future.wait([
      _warmUpServer(),
      _checkAuth(),
      // Guarantee minimum 2.5s splash for a snappy but polished animation experience
      Future.delayed(const Duration(milliseconds: 2500)),
    ]);

    stopwatch.stop();
    _serverReady = true;

    final hasToken = results[1] as bool;

    // Complete the progress bar to 100%
    if (mounted) {
      _progressCtrl.stop();
      _progressCtrl.duration = const Duration(milliseconds: 400);
      _progressValue = Tween<double>(
        begin: _progressCtrl.value * 0.85,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut));
      _progressCtrl.forward(from: 0);
    }

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    _navigating = true;

    // Fade out the splash
    await _fadeOutCtrl.forward();

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(hasToken ? '/home' : '/login');
  }

  Future<void> _warmUpServer() async {
    try {
      // 1. Fire-and-forget raw GET requests to all backend microservices
      // to forcefully wake them up from Render cold starts instantly
      // without waiting for them to finish.
      final urls = [
        'https://growmate-orchestrator.onrender.com/health', // main orchestrator
        'https://crop-advisory-api.onrender.com/docs',
        'https://crop-discovery-api.onrender.com/docs',
        'https://soil-advisory-api.onrender.com/docs',
        'https://rainfall-advisory-api-1.onrender.com/docs',
        'https://crop-calendar-api-tq0m.onrender.com/docs',
      ];
      
      for (final url in urls) {
        // We use catchError so individual failures don't crash the warmup
        http.get(Uri.parse(url)).catchError((_) => http.Response('', 500));
      }

      // 2. Warm up Orchestrator via our built-in API Service
      // We await this one so the app knows the orchestrator is ready
      await ApiService.instance.getHealth();
    } catch (_) {
      // Server might be cold — that's fine, we still proceed
    }
  }

  Future<bool> _checkAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token') != null;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    _progressCtrl.dispose();
    _fadeOutCtrl.dispose();
    _textCycleCtrl.dispose();
    _leafCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _fadeOutOpacity,
        builder: (context, child) => Opacity(
          opacity: _fadeOutOpacity.value,
          child: child,
        ),
        child: Container(
          width: size.width,
          height: size.height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0A3D0A), // deep forest
                Color(0xFF1B5E20), // dark green
                Color(0xFF2E7D32), // green
                Color(0xFF0D4A0D), // deep base
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // ── Floating particles ────────────────────────────────────
              _FloatingParticles(animation: _particleCtrl),

              // ── Radial glow behind logo ───────────────────────────────
              Center(
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Transform.scale(
                    scale: _pulseScale.value,
                    child: Opacity(
                      opacity: _pulseOpacity.value,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              GrowMateTheme.primaryGreen.withValues(alpha: 0.3),
                              GrowMateTheme.primaryGreen.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Main content column ───────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // ── Logo entrance ─────────────────────────────────────
                    AnimatedBuilder(
                      animation: _logoCtrl,
                      builder: (_, __) => SlideTransition(
                        position: _logoSlide,
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: _buildLogoSection(),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // ── Spinning leaf accent ──────────────────────────────
                    AnimatedBuilder(
                      animation: _leafCtrl,
                      builder: (_, __) => Transform.rotate(
                        angle: _leafCtrl.value * 2 * pi,
                        child: Opacity(
                          opacity: 0.15,
                          child: Icon(
                            Icons.eco_rounded,
                            size: 28,
                            color: GrowMateTheme.sunYellow,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // ── Status text carousel ──────────────────────────────
                    AnimatedBuilder(
                      animation: _textOpacity,
                      builder: (_, __) => Opacity(
                        opacity: _textOpacity.value,
                        child: _buildStatusText(),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Progress bar ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 60),
                      child: AnimatedBuilder(
                        animation: _progressCtrl,
                        builder: (_, __) => _buildProgressBar(),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── Bottom brand tagline ──────────────────────────────
                    _buildBottomTag(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glowing logo container
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: GrowMateTheme.primaryGreen.withValues(alpha: 0.4),
                blurRadius: 40,
                spreadRadius: 8,
              ),
              BoxShadow(
                color: GrowMateTheme.sunYellow.withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Image.asset(
                'assets/icons/logo.png',
                width: 72,
                height: 72,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.eco_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // App name
        const Text(
          'GrowMate',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        // Tagline shimmer
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFA5D6A7),
              Color(0xFFFFF176),
              Color(0xFFA5D6A7),
            ],
          ).createShader(bounds),
          child: const Text(
            'Intelligent Farming Platform',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusText() {
    final line = _statusLines[_currentTextIndex];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(line.icon, size: 16, color: Colors.white54),
        const SizedBox(width: 8),
        Text(
          line.text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Colors.white54,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 4,
            child: Stack(
              children: [
                // Track
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                // Fill
                FractionallySizedBox(
                  widthFactor: _progressValue.value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF66BB6A),
                          Color(0xFFFBC02D),
                          Color(0xFFFF9800),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: GrowMateTheme.sunYellow.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${(_progressValue.value * 100).toInt()}%',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomTag() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _serverReady
                    ? GrowMateTheme.successGreen
                    : GrowMateTheme.sunYellow,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _serverReady ? 'Connected' : 'Connecting to server…',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Powered by AI-driven agtech',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }
}

// ─── Status line data ────────────────────────────────────────────────────────
class _StatusLine {
  final IconData icon;
  final String text;
  const _StatusLine(this.icon, this.text);
}

// ─── Floating Particles ──────────────────────────────────────────────────────
class _FloatingParticles extends StatelessWidget {
  final AnimationController animation;
  const _FloatingParticles({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _ParticlePainter(animation.value),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42); // fixed seed for consistent positions
    final paint = Paint();

    // Floating dots / circles
    for (int i = 0; i < 25; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.3 + random.nextDouble() * 0.7;
      final phase = random.nextDouble() * 2 * pi;

      final drift = sin((progress * 2 * pi * speed) + phase) * 30;
      final yDrift = cos((progress * 2 * pi * speed * 0.7) + phase) * 20;

      final x = baseX + drift;
      final y = baseY + yDrift;

      final radius = 1.5 + random.nextDouble() * 3;
      final opacity = 0.03 + random.nextDouble() * 0.08;

      // Alternate between green and yellow particles
      final isGreen = i % 3 != 0;
      paint.color = isGreen
          ? GrowMateTheme.primaryGreen.withValues(alpha: opacity)
          : GrowMateTheme.sunYellow.withValues(alpha: opacity);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Larger subtle glowing orbs
    for (int i = 0; i < 5; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final phase = random.nextDouble() * 2 * pi;
      final drift = sin((progress * 2 * pi * 0.3) + phase) * 50;

      paint.color = GrowMateTheme.primaryGreen.withValues(alpha: 0.02);
      canvas.drawCircle(
        Offset(baseX + drift, baseY),
        20 + random.nextDouble() * 30,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
