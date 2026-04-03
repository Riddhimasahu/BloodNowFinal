import 'package:flutter/material.dart';

import '../constants/blood_groups.dart';
import '../services/bank_api.dart';
import '../services/session_store.dart';
import 'bank_edit_profile_screen.dart';
import 'get_started_screen.dart';

class BankHomeScreen extends StatefulWidget {
  const BankHomeScreen({super.key});

  @override
  State<BankHomeScreen> createState() => _BankHomeScreenState();
}

class _BankHomeScreenState extends State<BankHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await SessionStore().clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const GetStartedScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood bank'),
        actions: [
          TextButton(
            onPressed: _logout,
            child: const Text('Log out'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Inventory'),
            Tab(text: 'Appointments'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _BankOverviewTab(),
          _BankInventoryTab(),
          _BankAppointmentsTab(),
          _BankRequestsTab(),
        ],
      ),
    );
  }
}

class _BankOverviewTab extends StatefulWidget {
  const _BankOverviewTab();

  @override
  State<_BankOverviewTab> createState() => _BankOverviewTabState();
}

class _BankOverviewTabState extends State<_BankOverviewTab> {
  final _session = SessionStore();
  final _api = BankApi();
  bool _loading = true;
  Map<String, dynamic>? _bank;
  String? _error;

  @override
  void dispose() {
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
        _error = 'Session missing';
      });
      return;
    }
    final r = await _api.getMe(token);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.isSuccess) {
        _bank = r.bank;
      } else {
        _error = r.errorMessage;
      }
    });
  }

  Future<void> _openEdit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const BankEditProfileScreen()),
    );
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.error),
          ),
        ),
      );
    }

    final b = _bank!;
    final lat = b['latitude'];
    final lng = b['longitude'];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${b['name'] ?? ''}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text('Email: ${b['email'] ?? ''}'),
        Text('Phone: ${b['phone'] ?? ''}'),
        if (b['addressLine'] != null && '${b['addressLine']}'.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${b['addressLine']}'),
          ),
        if (lat is num && lng is num)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Site: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _openEdit,
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Edit centre & password'),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Update stock levels under the Inventory tab. Requesters only see your bank when you have units available for their blood group.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BankInventoryTab extends StatefulWidget {
  const _BankInventoryTab();

  @override
  State<_BankInventoryTab> createState() => _BankInventoryTabState();
}

class _BankInventoryTabState extends State<_BankInventoryTab> {
  final _session = SessionStore();
  final _api = BankApi();
  final _controllers = <String, TextEditingController>{};

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _api.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _ensureControllers(List<InventoryItem> items) {
    for (final i in items) {
      _controllers.putIfAbsent(
        i.bloodGroup,
        () => TextEditingController(text: '${i.unitsAvailable}'),
      );
      _controllers[i.bloodGroup]!.text = '${i.unitsAvailable}';
    }
    for (final g in kBloodGroups) {
      _controllers.putIfAbsent(
        g,
        () => TextEditingController(text: '0'),
      );
    }
  }

  Future<void> _load() async {
    final token = await _session.getToken();
    if (!mounted) return;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Session missing';
      });
      return;
    }
    final r = await _api.getInventory(token);
    if (!mounted) return;
    if (!r.isSuccess) {
      setState(() {
        _loading = false;
        _error = r.errorMessage;
      });
      return;
    }
    _ensureControllers(r.items!);
    setState(() {
      _loading = false;
      _error = null;
    });
  }

  Future<void> _save() async {
    final token = await _session.getToken();
    if (!mounted) return;
    if (token == null) return;

    final units = <String, int>{};
    for (final g in kBloodGroups) {
      final c = _controllers[g];
      if (c == null) continue;
      final n = int.tryParse(c.text.trim());
      if (n == null || n < 0 || n > 999) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid units for $g (0–999)')),
        );
        return;
      }
      units[g] = n;
    }

    setState(() => _saving = true);
    final r = await _api.putInventory(token, units);
    if (!mounted) return;
    setState(() => _saving = false);

    if (r.isSuccess) {
      _ensureControllers(r.items!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory saved')),
      );
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.errorMessage ?? 'Save failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Units available',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter whole units (0–999) per group. Save to update what requesters see in nearest-bank search.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
        ),
        const SizedBox(height: 16),
        ...kBloodGroups.map((g) {
          final c = _controllers[g]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    g,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 32),
                        onPressed: () {
                          final cur = int.tryParse(c.text) ?? 0;
                          if (cur > 0) setState(() => c.text = (cur - 1).toString());
                        },
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            c.text.isEmpty ? '0' : c.text,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                        onPressed: () {
                          final cur = int.tryParse(c.text) ?? 0;
                          if (cur < 999) setState(() => c.text = (cur + 1).toString());
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save inventory'),
        ),
      ],
    );
  }
}

