import 'dart:convert';
import 'dart:io' show File, Directory, Platform;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../shared/theme_controller.dart';
import '../services/report_service.dart';
import '../services/security_service.dart';
import 'change_password_screen.dart';

/// Lightweight App Settings screen (expand later).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _mode;
  bool _analyticsOptIn = false;
  bool _savingExport = false;
  static const _analyticsKey = 'analytics_opt_in_v1';

  @override
  void initState() {
    super.initState();
    _mode = ThemeController.instance.mode;
    ThemeController.instance.addListener(_onThemeChanged);
    _loadAnalyticsPref();
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (!mounted) return;
    setState(() => _mode = ThemeController.instance.mode);
  }

  Future<void> _setMode(ThemeMode m) async {
    await ThemeController.instance.setMode(m);
  }

  Future<void> _loadAnalyticsPref() async {
    try {
      final v = await SecurityService.getSecureData(_analyticsKey);
      if (!mounted) return;
      setState(() => _analyticsOptIn = (v == '1' || v == 'true'));
    } catch (_) {
      // ignore (plugin may not be available in tests)
    }
  }

  Future<void> _setAnalytics(bool v) async {
    setState(() => _analyticsOptIn = v);
    try {
      await SecurityService.storeSecureData(_analyticsKey, v ? '1' : '0');
    } catch (e) {
      debugPrint('Failed to persist analytics preference: $e');
    }
  }

  Future<void> _exportReports() async {
    setState(() => _savingExport = true);
    try {
      final json = await ReportService().exportUserReportsJson();

      // attach live prefs
      final payload = jsonDecode(json) as Map<String, dynamic>;
      payload['meta']['themeMode'] = ThemeController.instance.mode.toString();
      payload['meta']['analyticsOptIn'] = _analyticsOptIn ? '1' : '0';
      final finalJson = const JsonEncoder.withIndent('  ').convert(payload);

      // web: use Anchor download
      if (kIsWeb) {
        // Use a data: URL so we don't need dart:html imports (works across browsers).
        final url =
            'data:application/json;charset=utf-8,${Uri.encodeComponent(finalJson)}';
        try {
          // protect test harness from blocking platform calls
          await launchUrlString(
            url,
          ).timeout(const Duration(milliseconds: 300), onTimeout: () => false);
        } catch (e) {
          debugPrint('Could not open data URL for download: $e');
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opened JSON in a new tab — use Save As to persist'),
          ),
        );
        return;
      }

      // non-web: try Downloads folder first (desktop), otherwise system temp.
      await Clipboard.setData(ClipboardData(text: finalJson));

      try {
        String? downloadsDirPath;
        try {
          if (!kIsWeb) {
            if (Platform.isWindows) {
              downloadsDirPath = Platform.environment['USERPROFILE'] != null
                  ? '${Platform.environment['USERPROFILE']}\\Downloads'
                  : null;
            } else if (Platform.isMacOS || Platform.isLinux) {
              downloadsDirPath = Platform.environment['HOME'] != null
                  ? '${Platform.environment['HOME']}/Downloads'
                  : null;
            }
          }
        } catch (e) {
          downloadsDirPath = null;
        }

        if (downloadsDirPath != null) {
          final d = Directory(downloadsDirPath);
          if (await d.exists()) {
            final out = File(
              '${d.path}${Platform.pathSeparator}ethio_reports_${DateTime.now().millisecondsSinceEpoch}.json',
            );
            await out.writeAsString(finalJson);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Export saved to ${out.path} (also copied to clipboard)',
                ),
                action: SnackBarAction(
                  label: 'Open folder',
                  onPressed: () async {
                    try {
                      await launchUrlString(Uri.file(d.path).toString());
                    } catch (_) {}
                  },
                ),
              ),
            );
            return;
          }
        }

        // fallback to system temp
        final tmp = Directory.systemTemp;
        final out = File(
          '${tmp.path}${Platform.pathSeparator}ethio_reports_${DateTime.now().millisecondsSinceEpoch}.json',
        );
        await out.writeAsString(finalJson);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export copied to clipboard and saved to ${out.path}',
            ),
            action: SnackBarAction(
              label: 'Show',
              onPressed: () async {
                if (!mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Export JSON'),
                    content: SingleChildScrollView(
                      child: SelectableText(finalJson),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: finalJson),
                          );
                          if (!mounted) return;
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                            ),
                          );
                        },
                        child: const Text('Copy'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        return;
      } catch (e) {
        debugPrint('Export write failed: $e');
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Export JSON'),
            content: SingleChildScrollView(child: SelectableText(finalJson)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: finalJson));
                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
                child: const Text('Copy'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e, st) {
      debugPrint('Export error: $e\n$st');
      if (!mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _savingExport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: const Text('App Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'General',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Theme selector
          ListTile(
            leading: const Icon(Icons.color_lens_outlined),
            title: const Text('Theme'),
            subtitle: Text(
              _mode == ThemeMode.system
                  ? 'System default'
                  : _mode == ThemeMode.dark
                  ? 'Dark'
                  : 'Light',
            ),
            trailing: DropdownButton<ThemeMode>(
              value: _mode,
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (v) {
                if (v == null) return;
                _setMode(v);
              },
            ),
          ),

          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Send anonymous usage statistics'),
            value: _analyticsOptIn,
            onChanged: (v) => _setAnalytics(v),
            secondary: const Icon(Icons.analytics),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy & Data'),
            subtitle: const Text('Manage location / photo permissions'),
            onTap: () async {
              // Open platform app settings where possible, show guidance on web
              try {
                if (Theme.of(context).platform == TargetPlatform.android ||
                    Theme.of(context).platform == TargetPlatform.iOS) {
                  // app-settings: works on mobile platforms
                  await launchUrlString('app-settings:');
                  return;
                }
              } catch (e) {
                debugPrint('Could not open app settings: $e');
              }

              // Fallback: show an instructions dialog (safe for web)
              if (!mounted) return;
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Privacy & Data'),
                  content: const Text(
                    'To change permissions: open your browser or OS settings → Privacy/Permissions → allow Location/Camera access for this site/app.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          const Text(
            'Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change password'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export my reports (JSON)'),
            trailing: _savingExport
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _exportReports,
          ),
        ],
      ),
    );
  }
}
