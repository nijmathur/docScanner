import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/session_service.dart';
import '../../auth/screens/auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _documentCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final dbService = context.read<DatabaseService>();
      final count = await dbService.getDocumentCount();

      setState(() {
        _documentCount = count;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final authService = context.read<AuthService>();
        final sessionService = context.read<SessionService>();

        // Clear session data (DEK)
        sessionService.clearSession();

        // Logout (clear last activity timestamp)
        await authService.logout();

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout error: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleDatabaseOptimization() async {
    try {
      final dbService = context.read<DatabaseService>();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      await dbService.optimize();

      if (mounted) {
        Navigator.pop(context); // Dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database optimized successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Optimization error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Statistics Section
                _buildSection(
                  title: 'Statistics',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: const Text('Total Documents'),
                      trailing: Text(
                        _documentCount.toString(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),

                const Divider(),

                // Storage Section
                _buildSection(
                  title: 'Storage',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cloud_upload),
                      title: const Text('Backup'),
                      subtitle: const Text('Create encrypted backup'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Backup feature coming soon'),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.cloud_download),
                      title: const Text('Restore'),
                      subtitle: const Text('Restore from backup'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Restore feature coming soon'),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.build),
                      title: const Text('Optimize Database'),
                      subtitle: const Text('Compact and optimize storage'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _handleDatabaseOptimization,
                    ),
                  ],
                ),

                const Divider(),

                // Security Section
                _buildSection(
                  title: 'Security',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock),
                      title: const Text('Change PIN'),
                      subtitle: const Text('Update your security PIN'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PIN change feature coming soon'),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.fingerprint),
                      title: const Text('Biometric Authentication'),
                      subtitle: const Text('Use biometrics to unlock'),
                      trailing: Switch(
                        value: false,
                        onChanged: (value) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Biometric feature coming soon'),
                            ),
                          );
                        },
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('Audit Log'),
                      subtitle: const Text('View security audit trail'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Audit log feature coming soon'),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const Divider(),

                // About Section
                _buildSection(
                  title: 'About',
                  children: [
                    const ListTile(
                      leading: Icon(Icons.info),
                      title: Text('Version'),
                      trailing: Text('1.0.0'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.description),
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Privacy policy coming soon'),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.gavel),
                      title: const Text('Terms of Service'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Terms of service coming soon'),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const Divider(),

                // Logout Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        ...children,
      ],
    );
  }
}
