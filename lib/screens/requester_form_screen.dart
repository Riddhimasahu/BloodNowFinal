import 'package:flutter/material.dart';

import '../constants/blood_groups.dart';
import '../services/location_service.dart';
import '../services/search_api.dart';
import '../services/session_store.dart';
import '../services/geocoding_service.dart';
import '../services/user_api.dart';

class RequesterFormScreen extends StatefulWidget {
  const RequesterFormScreen({super.key});

  @override
  State<RequesterFormScreen> createState() => _RequesterFormScreenState();
}

class _RequesterFormScreenState extends State<RequesterFormScreen> {
  final _search = SearchApi();
  final _location = LocationService();
  final _userApi = UserApi();

  final _area = TextEditingController();
  final _patientName = TextEditingController();
  final _patientAge = TextEditingController();
  final _units = TextEditingController(text: '1');
  
  String _district = 'Kota';
  String _state = 'Rajasthan';

  final List<String> _districts = ['Kota', 'Jaipur', 'Bundi', 'Jodhpur', 'Udaipur', 'Bikaner', 'Ajmer'];
  final List<String> _states = ['Rajasthan', 'Delhi', 'Maharashtra', 'Madhya Pradesh', 'Gujarat'];

  String _neededBloodGroup = kBloodGroups[4];
  bool _searching = false;
  bool _hasSearched = false;
  bool _gpsBusy = false;
  List<NearestBank> _banks = [];
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    final session = SessionStore();
    final u = await session.getUser();
    if (mounted && u != null) {
      final addr = u['addressLine'];
      if (addr != null && addr is String && addr.isNotEmpty) {
        _area.text = addr;
      }
    }
  }

  @override
  void dispose() {
    _area.dispose();
    _patientName.dispose();
    _patientAge.dispose();
    _units.dispose();
    _search.close();
    _userApi.close();
    super.dispose();
  }

  Future<void> _useGpsForSearch() async {
    setState(() => _gpsBusy = true);
    try {
      final pos = await _location.getCurrentPosition();
      final geo = GeocodingService();
      final addr = await geo.reverseLookup(pos.latitude, pos.longitude);
      geo.close();
      if (addr != null && mounted) {
        _area.text = addr;
      }
    } on LocationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  Future<void> _runSearch() async {
    final area = _area.text.trim();
    if (area.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter area/street address.')),
      );
      return;
    }

    setState(() {
      _searching = true;
      _hasSearched = true;
      _searchError = null;
      _banks = [];
    });

    final units = int.tryParse(_units.text.trim()) ?? 1;
    final fullAddress = '$area, $_district, $_state';

    final res = await _search.nearestBanks(
      address: fullAddress,
      bloodGroup: _neededBloodGroup,
      minUnits: units,
      limit: 15,
    );

    if (!mounted) return;
    setState(() {
      _searching = false;
      if (res.isSuccess) {
        _banks = res.results!;
      } else {
        _searchError = res.errorMessage;
      }
    });
  }

  Future<void> _submitRequest(int bankId, String bankName) async {
    final units = int.tryParse(_units.text.trim());
    if (units == null || units <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid positive number for units.')),
      );
      return;
    }
    final token = await SessionStore().getToken();
    if (token == null) return;
    
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final age = int.tryParse(_patientAge.text.trim());

    final res = await _userApi.requestBlood(
      token,
      bankId,
      bloodGroup: _neededBloodGroup,
      unitsNeeded: units,
      patientName: _patientName.text.trim(),
      patientAge: age,
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading dialog

    if (res.isSuccess) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Request Sent!'),
          content: Text('Your request for $units units of $_neededBloodGroup has been sent to $bankName.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(); // go back to dashboard
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.errorMessage ?? 'Failed to send request')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Blood (Requester)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Request Blood',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Locate nearby blood banks that currently have the blood group you need in stock.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _patientName,
            decoration: const InputDecoration(
              labelText: 'Patient Name (Optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _patientAge,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Patient Age (Optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>(_neededBloodGroup),
                  initialValue: _neededBloodGroup,
                  decoration: const InputDecoration(
                    labelText: 'Required blood group',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: kBloodGroups
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _neededBloodGroup = v);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _units,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Units',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Search Location (Hospital / Current)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _area,
            decoration: const InputDecoration(
              labelText: 'Area / Street Address',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _district,
                  decoration: const InputDecoration(labelText: 'District', border: OutlineInputBorder(), isDense: true),
                  items: _districts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _district = val);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _state,
                  decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder(), isDense: true),
                  items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _state = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _gpsBusy ? null : _useGpsForSearch,
            icon: _gpsBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded, size: 20),
            label: Text(_gpsBusy ? 'Getting location…' : 'Fill from GPS'),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _searching ? null : _runSearch,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: _searching
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Find Available Blood Banks'),
          ),
          if (_searchError != null) ...[
            const SizedBox(height: 16),
            Text(
              _searchError!,
              style: TextStyle(color: scheme.error),
            ),
          ],
          if (!_searching && _hasSearched && _banks.isEmpty && _searchError == null) ...[
            const SizedBox(height: 20),
            Center(
              child: Text(
                'No blood banks found with $_neededBloodGroup in stock nearby.\n(They must update their inventory first.)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
          ],
          const SizedBox(height: 20),
          ..._banks.map(
            (b) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.location_city, color: Colors.white),
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(width: 8),
                    if (_hasSearched)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: b.availableUnits > 5
                              ? Colors.green.shade50
                              : (b.availableUnits > 0 ? Colors.orange.shade50 : Colors.red.shade50),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: b.availableUnits > 5
                                ? Colors.green.shade700
                                : (b.availableUnits > 0 ? Colors.orange.shade700 : Colors.red.shade700),
                          ),
                        ),
                        child: Text(
                          b.availableUnits > 5
                              ? 'Available (${b.availableUnits})'
                              : (b.availableUnits > 0 ? 'Low Stock (${b.availableUnits})' : 'Unavailable (0)'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: b.availableUnits > 5
                                ? Colors.green.shade900
                                : (b.availableUnits > 0 ? Colors.orange.shade900 : Colors.red.shade900),
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  [
                    if (b.addressLine != null && b.addressLine!.isNotEmpty)
                      b.addressLine!,
                    '${(b.distanceMeters / 1000).toStringAsFixed(2)} km away',
                  ].join('\n'),
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _submitRequest(b.id, b.name),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
