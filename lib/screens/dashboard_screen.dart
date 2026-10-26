import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${authProvider.userName} 👋',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Stats Grid
                    if (_stats != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'Active Customers',
                              value: _stats!['total_active_customers'].toString(),
                              icon: Icons.people_alt_outlined,
                              color: theme.colorScheme.primary, // Logo Blue
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              title: '${_stats!['unpaid_invoices_count']} Unpaid Invoices',
                              value: '\$${_stats!['unpaid_invoices_amount']}',
                              icon: Icons.receipt_long_outlined,
                              color: theme.colorScheme.secondary, // Logo Yellow
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: '${_stats!['paid_invoices_count']} Paid Invoices',
                              value: '\$${_stats!['paid_invoices_amount']}',
                              icon: Icons.check_circle_outline,
                              color: const Color(0xFF34A853), // Logo Green
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              title: '${_stats!['overdue_invoices_count']} Overdue Invoices',
                              value: '\$${_stats!['overdue_invoices_amount']}',
                              icon: Icons.warning_amber_rounded,
                              color: theme.colorScheme.error, // Logo Red
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: '${_stats!['draft_invoices_count']} Draft Invoices',
                              value: '\$${_stats!['draft_invoices_amount']}',
                              icon: Icons.edit_document,
                              color: Colors.grey.shade600, 
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(child: SizedBox()), // Empty space to keep card size same
                        ],
                      ),
                    ],
                    if (_stats == null && _error != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Error loading dashboard:\n$_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
