import 'package:flutter/material.dart';

import '../services/bank_api.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart' show LocationException, LocationService;
import '../services/session_store.dart';
import 'bank_home_screen.dart';
import 'bank_login_screen.dart';

class BankRegistrationScreen extends StatefulWidget {
  const BankRegistrationScreen({super.key});

  @override
  State<BankRegistrationScreen> createState() => _BankRegistrationScreenState();
}

class _BankRegistrationScreenState extends State<BankRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _address = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();

  bool _obscurePassword = true;
  bool _submitting = false;

  final _api = BankApi();
  final _session = SessionStore();
  final _location = LocationService();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _address.dispose();
    _lat.dispose();
    _lng.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() => _submitting = true);
    try {
      final pos = await _location.getCurrentPosition();
      _lat.text = pos.latitude.toStringAsFixed(6);
      _lng.text = pos.longitude.toStringAsFixed(6);
      final geo = GeocodingService();
      try {
        final line = await geo.reverseLookup(pos.latitude, pos.longitude);
        if (line != null && line.isNotEmpty && _address.text.trim().isEmpty) {
          _address.text = line;
        }
      } finally {
        geo.close();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location captured.')),
        );
      }
    } on LocationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (lat == null || lng == null) {
      _showErrorDialog('Latitude and longitude are required for the bank site.');
      return;
    }

    setState(() => _submitting = true);

    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'password': _password.text,
      'latitude': lat,
      'longitude': lng,
    };
    final addr = _address.text.trim();
    if (addr.isNotEmpty) body['addressLine'] = addr;

    try {
      final r = await _api.register(body);
      if (!mounted) return;

      if (r.isSuccess) {
        await _session.saveBankSession(r.token!, r.bank!);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const BankHomeScreen()),
          (route) => false,
        );
      } else {
        _showErrorDialog(r.errorMessage ?? 'Registration failed');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood bank registration'),
        actions: [
          TextButton(
            onPressed: _submitting
                ? null
                : () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(builder: (_) => const BankLoginScreen()),
                    );
                  },
            child: const Text('Log in'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Register your centre',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'A fixed site location is required for donor and patient matching.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Blood bank / centre name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Official email',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Valid email required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 8) ? 'Valid phone required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.length < 8) ? 'At least 8 characters' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _address,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _useGps,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Set site location (GPS)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lat,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Latitude *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lng,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Longitude *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create blood bank account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
