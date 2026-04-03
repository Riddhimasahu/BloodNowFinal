import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_store.dart';
import '../services/user_api.dart';

class DonorDashboardScreen extends StatefulWidget {
  const DonorDashboardScreen({super.key});

  @override
  State<DonorDashboardScreen> createState() => _DonorDashboardScreenState();
}

class _DonorDashboardScreenState extends State<DonorDashboardScreen> {
  final _session = SessionStore();
  bool _isLoading = true;
  String? _error;

  int _credits = 0;
  int _totalDonations = 0;
  DateTime? _lastDonationDate;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _session.getToken();
      if (token == null) throw Exception('Not logged in');

      final api = UserApi();
      final res = await api.getDonorProfile(token);
      api.close();

      if (res.isSuccess && res.data != null) {
        final data = res.data!;
        setState(() {
          _credits = data['credits'] ?? 0;
          _totalDonations = data['totalDonations'] ?? 0;
          _lastDonationDate = data['lastDonationDate'] != null 
              ? DateTime.parse(data['lastDonationDate']) 
              : null;
          _history = data['donationHistory'] as List<dynamic>? ?? [];
        });
      } else {
        throw Exception(res.errorMessage ?? 'Failed to load profile');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _isEligibleToDonate {
    if (_lastDonationDate == null) return true;
    final nextEligible = _lastDonationDate!.add(const Duration(days: 90));
    return DateTime.now().isAfter(nextEligible);
  }

  DateTime? get _nextEligibleDate {
    if (_lastDonationDate == null) return null;
    return _lastDonationDate!.add(const Duration(days: 90));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Donations'),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : _error != null 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProfile,
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBannerCard(),
          const SizedBox(height: 16),
          _buildImpactCard(),
          const SizedBox(height: 16),
          _buildEligibilityCard(),
          const SizedBox(height: 16),
          _buildUpcomingDonations(),
          const SizedBox(height: 16),
          Text(
            'Donation History',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._buildHistoryList(),
        ],
      ),
    );
  }

  Widget _buildBannerCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
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
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Be the hero someone needs.\nDonate blood. Save lives.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.4,
                        ),
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
    );
  }

  Widget _buildImpactCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  radius: 30,
                  child: Icon(Icons.favorite, color: Colors.blue.shade700, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Impact',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You have helped $_totalDonations people so far!',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Credit Score', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('$_credits Credits', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                _buildBadge(),
              ],
            ),
          ],
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
    return Text('Donate to earn badges!', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic));
  }

  Widget _buildEligibilityCard() {
    final eligible = _isEligibleToDonate;
    final date = _nextEligibleDate;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: eligible ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  eligible ? Icons.check_circle : Icons.timer,
                  color: eligible ? Colors.green.shade700 : Colors.orange.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Next Eligible Date',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: eligible ? Colors.green.shade900 : Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (eligible)
              Text(
                'You are currently eligible to donate blood. Thank you for being a lifesaver!',
                style: TextStyle(color: Colors.green.shade800, fontSize: 16),
              )
            else ...[
              Text(
                'For your safety, you must wait 90 days between blood donations.',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (date != null)
                Text(
                  DateFormat('MMMM d, yyyy').format(date),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingDonations() {
    final now = DateTime.now();
    
    final upcomingList = _history.where((h) {
      if (h['status'] != 'pending' && h['status'] != 'confirmed') return false;
      final dt = DateTime.parse(h['date']).toLocal();
      final endTime = dt.add(const Duration(hours: 2));
      return now.isBefore(endTime);
    }).toList();
    
    upcomingList.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
    
    if (upcomingList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: upcomingList.map((h) {
        final dt = DateTime.parse(h['date']).toLocal();
        final dateStr = DateFormat('MMMM d, yyyy').format(dt);
        String timeSlot = '${dt.hour}:00';
        if (dt.hour == 9) timeSlot = '9:00 AM – 11:00 AM';
        else if (dt.hour == 11) timeSlot = '11:00 AM – 1:00 PM';
        else if (dt.hour == 14) timeSlot = '2:00 PM – 4:00 PM';
        else if (dt.hour == 16) timeSlot = '4:00 PM – 6:00 PM';

        return GestureDetector(
          onTap: () async {
            if (h['bankLat'] == null || h['bankLng'] == null) return;
            final lat = (h['bankLat'] as num).toDouble();
            final lng = (h['bankLng'] as num).toDouble();
            final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
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
                        '${h['bloodBankName']} at $timeSlot\nTap to get directions.',
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
      }).toList(),
    );
  }

  List<Widget> _buildHistoryList() {
    if (_history.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'No donations yet. Become a hero today!',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        )
      ];
    }

    return _history.map((h) {
      final dt = DateTime.parse(h['date']);
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Text(
              h['bloodGroup'],
              style: TextStyle(
                color: Colors.red.shade900, 
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            h['bloodBankName'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(DateFormat('MMM d, yyyy • h:mm a').format(dt)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${h['units']} Unit(s)',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                h['status'] == 'pending' ? 'Scheduled' :
                h['status'] == 'confirmed' ? 'Confirmed' :
                h['status'] == 'donated' ? 'Donated' :
                h['status'] == 'no_show' ? 'Missed' :
                h['status'] ?? 'Unknown',
                style: TextStyle(
                  fontSize: 12, 
                  color: h['status'] == 'pending' ? Colors.blue.shade700 :
                         h['status'] == 'confirmed' ? Colors.orange.shade700 :
                         h['status'] == 'donated' ? Colors.green.shade700 : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
