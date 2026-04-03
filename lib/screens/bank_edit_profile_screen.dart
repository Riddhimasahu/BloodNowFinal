import 'package:flutter/material.dart';

import '../services/bank_api.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart' show LocationException, LocationService;
import '../services/session_store.dart';

class BankEditProfileScreen extends StatefulWidget {
  const BankEditProfileScreen({super.key});

  @override
  State<BankEditProfileScreen> createState() => _BankEditProfileScreenState();
}

class _BankEditProfileScreenState extends State<BankEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _currentPwd = TextEditingController();
  final _newPwd = TextEditingController();
  final _confirmPwd = TextEditingController();

  final _session = SessionStore();
  final _api = BankApi();
  final _location = LocationService();

  bool _loading = true;
  bool _saving = false;
  bool _pwdObscure = true;
  String? _emailLabel;
  String? _loadError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _lat.dispose();
    _lng.dispose();
    _currentPwd.dispose();
    _newPwd.dispose();
    _confirmPwd.dispose();
    _api.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await _session.getToken();
    if (!mounted) return;
    if (token == null) {
      setState(() {
        _loading = false;
        _loadError = 'Not signed in';
      });
      return;
    }
    final r = await _api.getMe(token);
    if (!mounted) return;
    if (!r.isSuccess) {
      setState(() {
        _loading = false;
        _loadError = r.errorMessage ?? 'Failed to load';
      });
      return;
    }
    final b = r.bank!;
    _emailLabel = b['email'] as String?;
    _name.text = '${b['name'] ?? ''}';
    _phone.text = '${b['phone'] ?? ''}';
    _address.text = '${b['addressLine'] ?? ''}';
    final lat = b['latitude'];
    final lng = b['longitude'];
    if (lat is num && lng is num) {
      _lat.text = lat.toStringAsFixed(6);
      _lng.text = lng.toStringAsFixed(6);
    }
    setState(() => _loading = false);
  }

  Future<void> _useGps() async {
    setState(() => _saving = true);
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
          const SnackBar(content: Text('Location updated from GPS.')),
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
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valid latitude and longitude required.')),
      );
      return;
    }

    final token = await _session.getToken();
    if (token == null) return;

    setState(() => _saving = true);
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'phone': _phone.text.trim(),
      'latitude': lat,
      'longitude': lng,
    };
    final addr = _address.text.trim();
    body['addressLine'] = addr.isEmpty ? null : addr;

    final r = await _api.patchMe(token, body);
    if (!mounted) return;
    setState(() => _saving = false);

    if (r.isSuccess) {
      await _session.saveBankSession(token, r.bank!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Centre details saved')),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.errorMessage ?? 'Save failed')),
      );
    }
  }

  Future<void> _changePassword() async {
    final cur = _currentPwd.text;
    final n = _newPwd.text;
    final c = _confirmPwd.text;
    if (cur.isEmpty || n.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill current and new password')),
      );
      return;
    }
    if (n.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password: at least 8 characters')),
      );
      return;
    }
    if (n != c) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    final token = await _session.getToken();
    if (token == null) return;

    setState(() => _saving = true);
    final r = await _api.changePassword(
      token,
      currentPassword: cur,
      newPassword: n,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (r.isSuccess) {
      _currentPwd.clear();
      _newPwd.clear();
      _confirmPwd.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.errorMessage ?? 'Failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit centre')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                )
              : SafeArea(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        if (_emailLabel != null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Email'),
                            subtitle: Text(_emailLabel!),
                          ),
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Centre name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().length < 2)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().length < 8)
                              ? 'Valid phone required'
                              : null,
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
                          onPressed: _saving ? null : _useGps,
                          icon: const Icon(Icons.my_location_rounded),
                          label: const Text('Update site from GPS'),
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
                                  labelText: 'Latitude',
                                  border: OutlineInputBorder(),
                                ),
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
                                  labelText: 'Longitude',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save'),
                        ),
                        const Divider(height: 36),
                        Text(
                          'Change password',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _currentPwd,
                          obscureText: _pwdObscure,
                          decoration: const InputDecoration(
                            labelText: 'Current password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _newPwd,
                          obscureText: _pwdObscure,
                          decoration: const InputDecoration(
                            labelText: 'New password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPwd,
                          obscureText: _pwdObscure,
                          decoration: const InputDecoration(
                            labelText: 'Confirm new password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _pwdObscure = !_pwdObscure),
                          child: Text(_pwdObscure ? 'Show passwords' : 'Hide passwords'),
                        ),
                        OutlinedButton(
                          onPressed: _saving ? null : _changePassword,
                          child: const Text('Update password'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
