import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_api.dart';
import '../services/session_store.dart';
import '../widgets/google_sign_in_button.dart';
import 'google_registration_screen.dart';
import 'login_screen.dart';
import 'user_home_screen.dart';

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  bool _submitting = false;

  final _auth = AuthApi();
  final _session = SessionStore();

  final _googleSignIn = GoogleSignIn(
    clientId:
        '781106930638-kba29cmj9q7epkqbsmrs63a5o07h2ecu.apps.googleusercontent.com',
  );
  late final StreamSubscription<GoogleSignInAccount?> _googleSignInSub;

  @override
  void initState() {
    super.initState();
    _googleSignInSub =
        _googleSignIn.onCurrentUserChanged.listen((account) {
      if (account != null) _handleGoogleSignIn(account);
    });
  }

  @override
  void dispose() {
    _googleSignInSub.cancel();
    _auth.close();
    super.dispose();
  }

  void _showErrorDialog(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notice'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn(GoogleSignInAccount account) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        _showErrorDialog('Could not get Google ID token.');
        return;
      }
      final r = await _auth.googleAuth(idToken);
      if (!mounted) return;
      if (r.isSuccess) {
        await _session.saveUserSession(r.token!, r.user!);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const UserHomeScreen()),
          (route) => false,
        );
      } else if (r.isGoogleNewUser) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GoogleRegistrationScreen(
              idToken: idToken,
              email: r.googleEmail ?? '',
              fullName: r.googleFullName ?? '',
            ),
          ),
        );
      } else {
        _showErrorDialog(r.errorMessage ?? 'Google Login failed');
      }
    } catch (e) {
      if (mounted) _showErrorDialog('Google Sign-In failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (kIsWeb) return;
    setState(() => _submitting = true);
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.signIn();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Google Sign-In failed: $e');
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top nav ──────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => const LoginScreen()),
                              ),
                      child: const Text(
                        'Log in',
                        style: TextStyle(
                          color: Color(0xFFB71C1C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Header ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFB71C1C),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Create your account',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Join thousands of donors saving lives every day',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF888888),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Stats row ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _StatChip(icon: Icons.people_rounded, label: '10K+ Donors'),
                    const SizedBox(width: 10),
                    _StatChip(
                        icon: Icons.favorite_rounded, label: 'Lives Saved'),
                    const SizedBox(width: 10),
                    _StatChip(
                        icon: Icons.location_on_rounded,
                        label: 'Pan India'),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Trust card ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFFB71C1C),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verified community only',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'We use Google Sign-in to verify real identities and prevent fake accounts — keeping our community trustworthy.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF888888),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── What you can do ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What you can do',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF888888),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.bloodtype_rounded,
                      text: 'Request blood in emergencies',
                    ),
                    _FeatureRow(
                      icon: Icons.volunteer_activism_rounded,
                      text: 'Register as a blood donor',
                    ),
                    _FeatureRow(
                      icon: Icons.sos_rounded,
                      text: 'Send SOS alerts to nearby donors',
                    ),
                    _FeatureRow(
                      icon: Icons.local_hospital_rounded,
                      text: 'Find blood banks near you',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Google Sign-in button ────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _submitting
                    ? const Center(child: CircularProgressIndicator(
                        color: Color(0xFFB71C1C),
                      ))
                    : GoogleAuthButton(
                        onPressed: _submitting ? () {} : _signInWithGoogle,
                      ),
              ),

              const SizedBox(height: 16),

              // ── Terms note ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFB71C1C)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB71C1C),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFFB71C1C)),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF333333),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
