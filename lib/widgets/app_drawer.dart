import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/estimates_screen.dart';
import '../screens/items_screen.dart';
import '../screens/pending_screen.dart';
import '../screens/profile_screen.dart';
import 'staff_avatar.dart';

/// Side menu for everything that is not on the bottom bar. A new module
/// (expenses, credit notes, ...) is one more [_DrawerTile] below.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).pop(); // close the drawer
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final cs = Theme.of(context).colorScheme;
    final name = auth.userName.isEmpty ? 'Staff' : auth.userName;

    return Drawer(
      child: Column(
        children: [
          InkWell(
            onTap: () => _open(context, const ProfileScreen()),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  16, MediaQuery.of(context).padding.top + 14, 12, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [cs.primary, const Color(0xFF1A5FD0)],
                ),
              ),
              child: Row(
                children: [
                  StaffAvatar(
                    name: name,
                    path: auth.avatarPath,
                    radius: 24,
                    background: Colors.white.withValues(alpha: 0.2),
                    foreground: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const Text('View & edit profile',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white70),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              children: [
                const _SectionLabel('SALES'),
                _DrawerTile(
                  icon: Icons.request_quote_outlined,
                  color: const Color(0xFF7C3AED),
                  title: 'Estimates',
                  subtitle: 'Quotes sent to customers',
                  onTap: () => _open(context, const EstimatesScreen()),
                ),
                _DrawerTile(
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFFF59E0B),
                  title: 'Pending',
                  subtitle: 'Payments still to collect',
                  onTap: () => _open(context, const PendingScreen()),
                ),
                if (auth.canViewItems) ...[
                  const SizedBox(height: 6),
                  const _SectionLabel('CATALOG'),
                  _DrawerTile(
                    icon: Icons.inventory_2_outlined,
                    color: cs.primary,
                    title: 'Items',
                    subtitle: 'Products, rates and taxes',
                    onTap: () => _open(context, const ItemsScreen()),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
                12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
            child: _DrawerTile(
              icon: Icons.logout,
              color: cs.error,
              title: 'Logout',
              onTap: () {
                Navigator.of(context).pop();
                auth.logout();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
      child: Text(text,
          style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600)),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
