import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'govt_analytics_screen.dart';

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleGovtLogin() async {
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String val = '';
        return AlertDialog(
          title: const Text('Government Access Only', style: TextStyle(color: Colors.red)),
          content: TextField(
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Enter Official Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            onChanged: (v) => val = v,
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, val),
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    
    if (password == 'admin123') {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const GovtAnalyticsScreen(),
        ),
      );
    } else if (password != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid password. Access denied.'), backgroundColor: Colors.red),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.red.shade50,
              Colors.white,
              Colors.red.shade100,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // App Quote
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(180),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.shade100, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.format_quote_rounded, color: Colors.red.shade400, size: 28),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '"Be a Life Saver for Someone, Donate Blood"',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 0.5,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.format_quote_rounded, color: Colors.red.shade400, size: 28),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  
                  // Pulsing Logo
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(35),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withAlpha(60),
                            blurRadius: 40,
                            spreadRadius: 8,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.bloodtype_rounded,
                        size: 110,
                        color: AppTheme.primaryRedDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  
                  // Title
                  Text(
                    'Blood Now',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryRedDark,
                          letterSpacing: 1.5,
                        ),
                  ),
                  const SizedBox(height: 16),
                  // Tagline
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Emergency blood assistance — connect donors, patients, and blood banks when minutes matter.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade800,
                            height: 1.5,
                            fontSize: 16,
                          ),
                    ),
                  ),
                  
                  const Spacer(flex: 4),
                  
                  // Get Started Button
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade400.withAlpha(100),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              const curve = Curves.easeOutCubic;
                              var tween = Tween(begin: const Offset(0.0, 0.1), end: Offset.zero).chain(CurveTween(curve: curve));
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: animation.drive(tween),
                                  child: child,
                                ),
                              );
                            },
                            transitionDuration: const Duration(milliseconds: 600),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: AppTheme.primaryRedDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Get Started',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 22),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Govt Portal Button
                  TextButton.icon(
                    onPressed: _handleGovtLogin,
                    icon: Icon(Icons.security_rounded, color: Colors.grey.shade600),
                    label: Text(
                      'Government Data Portal',
                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
