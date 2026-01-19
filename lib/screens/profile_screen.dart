import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'Dashboard_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';
import '../services/auth_service.dart';
import '../services/security_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _pickedImageBytes;

  Future<void> _pickImage() async {
    try {
      final xfile = await _picker.pickImage(source: ImageSource.gallery);
      if (xfile != null) {
        final bytes = await xfile.readAsBytes();
        setState(() => _pickedImageBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image pick error: $e')));
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> profile) async {
    final nameController = TextEditingController(
      text: profile['displayName'] as String?,
    );
    Uint8List? previewBytes = _pickedImageBytes;

    final res = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Profile'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final xfile = await _picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (xfile != null) {
                        final b = await xfile.readAsBytes();
                        setDialogState(() => previewBytes = b);
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[200],
                      foregroundImage: previewBytes != null
                          ? MemoryImage(previewBytes!)
                          : null,
                      child: previewBytes == null
                          ? const Icon(Icons.add_a_photo)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (res == true) {
      try {
        await AuthService().updateProfile(
          displayName: nameController.text.trim(),
          photoBytes: previewBytes,
          photoFilename: 'profile.jpg',
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Profile updated')));
        }
        setState(() => _pickedImageBytes = null);
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: AuthService().getCurrentUserProfile(),
      builder: (context, snapshot) {
        final profile =
            snapshot.data ??
            {
              'displayName': 'User Name',
              'email': 'demo@local',
              'photoUrl': null,
            };

        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: profile['photoUrl'] != null
                        ? NetworkImage(profile['photoUrl'] as String)
                        : (profile['photoData'] != null
                                  ? MemoryImage(
                                      base64Decode(
                                        profile['photoData'] as String,
                                      ),
                                    )
                                  : null)
                              as ImageProvider<Object>?,
                    child:
                        (profile['photoUrl'] == null &&
                            profile['photoData'] == null)
                        ? Text(
                            (profile['displayName'] as String?)
                                    ?.substring(0, 1)
                                    .toUpperCase() ??
                                'U',
                            style: const TextStyle(
                              fontSize: 30,
                              color: Colors.green,
                            ),
                          )
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () => _showEditDialog(profile),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(
                  profile['displayName'] as String? ?? 'User Name',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                subtitle: Text(
                  profile['email'] as String? ?? 'Unknown',
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(),
              _buildProfileOption(
                context,
                Icons.history,
                'My Reports',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                ),
              ),
              _buildProfileOption(
                context,
                Icons.settings,
                'App Settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              _buildProfileOption(
                context,
                Icons.help_outline,
                'Help & Feedback',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                ),
              ),
              _buildProfileOption(
                context,
                Icons.logout,
                'Logout',
                textColor: Colors.red,
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Confirm logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );

                  if (confirm != true) return;

                  try {
                    await AuthService().signOut();
                  } catch (e) {
                    print('Sign-out error (non-fatal): $e');
                  }

                  try {
                    await SecurityService.clearAllSecureData();
                  } catch (_) {}

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (r) => false,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileOption(
    BuildContext context,
    IconData icon,
    String title, {
    Color? textColor,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
