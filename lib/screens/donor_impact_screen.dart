import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/session_store.dart';
import '../services/user_api.dart';

class DonorImpactScreen extends StatefulWidget {
  const DonorImpactScreen({super.key});

  @override
  State<DonorImpactScreen> createState() => _DonorImpactScreenState();
}

class _DonorImpactScreenState extends State<DonorImpactScreen> {
  final _session = SessionStore();
  bool _isLoading = true;
  String? _error;

  int _impactScore = 0;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadImpact();
  }

  Future<void> _loadImpact() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _session.getToken();
      if (token == null) throw Exception('Not logged in');

      final api = UserApi();
      final res = await api.getDonorImpact(token);
      api.close();

      if (res.isSuccess && res.data != null) {
        setState(() {
          _impactScore = res.data!['impactScore'] ?? 0;
          _notifications = res.data!['notifications'] ?? [];
        });
      } else {
        throw Exception(res.errorMessage ?? 'Failed to load impact details');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Impact'),
        backgroundColor: Colors.pink.shade600,
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
                        onPressed: _loadImpact,
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
      onRefresh: _loadImpact,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildScoreCard(),
          const SizedBox(height: 32),
          Text(
            'Impact History',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._buildNotificationsList(),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.pink.shade500, Colors.pink.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.shade200,
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.favorite, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          Text(
            '$_impactScore',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 64,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lives Saved',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          if (_impactScore > 0)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Thank you for being a hero! 🦸‍♀️🦸‍♂️',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildNotificationsList() {
    if (_notifications.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'No impact notifications yet. Your donation just might be next to save a life!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        )
      ];
    }

    return _notifications.map((n) {
      final dt = DateTime.parse(n['date']);
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_hospital_rounded, color: Colors.pink.shade600, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n['message'],
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('MMMM d, yyyy').format(dt) + ' at ' + n['bankName'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
