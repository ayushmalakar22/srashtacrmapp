import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/animated_entry.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (mounted) Provider.of<AuthProvider>(context, listen: false).fetchPermissions();
    try {
      final data = await ApiService.getDashboardStats();
      if (data['status'] == true) {
        setState(() {
          _stats = data['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'] ?? 'Unknown error from API';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).logout();
      }
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => authProvider.logout(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedEntry(index: 0, child: _buildHero(theme, authProvider.userName)),
                    const SizedBox(height: 20),
                    if (_stats != null) _buildStats(theme),
                    if (_stats == null && _error != null)
                      Text(
                        'Error loading dashboard:\n$_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHero(ThemeData theme, String? userName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, const Color(0xFF1A5FD0)],
        ),
        boxShadow: [
          BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  '${userName ?? ''} 👋',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text("Here's how your business is doing", style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: const Icon(Icons.insights_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(ThemeData theme) {
    final s = _stats!;
    final cards = <_Stat>[
      _Stat('Active Customers', s['total_active_customers'], Icons.people_alt_outlined, theme.colorScheme.primary),
      _Stat('${s['unpaid_invoices_count']} Unpaid Invoices', s['unpaid_invoices_amount'], Icons.receipt_long_outlined, const Color(0xFFF9AB00), money: true),
      _Stat('${s['paid_invoices_count']} Paid Invoices', s['paid_invoices_amount'], Icons.check_circle_outline, const Color(0xFF34A853), money: true),
      _Stat('${s['overdue_invoices_count']} Overdue Invoices', s['overdue_invoices_amount'], Icons.warning_amber_rounded, theme.colorScheme.error, money: true),
      _Stat('${s['draft_invoices_count']} Draft Invoices', s['draft_invoices_amount'], Icons.edit_document, Colors.grey.shade600, money: true),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final cols = constraints.maxWidth >= 900 ? 4 : (constraints.maxWidth >= 600 ? 3 : 2);
        final cardWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < cards.length; i++)
              SizedBox(
                width: cardWidth,
                child: AnimatedEntry(index: i + 1, child: _buildStatCard(cards[i])),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(_Stat stat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(stat.icon, color: stat.color, size: 22),
          ),
          const SizedBox(height: 14),
          _CountUp(raw: stat.value, money: stat.money),
          const SizedBox(height: 4),
          Text(
            stat.title,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _Stat {
  final String title;
  final dynamic value;
  final IconData icon;
  final Color color;
  final bool money;
  const _Stat(this.title, this.value, this.icon, this.color, {this.money = false});
}

/// Number that counts up from zero when it first appears.
class _CountUp extends StatelessWidget {
  final dynamic raw;
  final bool money;
  const _CountUp({required this.raw, required this.money});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937));
    final target = double.tryParse(raw.toString());
    if (target == null) return Text(money ? '\$$raw' : raw.toString(), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(money ? '\$${v.toStringAsFixed(2)}' : v.round().toString(), style: style),
    );
  }
}