class _BankAppointmentsTab extends StatefulWidget {
  const _BankAppointmentsTab();

  @override
  State<_BankAppointmentsTab> createState() => _BankAppointmentsTabState();
}

class _BankAppointmentsTabState extends State<_BankAppointmentsTab> {
  final _session = SessionStore();
  final _api = BankApi();
  bool _loading = true;
  List<BankAppointment>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    final token = await _session.getToken();
    if (!mounted) return;
    if (token == null) return;
    
    final r = await _api.getAppointments(token);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.isSuccess) {
        _list = r.appointments;
      } else {
        _error = r.errorMessage;
      }
    });
  }

  Future<void> _update(int id, String status) async {
    final token = await _session.getToken();
    if (token == null) return;
    
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    final r = await _api.updateAppointmentStatus(token, id, status);
    if (!mounted) return;
    Navigator.of(context).pop();

    if (r.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Appointment marked $status')));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.errorMessage ?? 'Failed')));
    }
  }

  Future<void> _markUsed(int id) async {
    final token = await _session.getToken();
    if (token == null) return;
    
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    final r = await _api.markDonationAsUsed(token, id);
    if (!mounted) return;
    Navigator.of(context).pop();

    if (r.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as dispensed! Donor notified. ❤️')));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.errorMessage ?? 'Failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_list == null || _list!.isEmpty) return const Center(child: Text('No appointments.'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _list!.length,
        itemBuilder: (ctx, i) {
          final item = _list![i];
          return Card(
            child: ListTile(
              title: Text('${item.donorName} (${item.bloodGroup})'),
              subtitle: Text('${item.date.split('T').first}\nStatus: ${item.status}'),
              isThreeLine: true,
              trailing: item.status == 'pending'
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          tooltip: 'Accept',
                          onPressed: () => _update(item.id, 'confirmed'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          tooltip: 'Reject',
                          onPressed: () => _update(item.id, 'no_show'),
                        ),
                      ],
                    )
                  : item.status == 'confirmed'
                      ? FilledButton.tonal(
                          onPressed: () => _update(item.id, 'donated'),
                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                          child: const Text('Donated'),
                        )
                      : item.status == 'donated' && !item.isUsed
                          ? FilledButton.tonalIcon(
                              onPressed: () => _markUsed(item.id),
                              icon: const Icon(Icons.outbound, size: 18),
                              label: const Text('Dispatch'),
                              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                            )
                          : item.status == 'donated' && item.isUsed
                              ? const Chip(
                                  label: Text('Dispensed ✨', style: TextStyle(fontSize: 12)),
                                  backgroundColor: Colors.transparent,
                                  side: BorderSide(color: Colors.green),
                                )
                              : null,
            ),
          );
        },
      ),
    );
  }
}

class _BankRequestsTab extends StatefulWidget {
  const _BankRequestsTab();

  @override
  State<_BankRequestsTab> createState() => _BankRequestsTabState();
}

class _BankRequestsTabState extends State<_BankRequestsTab> {
  final _session = SessionStore();
  final _api = BankApi();
  bool _loading = true;
  List<BankBloodRequest>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    final token = await _session.getToken();
    if (!mounted) return;
    if (token == null) return;
    
    final r = await _api.getRequests(token);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.isSuccess) {
        _list = r.requests;
      } else {
        _error = r.errorMessage;
      }
    });
  }

  Future<void> _update(int id, String status) async {
    final token = await _session.getToken();
    if (token == null) return;
    
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    final r = await _api.updateRequestStatus(token, id, status);
    if (!mounted) return;
    Navigator.of(context).pop();

    if (r.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request marked $status')));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.errorMessage ?? 'Failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_list == null || _list!.isEmpty) return const Center(child: Text('No requests.'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _list!.length,
        itemBuilder: (ctx, i) {
          final item = _list![i];
          return Card(
            child: ListTile(
              title: Text('${item.patientName} needs ${item.unitsNeeded} units of ${item.bloodGroup}'),
              subtitle: Text('${item.date.split('T').first}\nStatus: ${item.status}'),
              isThreeLine: true,
              trailing: item.status == 'pending'
                  ? FilledButton(
                      onPressed: () => _update(item.id, 'fulfilled'),
                      child: const Text('Fulfill'),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
