import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants.dart';
import '../../utils/app_constants.dart' as app_utils;
import '../login/login_screen.dart';

class UserScreen extends StatelessWidget {
  const UserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDark ? bgColor : Colors.grey.shade100,
            isDark ? bgColor.withOpacity(0.8) : Colors.grey.shade50,
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Profile Avatar
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.person,
                  size: 64,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              
              // User Status
              if (auth.isVisitor) ...[
                Text(
                  'Visitor Mode',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are browsing as a guest',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ] else if (user != null) ...[
                Text(
                  'Welcome Back!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.email ?? 'User',
                  style: TextStyle(
                    fontSize: 16,
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // User Info Card
              Card(
                color: isDark ? secondaryColor : Colors.white,
                margin: const EdgeInsets.symmetric(horizontal: 32),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (auth.isVisitor) ...[
                        _buildInfoRow(
                          icon: Icons.info_outline,
                          label: 'Status',
                          value: 'Guest User',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: Icons.access_time,
                          label: 'Access Level',
                          value: 'Limited Features',
                          isDark: isDark,
                        ),
                      ] else if (user != null) ...[
                        _buildUidRow(
                          uid: user.id,
                          isDark: isDark,
                          context: context,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: user.email ?? 'Not provided',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: Icons.verified_user_outlined,
                          label: 'Email Verified',
                          value: user.emailConfirmedAt != null ? 'Yes' : 'No',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Member Since',
                          value: user.createdAt != null 
                              ? app_utils.DateUtils.formatDateString(user.createdAt!)
                              : 'Unknown',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: Icons.login_outlined,
                          label: 'Last Login',
                          value: user.lastSignInAt != null 
                              ? app_utils.DateUtils.formatDateString(user.lastSignInAt!)
                              : 'Unknown',
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    if (auth.isAuthenticated) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await auth.signOut();
                              if (context.mounted) {
                                // Explicitly navigate to login screen and clear navigation stack
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                  (route) => false, // Remove all routes from stack
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Signed out successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Sign out failed: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ] else if (auth.isVisitor) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            auth.signOut(); // This will reset visitor mode
                            if (context.mounted) {
                              // Explicitly navigate to login screen and clear navigation stack
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                                (route) => false, // Remove all routes from stack
                              );
                            }
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Sign In to Account'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: primaryColor,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              SelectableText(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUidRow({
    required String uid,
    required bool isDark,
    required BuildContext context,
  }) {
    return Row(
      children: [
        Icon(
          Icons.fingerprint_outlined,
          color: primaryColor,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User ID',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      uid,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: uid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('User ID copied to clipboard'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.copy,
                      size: 16,
                      color: primaryColor,
                    ),
                    tooltip: 'Copy full User ID',
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }


} 