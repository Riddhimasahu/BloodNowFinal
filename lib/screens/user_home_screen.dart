import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/blood_groups.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/session_store.dart';
import '../services/user_api.dart';
import '../services/sos_api.dart';
import 'donor_eligibility_screen.dart';
import 'get_started_screen.dart';
import 'requester_form_screen.dart';
import 'user_profile_screen.dart';
import 'donor_dashboard_screen.dart';
import 'donor_impact_screen.dart';
import 'map_route_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _sosAnim;
  late Animation<double> _sosScale;
  final _session = SessionStore();
  
  int _currentIndex = 0;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _upcomingAppointment;
  DateTime? _upcomingDate;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _sosAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _sosScale = Tween<double>(begin: 1.0, end: 1.05).animate(_sosAnim);
    _loadUser();
  }

  @override
  void dispose() {
    _sosAnim.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final token = await _session.getToken();
    final u = await _session.getUser();
    
    if (mounted && u != null) {
      setState(() {
        _user = u;
        _loadingUser = false;
      });
    }

    if (token != null) {
      try {
        final api = UserApi();
        final res = await api.getMe(token);
        api.close();
        if (res.isSuccess && res.user != null) {
          await _session.saveUserSession(token, res.user!);
          if (mounted) {
            setState(() {
              _user = res.user;
            });
          }
        }
        final activityRes = await api.getUserActivity(token);
        if (activityRes.isSuccess && activityRes.data != null) {
          final appts = activityRes.data!['appointments'] as List?;
          if (appts != null) {
            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day);
            Map<String, dynamic>? nextAppt;
            DateTime? nextApptDate;

            for (var a in appts) {
              if ((a['status'] == 'pending' || a['status'] == 'confirmed') && a['appointment_date'] != null) {
                final dt = DateTime.parse(a['appointment_date']).toLocal();
                final endTime = dt.add(const Duration(hours: 2));
                // Only show if the current time is before the appointment end time
                if (now.isBefore(endTime)) {
                  if (nextApptDate == null || dt.isBefore(nextApptDate)) {
                    nextAppt = a;
                    nextApptDate = dt;
                  }
                }
              }
            }
            if (mounted) {
              setState(() {
                _upcomingAppointment = nextAppt;
                _upcomingDate = nextApptDate;
              });
            }
          }
        }
      } catch (_) {}

      // Fetch FCM Token and send to backend
      try {
        if (!kIsWeb) {
          final messaging = FirebaseMessaging.instance;
          final settings = await messaging.requestPermission(
            alert: true, badge: true, sound: true,
          );
          if (settings.authorizationStatus == AuthorizationStatus.authorized) {
            final fcmToken = await messaging.getToken();
            if (fcmToken != null) {
              final api = UserApi();
              await api.updateFcmToken(token, fcmToken);
              api.close();
            }
          }
        }
      } catch (e) {
        debugPrint('FCM Error: $e');
      }
    }

    if (mounted && _loadingUser) {
      setState(() {
        _loadingUser = false;
      });
    }
  }

  Future<void> _logout() async {
    await _session.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const GetStartedScreen()),
      (route) => false,
    );
  }

  Future<void> _sendSosRequest() async {
    final user = _user;
    if (user == null) return;
    
    // Check if vibration is available
    bool hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) {
      Vibration.vibrate(pattern: [500, 1000, 500, 1000, 500, 1000, 500, 1000], intensities: [1, 255, 1, 255, 1, 255, 1, 255]);
    }

    if (!mounted) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SosFormBottomSheet(initialBloodGroup: user['bloodGroup']),
    );

    if (hasVibrator) {
      Vibration.cancel();
    }

    if (result == null) return;

    final bg = result['bloodGroup'] as String;
    final lat = result['lat'] as double;
    final lng = result['lng'] as double;

    final token = await _session.getToken();
    if (token == null) return;

    try {
      final api = SosApi();
      final res = await api.sendSosRequest(
        token,
        bloodGroup: bg,
        lat: lat,
        lng: lng,
      );
      if (res.isSuccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alert sent to ${res.donorsNotifiedCount} nearby donors!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(res.errorMessage ?? 'Unknown error');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send SOS: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = _user == null ? '' : '${_user!['fullName'] ?? ''}';

    return Scaffold(
      appBar: _currentIndex == 0 ? AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'Profile',
            onPressed: () async {
              final updated = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => const UserProfileScreen(),
                ),
              );
              if (updated == true && mounted) await _loadUser();
            },
          ),
          TextButton(
            onPressed: _logout,
            child: const Text('Log out'),
          ),
        ],
      ) : null,
      body: _currentIndex == 0 
          ? _buildHomeContent(scheme, name) 
          : _currentIndex == 1 
              ? const DonorDashboardScreen()
              : const DonorImpactScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.red.shade700,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Donations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_rounded),
            label: 'Impact',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(ColorScheme scheme, String name) {
    return _loadingUser
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  name.isEmpty ? 'Welcome' : 'Welcome, $name',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'What would you like to do today?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                if (_upcomingAppointment != null && _upcomingDate != null)
                  Builder(
                    builder: (context) {
                      final dt = _upcomingDate!;
                      final now = DateTime.now();
                      final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
                      final dateStr = isToday ? 'Today' : '${dt.day}/${dt.month}/${dt.year}';
                      
                      String timeSlot = '${dt.hour}:00';
                      if (dt.hour == 9) timeSlot = '9:00 AM – 11:00 AM';
                      else if (dt.hour == 11) timeSlot = '11:00 AM – 1:00 PM';
                      else if (dt.hour == 14) timeSlot = '2:00 PM – 4:00 PM';
                      else if (dt.hour == 16) timeSlot = '4:00 PM – 6:00 PM';

                      return GestureDetector(
                        onTap: () async {
                          final lat = (_upcomingAppointment!['bank_lat'] as num).toDouble();
                          final lng = (_upcomingAppointment!['bank_lng'] as num).toDouble();
                          final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200, width: 2),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.red.withAlpha(20), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.directions_car_filled_rounded, color: Colors.blue.shade700, size: 36),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Upcoming Donation: $dateStr',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade900),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_upcomingAppointment!['bank_name']} at $timeSlot\nTap to get directions.',
                                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, color: Colors.red.shade700, size: 16),
                            ],
                          ),
                        ),
                      );
                    }
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.red.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.red.withAlpha(80), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Icon(Icons.water_drop, color: Colors.white.withAlpha(30), size: 150),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Blood Now',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: Colors.white, letterSpacing: 1.2),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Be the hero someone needs.\nDonate blood. Save lives.',
                                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(40),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.favorite, color: Colors.white, size: 40),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _DashboardCard(
                  title: 'I want to Donate Blood',
                  subtitle: 'Check eligibility and find a nearby blood bank to book an appointment.',
                  icon: Icons.favorite,
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DonorEligibilityScreen()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _DashboardCard(
                  title: 'I need Blood',
                  subtitle: 'Search nearby blood banks for required units or request from donors.',
                  icon: Icons.local_hospital,
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RequesterFormScreen()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                ScaleTransition(
                  scale: _sosScale,
                  child: ElevatedButton.icon(
                    onPressed: _sendSosRequest,
                    icon: const Icon(Icons.warning_amber_rounded, size: 28),
                    label: const Text('EMERGENCY SOS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: Colors.redAccent,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withAlpha(25), // 0.1 * 255
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(127), width: 1.5), // 0.5 * 255
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color,
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _SosFormBottomSheet extends StatefulWidget {
  final String? initialBloodGroup;
  const _SosFormBottomSheet({this.initialBloodGroup});

  @override
  State<_SosFormBottomSheet> createState() => _SosFormBottomSheetState();
}

class _SosFormBottomSheetState extends State<_SosFormBottomSheet> {
  late String _bloodGroup;
  final _area = TextEditingController();
  final _lat = TextEditingController(); // Hidden storage for GPS
  final _lng = TextEditingController();
  String _district = 'Kota';
  String _state = 'Rajasthan';
  bool _busy = false;

  final List<String> _districts = ['Kota', 'Jaipur', 'Bundi', 'Jodhpur', 'Udaipur', 'Bikaner', 'Ajmer'];
  final List<String> _states = ['Rajasthan', 'Delhi', 'Maharashtra', 'Madhya Pradesh', 'Gujarat'];

  @override
  void initState() {
    super.initState();
    _bloodGroup = widget.initialBloodGroup ?? 'O+';
    if (!kBloodGroups.contains(_bloodGroup)) _bloodGroup = 'O+';
  }

  @override
  void dispose() {
    _area.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() => _busy = true);
    try {
      final loc = LocationService();
      final pos = await loc.getCurrentPosition();
      _lat.text = pos.latitude.toString();
      _lng.text = pos.longitude.toString();
      final geo = GeocodingService();
      final addr = await geo.reverseLookup(pos.latitude, pos.longitude);
      geo.close();
      if (addr != null && mounted) {
        _area.text = addr;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GPS Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_area.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an area/address.')));
      return;
    }
    setState(() => _busy = true);

    double? lat;
    double? lng;

    final loc = LocationService();
    final fullAddr = '${_area.text}, $_district, $_state';
    final pos = await loc.geocodeAddress(fullAddr);

    if (pos != null) {
      lat = pos.latitude;
      lng = pos.longitude;
    } else if (_lat.text.isNotEmpty && _lng.text.isNotEmpty) {
      lat = double.tryParse(_lat.text);
      lng = double.tryParse(_lng.text);
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (lat != null && lng != null) {
      Navigator.of(context).pop({
        'bloodGroup': _bloodGroup,
        'lat': lat,
        'lng': lng,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not geocode address. Please use GPS or enter a clearer address.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Emergency SOS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 8),
          const Text('Alert nearby donors immediately.'),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _bloodGroup,
            decoration: const InputDecoration(labelText: 'Required Blood Group', border: OutlineInputBorder()),
            items: kBloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _bloodGroup = val);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _area,
            decoration: const InputDecoration(labelText: 'Area / Street Address', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _district,
                  decoration: const InputDecoration(labelText: 'District', border: OutlineInputBorder()),
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
                  decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                  items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _state = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : _useGps,
            icon: const Icon(Icons.my_location),
            label: const Text('Use Current Location'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _busy ? null : _submit,
            child: _busy 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text('SEND SOS ALERT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
