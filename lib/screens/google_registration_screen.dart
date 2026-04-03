import 'package:flutter/material.dart';

import '../constants/blood_groups.dart';
import '../services/auth_api.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/session_store.dart';
import 'user_home_screen.dart';

class GoogleRegistrationScreen extends StatefulWidget {
  const GoogleRegistrationScreen({
    super.key,
    required this.idToken,
    required this.email,
    required this.fullName,
  });

  final String idToken;
  final String email;
  final String fullName;

  @override
  State<GoogleRegistrationScreen> createState() => _GoogleRegistrationScreenState();
}

class _GoogleRegistrationScreenState extends State<GoogleRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  bool _obscurePassword = true;

  double? _latValue;
  double? _lngValue;
  bool _gpsAcquired = false;

  final List<String> _states = ['Rajasthan', 'Madhya Pradesh', 'Gujarat', 'Maharashtra', 'Delhi'];
  final Map<String, List<String>> _districtsByState = {
    'Rajasthan': ['Kota', 'Jaipur', 'Jodhpur', 'Udaipur', 'Ajmer', 'Bikaner'],
    'Madhya Pradesh': ['Bhopal', 'Indore', 'Gwalior', 'Jabalpur'],
    'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot'],
    'Maharashtra': ['Mumbai', 'Pune', 'Nagpur', 'Thane'],
    'Delhi': ['New Delhi', 'North Delhi', 'South Delhi', 'East Delhi', 'West Delhi'],
  };
  
  String? _selectedState;
  String? _selectedDistrict;

  String _bloodGroup = kBloodGroups[4];
  bool _shareLocation = false;
  bool _submitting = false;

  final _auth = AuthApi();
  final _session = SessionStore();
  final _location = LocationService();

  @override
  void dispose() {
    _password.dispose();
    _phone.dispose();
    _address.dispose();
    _auth.close();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() => _submitting = true);
    try {
      final pos = await _location.getCurrentPosition();
      _latValue = pos.latitude;
      _lngValue = pos.longitude;
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
        setState(() => _gpsAcquired = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location securely captured.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
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

    if (_shareLocation && (_latValue == null || _lngValue == null)) {
      _showErrorDialog('Turn off "share location" or capture GPS to share your position.');
      return;
    }

    setState(() => _submitting = true);

    final addrParts = <String>[];
    if (_address.text.trim().isNotEmpty) addrParts.add(_address.text.trim());
    if (_selectedDistrict != null) addrParts.add(_selectedDistrict!);
    if (_selectedState != null) addrParts.add(_selectedState!);
    
    final fullAddr = addrParts.join(', ');

    final extraInfo = <String, dynamic>{
      'password': _password.text.trim(),
      'phone': _phone.text.trim(),
      'bloodGroup': _bloodGroup,
      'shareLocationForMatching': _shareLocation,
    };
    
    if (fullAddr.isNotEmpty) extraInfo['addressLine'] = fullAddr;
    if (_latValue != null && _lngValue != null) {
      extraInfo['latitude'] = _latValue;
      extraInfo['longitude'] = _lngValue;
    }

    try {
      final result = await _auth.googleAuth(widget.idToken, extraInfo);

      if (!mounted) return;

      if (result.isSuccess) {
        await _session.saveUserSession(result.token!, result.user!);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const UserHomeScreen()),
          (route) => false,
        );
      } else {
        final msg = result.errorMessage ?? 'Registration failed';
        _showErrorDialog(msg);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Almost Done')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Complete your profile',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'We need a few more details to set up your account.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                initialValue: widget.fullName,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: widget.email,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              const Text(
                'Set a Password for Email Login',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Create a password',
                  hintText: 'So you can also log in without Google later',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 8) ? 'Password must be at least 8 characters' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 8) ? 'Enter a valid phone' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _bloodGroup,
                decoration: const InputDecoration(
                  labelText: 'Blood group',
                  border: OutlineInputBorder(),
                ),
                items: kBloodGroups
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (v) {
                        if (v != null) setState(() => _bloodGroup = v);
                      },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedState,
                decoration: const InputDecoration(
                  labelText: 'State (optional)',
                  border: OutlineInputBorder(),
                ),
                items: _states
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (v) {
                        setState(() {
                          _selectedState = v;
                          _selectedDistrict = null; // Reset district
                        });
                      },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedDistrict,
                decoration: const InputDecoration(
                  labelText: 'District (optional)',
                  border: OutlineInputBorder(),
                ),
                items: _selectedState == null
                    ? []
                    : _districtsByState[_selectedState!]!
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                onChanged: _submitting || _selectedState == null
                    ? null
                    : (v) {
                        setState(() => _selectedDistrict = v);
                      },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _address,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Locality / Area Details (optional)',
                  hintText: 'Or click GPS below to fill automatically',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : _useGps,
                      icon: const Icon(Icons.my_location_rounded),
                      label: const Text('Use current location (GPS)'),
                    ),
                  ),
                  if (_gpsAcquired) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 4),
                    const Text('Acquired', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Share location for donor matching'),
                value: _shareLocation,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _shareLocation = v),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Finish Registration'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
