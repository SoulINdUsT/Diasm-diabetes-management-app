
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppDrawer extends StatelessWidget {
  final bool isEnglish;
  const AppDrawer({super.key, required this.isEnglish});

  @override
  Widget build(BuildContext context) {
    String t(String en, String bn) => isEnglish ? en : bn;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(isEnglish: isEnglish),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(
  icon: Icons.person_outline,
  title: isEnglish ? 'Profile' : 'প্রোফাইল',
  onTap: () {
    Navigator.pop(context);
    context.go('/profile');
  },
),
const SizedBox(height: 6),

                  _DrawerItem(
                    icon: Icons.handyman_outlined,
                    title: t("Tools", "টুলস"),
                    onTap: () => _go(context, "/tools"),
                  ),
                  _DrawerItem(
                    icon: Icons.groups_2_outlined,
                    title: t("Community Hub", "কমিউনিটি হাব"),
                    onTap: () => _go(context, "/community"),
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    title: t("Settings", "সেটিংস"),
                    onTap: () => _go(context, "/settings"),
                  ),
                  const Divider(height: 8),
                  _DrawerItem(
                    icon: Icons.logout,
                    title: t("Logout", "লগ আউট"),
                    onTap: () => _logout(context),
                    isDestructive: true,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "DIAsm v1.0",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String route) {
    Navigator.pop(context); // close drawer
    context.go(route);
  }

  void _logout(BuildContext context) {
    Navigator.pop(context);

    // If you already have signOut logic, call it here.
    // For demo:
    context.go("/login");
  }
}

class _DrawerHeader extends StatelessWidget {
  final bool isEnglish;
  const _DrawerHeader({required this.isEnglish});

  @override
  Widget build(BuildContext context) {
    String t(String en, String bn) => isEnglish ? en : bn;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.favorite, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t("DIAsm Diabetes App", "ডায়াবেটিস অ্যাপ DIAsm"),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  t("Self-Management Companion", "স্ব-ব্যবস্থাপনা সহকারী"),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
      horizontalTitleGap: 8,
    );
  }
}
