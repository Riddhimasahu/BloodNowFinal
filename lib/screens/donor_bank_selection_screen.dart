import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../services/search_api.dart';
import '../services/session_store.dart';
import '../services/user_api.dart';
import '../services/geocoding_service.dart';
import 'map_route_screen.dart';

class DonorBankSelectionScreen extends StatefulWidget {
  const DonorBankSelectionScreen({super.key});

  @override
  State<DonorBankSelectionScreen> createState() => _DonorBankSelectionScreenState();
}

class _DonorBankSelectionScreenState extends State<DonorBankSelectionScreen> {
  final _search = SearchApi();
  final _location = LocationService();
  final _userApi = UserApi();

  final _addressController = TextEditingController();

  bool _searching = false;
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
        _addressController.text = addr;
      }
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
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
        _addressController.text = addr;
        await _runSearch();
      }
    } on LocationException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location error: $e')));
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  Future<void> _runSearch() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an address to search near.')));
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
      _banks = [];
    });

    final pos = await _location.geocodeAddress(address);
    if (pos == null) {
      if (mounted) {
        setState(() {
          _searching = false;
          _searchError = 'Could not pinpoint this address. Please try standardizing it (e.g. City, Region).';
        });
      }
      return;
    }

    final res = await _search.nearestBanks(
      latitude: pos.latitude,
      longitude: pos.longitude,
      limit: 20,
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

  Future<void> _bookAppointment(int bankId, String bankName, double bankLat, double bankLng) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
        String? selectedSlot;
        final slotList = ['9:00 AM – 11:00 AM', '11:00 AM – 1:00 PM', '2:00 PM – 4:00 PM', '4:00 PM – 6:00 PM'];

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Book Appointment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 300,
                        child: CalendarDatePicker(
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                          onDateChanged: (val) {
                            setState(() => selectedDate = val);
                          },
                        ),
                      ),
                      const Divider(),
                      const Text('Select Time Slot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...slotList.map((slot) {
                        final isSelected = selectedSlot == slot;
                        
                        bool isAvailable = true;
                        final now = DateTime.now();
                        if (selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day == now.day) {
                          int endHour = 11;
                          if (slot.startsWith('11')) endHour = 13;
                          else if (slot.startsWith('2')) endHour = 16;
                          else if (slot.startsWith('4')) endHour = 18;
                          if (now.hour >= endHour) isAvailable = false;
                        }

                        return InkWell(
                          onTap: isAvailable ? () {
                            setState(() => selectedSlot = slot);
                          } : null,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isAvailable ? (isSelected ? Colors.red.shade50 : Colors.transparent) : Colors.grey.shade100,
                              border: Border.all(color: isAvailable ? (isSelected ? Colors.red : Colors.grey.shade300) : Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time, color: isAvailable ? (isSelected ? Colors.red : Colors.grey) : Colors.grey.shade400),
                                const SizedBox(width: 12),
                                Text(
                                  slot,
                                    style: TextStyle(
                                      color: isAvailable ? (isSelected ? Colors.red.shade900 : Colors.black87) : Colors.grey.shade400,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      decoration: isAvailable ? null : TextDecoration.lineThrough,
                                    ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: selectedSlot == null ? null : () {
                              Navigator.of(ctx).pop({
                                'date': selectedDate,
                                'slot': selectedSlot,
                              });
                            },
                            child: const Text('Confirm'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    
    final date = result['date'] as DateTime;
    final selectedSlot = result['slot'] as String;

    int hour = 9;
    if (selectedSlot.startsWith('11')) hour = 11;
    if (selectedSlot.startsWith('2')) hour = 14;
    if (selectedSlot.startsWith('4')) hour = 16;
    final finalDate = DateTime(date.year, date.month, date.day, hour, 0);

    final token = await SessionStore().getToken();
    if (token == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await _userApi.bookAppointment(token, bankId, finalDate);

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    if (res.isSuccess) {
      if (!mounted) return;
      final now = DateTime.now();
      final isToday = finalDate.year == now.year && finalDate.month == now.month && finalDate.day == now.day;
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Appointment Booked!'),
          content: Text('Your donation appointment at $bankName has been scheduled for ${finalDate.toLocal().toString().split(' ')[0]} ($selectedSlot). Thank you for being a hero!\n\nYou can view your appointment details and get directions anytime from your dashboard.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(); // back to dashboard
                Navigator.of(context).pop(); // pop eligibility too
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.errorMessage ?? 'Failed to book')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select a Blood Bank')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Origin Address (Your Location)', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.location_on)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _gpsBusy || _searching ? null : _useGpsForSearch,
            icon: _gpsBusy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
            label: const Text('Use GPS & Search'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _searching ? null : _runSearch,
            child: _searching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Search Banks'),
          ),
          if (_searchError != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_searchError!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 20),
          ..._banks.map((b) => Card(
            child: ListTile(
              leading: const Icon(Icons.local_hospital, color: Colors.red),
              title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${(b.distanceMeters / 1000).toStringAsFixed(2)} km away\n${b.addressLine ?? ''}'),
              isThreeLine: true,
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _bookAppointment(b.id, b.name, b.latitude, b.longitude),
            ),
          )),
        ],
      ),
    );
  }
}
