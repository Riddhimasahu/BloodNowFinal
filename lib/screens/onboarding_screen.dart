import 'package:flutter/material.dart';

import '../models/onboarding_feature.dart';
import 'registration_entry_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<OnboardingFeature> _features = [
    OnboardingFeature(
      title: 'Find blood faster',
      body:
          'Requesters can locate nearby banks, see availability, and get directions in critical moments.',
      icon: Icons.emergency_rounded,
    ),
    OnboardingFeature(
      title: 'Donate with purpose',
      body:
          'Donors complete eligibility checks, book slots at partner banks, and earn credits for future needs.',
      icon: Icons.volunteer_activism_rounded,
    ),
    OnboardingFeature(
      title: 'Banks stay in sync',
      body:
          'Blood banks manage inventory, slots, and requests so the platform reflects real-time supply.',
      icon: Icons.local_hospital_rounded,
    ),
  ];

  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToRegistration() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const RegistrationEntryScreen(),
      ),
    );
  }

  void _next() {
    if (_index < _features.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _goToRegistration();
    }
  }

  void _previous() {
    if (_index > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFirst = _index == 0;
    final isLast = _index == _features.length - 1;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('How it works', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _goToRegistration,
            child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.red.shade50],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _features.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double value = 1.0;
                        if (_pageController.position.haveDimensions) {
                          value = _pageController.page! - i;
                          value = (1 - (value.abs() * 0.25)).clamp(0.0, 1.0);
                        } else {
                          value = (i == _index) ? 1.0 : 0.75;
                        }
                        return Transform.scale(
                          scale: Curves.easeOutCubic.transform(value),
                          child: Opacity(
                            opacity: value.clamp(0.5, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
                        child: _FeatureCard(feature: _features[i], isActive: i == _index),
                      ),
                    );
                  },
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _features.length,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? scheme.primary
                          : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isFirst ? null : _previous,
                      child: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(isLast ? 'Continue' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature, required this.isActive});

  final OnboardingFeature feature;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive 
             ? [Colors.white, Colors.red.shade50]
             : [Colors.grey.shade50, Colors.grey.shade100],
        ),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: isActive ? Colors.red.shade200 : Colors.grey.shade300, 
          width: isActive ? 2 : 1
        ),
        boxShadow: [
          BoxShadow(
            color: isActive ? Colors.red.withAlpha(40) : Colors.black.withAlpha(10),
            blurRadius: isActive ? 30 : 15,
            spreadRadius: isActive ? 5 : 0,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with a glowing circle
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.red.shade100 : Colors.grey.shade200,
              boxShadow: [
                 if (isActive)
                   BoxShadow(
                     color: Colors.red.shade300.withAlpha(80),
                     blurRadius: 30,
                     spreadRadius: 10,
                   )
              ]
            ),
            child: Icon(
              feature.icon,
              size: 80,
              color: isActive ? Colors.red.shade700 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            feature.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isActive ? Colors.red.shade900 : Colors.grey.shade800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            feature.body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade700,
              height: 1.6,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
