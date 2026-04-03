import 'package:flutter/material.dart';

import '../services/session_store.dart';
import 'donor_bank_selection_screen.dart';

class DonorEligibilityScreen extends StatefulWidget {
  const DonorEligibilityScreen({super.key});

  @override
  State<DonorEligibilityScreen> createState() => _DonorEligibilityScreenState();
}

class _DonorEligibilityScreenState extends State<DonorEligibilityScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();

  String _gender = 'Male';
  bool _tattoo = false;
  bool _surgery = false;
  bool _menstrual = false;

  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final session = SessionStore();
    final u = await session.getUser();
    if (mounted) {
      setState(() {
        _user = u;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _checkEligibility() {
    if (!_formKey.currentState!.validate()) return;

    final weight = int.tryParse(_weightController.text) ?? 0;
    final age = int.tryParse(_ageController.text) ?? 0;

    String? error;
    if (age < 18 || age > 65) {
      error = 'Age must be between 18 and 65 to donate blood.';
    } else if (weight < 50) {
      error = 'Weight must be at least 50 kg to donate.';
    } else if (_tattoo) {
      error = 'You cannot donate if you had a tattoo in the last 12 months.';
    } else if (_surgery) {
      error = 'You cannot donate if you had a recent minor surgery.';
    } else if (_gender == 'Female' && _menstrual) {
      error = 'You cannot donate while in your menstrual cycle.';
    }

    if (error != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Not Eligible'),
          content: Text(error!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      // Eligible! Move to Nearest Banks selection to book an appointment
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are eligible! Connecting to nearest blood banks...'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const DonorBankSelectionScreen(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = _user?['fullName'] ?? 'Donor';
    final bloodGroup = _user?['bloodGroup'] ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donor Eligibility Form'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Hello $name!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Blood Group: $bloodGroup',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Please fill out this quick medical questionnaire to confirm you are eligible to donate today.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age (Years)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                ),
                items: ['Male', 'Female', 'Other']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _gender = v);
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Had a tattoo in the last 12 months?'),
                value: _tattoo,
                activeColor: Colors.red,
                onChanged: (v) => setState(() => _tattoo = v),
              ),
              SwitchListTile(
                title: const Text('Had any minor surgery recently?'),
                value: _surgery,
                activeColor: Colors.red,
                onChanged: (v) => setState(() => _surgery = v),
              ),
              if (_gender == 'Female')
                SwitchListTile(
                  title: const Text('Currently in menstrual cycle?'),
                  value: _menstrual,
                  activeColor: Colors.red,
                  onChanged: (v) => setState(() => _menstrual = v),
                ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _checkEligibility,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Check Eligibility & Proceed'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
