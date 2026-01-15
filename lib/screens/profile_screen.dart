import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../providers/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header with Avatar
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 3),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: theme.primaryColor.withOpacity(0.1),
                      child: user.photoURL != null
                          ? ClipOval(
                              child: Image.network(
                                user.photoURL!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Icon(Icons.person, size: 50, color: theme.primaryColor),
                              ),
                            )
                          : Icon(Icons.person, size: 50, color: theme.primaryColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(user.displayName ?? 'User', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(user.email ?? (user.isAnonymous ? 'Anonymous User' : 'No email'), style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                  if (user.isAnonymous) ...[
                    const SizedBox(height: 8),
                    Chip(label: const Text('Anonymous'), backgroundColor: theme.primaryColor.withOpacity(0.1)),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Account Section
            _buildSection(context, 'Account', [
              _buildTile(Icons.person_outline, 'Account', 'Manage your account settings', trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: () => _openAccountScreen(context, ref, user)),
            ]),

            // Subscription Section
            _buildSection(context, 'Subscription & Billing', [
              _buildTile(Icons.card_membership, 'Subscription', 'View plans and billing', trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: () => _openSubscriptionScreen(context)),
            ]),

            // Privacy & Data Section
            _buildSection(context, 'Privacy & Data', [
              _buildTile(Icons.privacy_tip_outlined, 'Privacy', 'Data and privacy settings', trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: () => _openPrivacyScreen(context, ref)),
            ]),

            // App Info Section
            _buildSection(context, 'App Info & Support', [
              _buildTile(Icons.info_outline, 'App Info', 'Version, help, and support', trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: () => _openAppInfoScreen(context)),
            ]),

            const SizedBox(height: 24),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _logout(context, ref),
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text('Log Out', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  Text('Split Trip v1.0.0', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('© 2025 Safwan Khan. All rights reserved.', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(left: 16.0, bottom: 8.0), child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey))),
          Card(elevation: 1, child: Column(children: children)),
        ],
      ),
    );
  }

  Widget _buildTile(IconData icon, String title, String? subtitle, {Widget? trailing, VoidCallback? onTap, Color? titleColor}) {
    return ListTile(
      leading: Icon(icon, color: titleColor),
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  void _logout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out successfully')));
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _openAccountScreen(BuildContext context, WidgetRef ref, User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AccountScreen(user: user, ref: ref),
      ),
    );
  }

  void _openSubscriptionScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const _SubscriptionScreen(),
      ),
    );
  }

  void _openPrivacyScreen(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PrivacyScreen(ref: ref),
      ),
    );
  }

  void _openAppInfoScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const _AppInfoScreen(),
      ),
    );
  }
}

// Account Screen
class _AccountScreen extends ConsumerWidget {
  final User user;
  final WidgetRef ref;

  const _AccountScreen({required this.user, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Display Name'),
            subtitle: Text(currentUser?.displayName ?? 'Not set'),
            trailing: const Icon(Icons.edit, size: 20),
            onTap: () => _editName(context, ref, currentUser),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Email'),
            subtitle: Text(currentUser?.email ?? (currentUser?.isAnonymous == true ? 'Anonymous User' : 'Not set')),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Account Created'),
            subtitle: Text(_formatDate(currentUser?.metadata.creationTime)),
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Last Sign In'),
            subtitle: Text(_formatDate(currentUser?.metadata.lastSignInTime)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) => date == null ? 'Unknown' : DateFormat('MMM dd, yyyy').format(date);

  void _editName(BuildContext context, WidgetRef ref, User? user) {
    if (user == null) return;

    // Always use the latest display name from the provider
    showDialog(
      context: context,
      builder: (ctx) {
        // Get the latest user from the provider inside the dialog
        final latestUser = ref.read(currentUserProvider);
        final controller = TextEditingController(text: latestUser?.displayName ?? '');
        return AlertDialog(
          title: const Text('Edit Display Name'),
          content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Display Name', border: OutlineInputBorder()), autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx);
                  // Update Firebase and reload user
                  await user.updateDisplayName(name);
                  await user.reload();
                  // Invalidate provider to refresh UI instantly
                  ref.invalidate(authStateProvider);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name updated')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

// Subscription Screen
class _SubscriptionScreen extends StatelessWidget {
  const _SubscriptionScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription & Billing')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.card_membership),
            title: const Text('Current Plan'),
            subtitle: const Text('Free'),
            trailing: const Chip(label: Text('FREE')),
          ),
          ListTile(
            leading: const Icon(Icons.upgrade),
            title: const Text('Upgrade to Pro'),
            subtitle: const Text('Unlock premium features'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showUpgrade(context),
          ),
          const ListTile(
            leading: Icon(Icons.receipt_long),
            title: Text('Invoices & Receipts'),
            subtitle: Text('No invoices yet'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ],
      ),
    );
  }

  void _showUpgrade(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upgrade to Pro'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pro features include:'),
            SizedBox(height: 12),
            ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text('Unlimited trips'), contentPadding: EdgeInsets.zero),
            ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text('Advanced analytics'), contentPadding: EdgeInsets.zero),
            ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text('Priority support'), contentPadding: EdgeInsets.zero),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Maybe Later')),
          FilledButton(onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon!'))); }, child: const Text('Upgrade Now')),
        ],
      ),
    );
  }
}

// Privacy Screen
class _PrivacyScreen extends StatelessWidget {
  final WidgetRef ref;

  const _PrivacyScreen({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Data')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Permanently delete your account'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _deleteAccount(context, ref),
          ),
        ],
      ),
    );
  }



  void _deleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚠️ Warning: This action cannot be undone!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('Deleting your account will:'),
            SizedBox(height: 8),
            Text('• Permanently delete all your trips'),
            Text('• Remove all expense records'),
            Text('• Delete your profile and settings'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () { Navigator.pop(ctx); _confirmDelete(context, ref); }, style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete Account')),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Type "DELETE" to confirm:'),
            const SizedBox(height: 16),
            TextField(controller: controller, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Type DELETE'), textCapitalization: TextCapitalization.characters),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim() == 'DELETE') {
                try {
                  await FirebaseAuth.instance.currentUser?.delete();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deleted')));
                } catch (e) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please type DELETE exactly')));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );
  }
}

// App Info Screen
class _AppInfoScreen extends StatelessWidget {
  const _AppInfoScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Info & Support')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('App Version'),
            subtitle: const Text('1.0.0 (Build 1)'),
            trailing: const Icon(Icons.copy, size: 16),
            onTap: () {
              Clipboard.setData(const ClipboardData(text: '1.0.0+1'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & FAQ'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showFAQ(context),
          ),
          const ListTile(
            leading: Icon(Icons.support_agent),
            title: Text('Contact Support'),
            subtitle: Text('Get help from our team'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
          ),
          const ListTile(
            leading: Icon(Icons.star),
            title: Text('Rate the App'),
            subtitle: Text('Share your feedback'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ],
      ),
    );
  }

  void _showFAQ(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help & FAQ'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How do I create a trip?', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Tap the + button on the trips screen.', style: TextStyle(color: Colors.grey)),
              SizedBox(height: 16),
              Text('How do I add expenses?', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Open a trip and tap "Add Expense".', style: TextStyle(color: Colors.grey)),
              SizedBox(height: 16),
              Text('How does splitting work?', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('You can split equally or customize amounts.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }
}
