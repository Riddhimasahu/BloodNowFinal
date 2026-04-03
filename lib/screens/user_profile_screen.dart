import 'package:flutter/material.dart';

import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/session_store.dart';
import '../services/user_api.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
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
  final _api = UserApi();
  final _location = LocationService();

  bool _shareLocation = false;
  bool _loading = true;
  bool _saving = false;
  bool _pwdObscure = true;
  String? _loadError;
  String? _emailLabel;
  int _credits = 0;

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
    _fetch();
  }

  Future<void> _fetch() async {
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
    final u = r.user!;
    _emailLabel = u['email'] as String?;
    _credits = u['credits'] ?? 0;
    _name.text = '${u['fullName'] ?? ''}';
    _phone.text = '${u['phone'] ?? ''}';
    _address.text = '${u['addressLine'] ?? ''}';
    final lat = u['latitude'];
    final lng = u['longitude'];
    if (lat is num && lng is num) {
      _lat.text = lat.toStringAsFixed(6);
      _lng.text = lng.toStringAsFixed(6);
    } else {
      _lat.clear();
      _lng.clear();
    }
    _shareLocation = u['shareLocationForMatching'] == true;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final latStr = _lat.text.trim();
    final lngStr = _lng.text.trim();
    double? lat;
    double? lng;
    if (latStr.isNotEmpty || lngStr.isNotEmpty) {
      if (latStr.isEmpty || lngStr.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter both latitude and longitude, or clear both.'),
          ),
        );
        return;
      }
      lat = double.tryParse(latStr);
      lng = double.tryParse(lngStr);
      if (lat == null || lng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid coordinates.')),
        );
        return;
      }
    }

    if (_shareLocation && (lat == null || lng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sharing location requires coordinates (GPS or manual).'),
        ),
      );
      return;
    }

    final token = await _session.getToken();
    if (token == null) return;

    setState(() => _saving = true);

    final body = <String, dynamic>{
      'fullName': _name.text.trim(),
      'phone': _phone.text.trim(),
      'shareLocationForMatching': _shareLocation,
    };
    final addr = _address.text.trim();
    body['addressLine'] = addr.isEmpty ? null : addr;
    if (lat != null && lng != null) {
      body['latitude'] = lat;
      body['longitude'] = lng;
    } else {
      body['latitude'] = null;
      body['longitude'] = null;
    }

    final r = await _api.patchMe(token, body);
    if (!mounted) return;
    setState(() => _saving = false);

    if (r.isSuccess) {
      await _session.saveUserSession(token, r.user!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
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
      appBar: AppBar(title: const Text('My profile')),
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
                            trailing: _buildBadge(),
                          ),
                        Text(
                          'Blood group is set at registration. Contact support to change it later.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().length < 2)
                              ? 'Enter your name'
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
                          label: const Text('Update location from GPS'),
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
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Share location for donor matching'),
                          subtitle: const Text(
                            'Visible only to signed-in users searching for donors.',
                          ),
                          value: _shareLocation,
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _shareLocation = v),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _saving ? null : _saveProfile,
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save profile'),
                        ),
                        const Divider(height: 40),
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

  Widget _buildBadge() {
    if (_credits >= 4) {
      return Chip(
        avatar: const Icon(Icons.workspace_premium, color: Colors.white, size: 20),
        label: const Text('Gold Donor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber.shade600,
        side: BorderSide.none,
      );
    } else if (_credits >= 2) {
      return Chip(
        avatar: const Icon(Icons.emoji_events, color: Colors.white, size: 20),
        label: const Text('Silver Donor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey.shade600,
        side: BorderSide.none,
      );
    } else if (_credits >= 1) {
      return Chip(
        avatar: const Icon(Icons.military_tech, color: Colors.white, size: 20),
        label: const Text('Bronze Donor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.brown.shade400,
        side: BorderSide.none,
      );
    }
    return const SizedBox.shrink();
  }
}
