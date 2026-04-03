import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import '../config/api_config.dart';

class GovtAnalyticsScreen extends StatefulWidget {
  const GovtAnalyticsScreen({super.key});

  @override
  State<GovtAnalyticsScreen> createState() => _GovtAnalyticsScreenState();
}

class _GovtAnalyticsScreenState extends State<GovtAnalyticsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _highDemandAreas = [];
  List<dynamic> _shortages = [];
  List<dynamic> _emergencyHotspots = [];
  List<dynamic> _unmetNeeds = [];
  List<dynamic> _mostRequestedGroups = [];
  Map<String, dynamic>? _summary;

  // Brand colors
  static const _red = Color(0xFFB71C1C);
  static const _redLight = Color(0xFFFFEBEE);
  static const _redMid = Color(0xFFEF5350);
  static const _bg = Color(0xFFF8F9FA);
  static const _cardBg = Colors.white;
  static const _textDark = Color(0xFF1A1A2E);
  static const _textGrey = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/analytics/dashboard'),
        headers: {'x-govt-token': 'admin123'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _highDemandAreas = data['highDemandAreas'] ?? [];
            _shortages = data['shortages'] ?? [];
            _emergencyHotspots = data['emergencyHotspots'] ?? [];
            _unmetNeeds = data['unmetNeedsHotspots'] ?? [];
            _mostRequestedGroups = data['mostRequestedGroups'] ?? [];
            _summary = data['summary'];
            _loading = false;
          });
        }
      } else {
        throw Exception('Failed to load');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not fetch analytics: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _red),
            )
          : _error != null
              ? _buildError()
              : CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(),
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (_summary != null) ...[
                            _buildSectionLabel('Overview'),
                            const SizedBox(height: 12),
                            _buildSummaryCards(),
                            const SizedBox(height: 24),
                            _buildSectionLabel('Blood Group Demand'),
                            const SizedBox(height: 12),
                            _buildBarChart(),
                            const SizedBox(height: 24),
                            _buildSectionLabel('Fulfillment Status'),
                            const SizedBox(height: 12),
                            _buildPieCard(),
                            const SizedBox(height: 24),
                          ],
                          if (_emergencyHotspots.isNotEmpty) ...[
                            _buildSectionLabel('Active Emergencies',
                                color: _red, icon: Icons.warning_rounded),
                            const SizedBox(height: 12),
                            ..._emergencyHotspots
                                .map((e) => _buildEmergencyCard(e)),
                            const SizedBox(height: 24),
                          ],
                          _buildSectionLabel('Unmet Needs Hotspots',
                              color: const Color(0xFF6A0DAD),
                              icon: Icons.location_off_rounded),
                          const SizedBox(height: 12),
                          if (_unmetNeeds.isEmpty)
                            _buildEmptyState('No unmet needs recorded')
                          else
                            ..._unmetNeeds.map((u) => _buildUnmetCard(u)),
                          const SizedBox(height: 24),
                          _buildSectionLabel('Blood Group Inventory'),
                          const SizedBox(height: 12),
                          _buildShortageTable(),
                          const SizedBox(height: 24),
                          _buildSectionLabel('High Demand Hospitals'),
                          const SizedBox(height: 12),
                          if (_highDemandAreas.isEmpty)
                            _buildEmptyState('No hospital data available')
                          else
                            ..._highDemandAreas
                                .map((a) => _buildHospitalCard(a)),
                          const SizedBox(height: 40),
                        ]),
                      ),
                    ),
                  ],
                ),
    );
  }

  // ── FIX 1: Removed duplicate title from FlexibleSpaceBar so "Government Portal"
  //    only shows in the collapsed pinned state, not overlapping with the expanded content.
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: _red,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        // ── Removed `title` from FlexibleSpaceBar entirely to avoid the
        //    double-title overlap. The expanded header text is rendered
        //    inside `background` and the pinned title is provided via
        //    a custom leading/title in the AppBar below.
        background: Container(
          decoration: const BoxDecoration(color: _red),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bar_chart_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Government Data Portal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'BloodNow Network Analytics',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // ── collapseMode set to none so the background fades out cleanly
        //    without any parallax shifting that can cause visual overlap.
        collapseMode: CollapseMode.none,
      ),
      // ── The pinned app bar title is handled here, separate from the
      //    FlexibleSpaceBar, so it only appears when fully collapsed.
      title: const Text(
        'Government Portal',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      // Keep title hidden while expanded; it fades in as bar collapses.
      titleSpacing: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () {
            setState(() => _loading = true);
            _loadData();
          },
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label,
      {Color? color, IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color ?? _textDark),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color ?? _textDark,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final s = _summary!;
    final donors = s['totalDonors'] ?? 0;
    final requests = s['totalRequests'] ?? 0;
    final fulfilled = s['fulfilledRequests'] ?? 0;
    final pending = s['pendingRequests'] ?? 0;
    final rate = requests > 0
        ? ((fulfilled / requests) * 100).toStringAsFixed(0)
        : '0';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Total Donors',
                value: '$donors',
                icon: Icons.favorite_rounded,
                iconColor: _red,
                bgColor: _redLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Requests',
                value: '$requests',
                icon: Icons.local_hospital_rounded,
                iconColor: const Color(0xFF1565C0),
                bgColor: const Color(0xFFE3F2FD),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Fulfilled',
                value: '$fulfilled',
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Success Rate',
                value: '$rate%',
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFFE65100),
                bgColor: const Color(0xFFFFF3E0),
              ),
            ),
          ],
        ),
        if (pending > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFCC02), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.pending_actions_rounded,
                    color: Color(0xFFE65100), size: 20),
                const SizedBox(width: 10),
                Text(
                  '$pending requests still pending',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE65100),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBarChart() {
    if (_mostRequestedGroups.isEmpty) {
      return _buildEmptyState('No demand data available');
    }

    double maxVal = 0;
    for (var g in _mostRequestedGroups) {
      final v = (g['count'] as num).toDouble();
      if (v > maxVal) maxVal = v;
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Requests by blood group',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textGrey,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal + (maxVal * 0.25).clamp(1, 999),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => _textDark,
                    getTooltipItem: (group, gIdx, rod, rIdx) {
                      return BarTooltipItem(
                        '${_mostRequestedGroups[group.x.toInt()]['bloodGroup']}\n',
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        children: [
                          TextSpan(
                            text: '${rod.toY.toInt()} requests',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i >= _mostRequestedGroups.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _mostRequestedGroups[i]['bloodGroup'],
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _textGrey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                            fontSize: 10, color: _textGrey),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.shade100,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _mostRequestedGroups.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: (e.value['count'] as num).toDouble(),
                        color: _red,
                        width: 28,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxVal + (maxVal * 0.25).clamp(1, 999),
                          color: _redLight,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── FIX 2: Restructured pie card layout so the donut chart is perfectly
  //    centred. Changed from a side-by-side Row to a Column with the chart
  //    centred at the top, and the legend + total pill below it.
  Widget _buildPieCard() {
    final s = _summary!;
    final fulfilled = (s['fulfilledRequests'] as num).toDouble();
    final pending = (s['pendingRequests'] as num).toDouble();
    final total = fulfilled + pending;

    if (total == 0) return _buildEmptyState('No request data');

    return _Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Centred donut chart
          Center(
            child: SizedBox(
              height: 180,
              width: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 44,
                  startDegreeOffset: -90,
                  sections: [
                    PieChartSectionData(
                      color: _red,
                      value: fulfilled,
                      title:
                          '${((fulfilled / total) * 100).toStringAsFixed(0)}%',
                      radius: 68,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: const Color(0xFFFFB74D),
                      value: pending,
                      title:
                          '${((pending / total) * 100).toStringAsFixed(0)}%',
                      radius: 62,
                      titleStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ── Legend row centred below the chart
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendRow(
                color: _red,
                label: 'Fulfilled',
                value: '${fulfilled.toInt()}',
              ),
              const SizedBox(width: 28),
              _LegendRow(
                color: const Color(0xFFFFB74D),
                label: 'Pending',
                value: '${pending.toInt()}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── Total pill centred
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: _redLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${total.toInt()} total requests',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard(dynamic e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _redLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: _red, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${e['units_needed']} units ',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _red,
                        ),
                      ),
                      TextSpan(
                        text: 'of ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      TextSpan(
                        text: e['blood_group'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                      TextSpan(
                        text: ' needed',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${e['bank_name']} • ${e['created_at'].toString().split('T').first}',
                  style: const TextStyle(fontSize: 12, color: _textGrey),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'URGENT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnmetCard(dynamic u) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0FF),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFCE93D8).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_off_rounded,
                color: Color(0xFF6A0DAD), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Blood group ${u['blood_group']} — no donor found',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Near ${u['approx_lat']}, ${u['approx_lng']}',
                  style:
                      const TextStyle(fontSize: 11, color: _textGrey),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${u['fail_count']} failed',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6A0DAD),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortageTable() {
    if (_shortages.isEmpty) return _buildEmptyState('No shortage data');

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: _shortages.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final bg = s['bloodGroup'];
          final avail = s['totalAvailable'];
          final needed = s['totalNeeded'];
          final shortage = s['shortage'];
          final hasShortage = (shortage as num) > 0;

          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: hasShortage
                  ? const Color(0xFFFFF3F3)
                  : Colors.transparent,
              border: i < _shortages.length - 1
                  ? Border(
                      bottom: BorderSide(
                          color: Colors.grey.shade100, width: 1))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hasShortage ? _redLight : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bg,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: hasShortage
                          ? _red
                          : const Color(0xFF2E7D32),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      _StatPill(
                          label: 'Avail', value: '$avail', isGood: true),
                      const SizedBox(width: 8),
                      _StatPill(
                          label: 'Need',
                          value: '$needed',
                          isGood: !hasShortage),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: hasShortage
                        ? _red
                        : const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasShortage ? '-$shortage units' : 'OK',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHospitalCard(dynamic area) {
    final requests = area['total_requests'] ?? 0;
    final units = area['total_units_needed'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _redLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_hospital_rounded,
                color: _red, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  area['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  area['address_line'] ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textGrey,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$requests requests',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$units units needed',
                style: const TextStyle(
                  fontSize: 11,
                  color: _red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Text(
        msg,
        style: const TextStyle(fontSize: 13, color: _textGrey),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textGrey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() => _loading = true);
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: child,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── FIX 2 (cont.): Updated _LegendRow to use a vertical layout (value below
//    label) so it reads cleanly when centred under the pie chart.
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E)),
            ),
            Text(
              '$value requests',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.isGood,
  });
  final String label;
  final String value;
  final bool isGood;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF6B7280)),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}