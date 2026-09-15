import 'package:flutter/material.dart' show showLicensePage, ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/backend_config.dart';
import '../../config/oidc_config.dart';
import '../../services/active_account_service.dart';
import '../../services/app_mode_service.dart';
import '../../services/auth_service.dart';
import '../../services/private_account_store.dart';
import '../../services/profile_refresh_requests.dart';
import '../../services/school_data_service.dart';
import '../../services/theme_service.dart';
import '../core/ui/section_header.dart';
import 'notification_settings_section.dart';
import 'privacy_settings_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final server = BackendConfig.isCustom ? BackendConfig.url : 'Schuly Cloud';

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Settings'),
        prefixes: [
          FHeaderAction.back(onPress: () => Navigator.of(context).pop()),
        ],
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.viewPaddingOf(context).bottom),
        children: [
          if (!AppModeService.instance.isPrivate) ...[
            const SectionHeader(icon: FIcons.circleUser, title: 'Account'),
            FTileGroup(
              divider: FItemDivider.full,
              children: [
                FTile(
                  prefix: const Icon(FIcons.userCog),
                  title: const Text('Manage account'),
                  subtitle: const Text('Profile, password & security'),
                  suffix: Icon(FIcons.externalLink, color: colors.mutedForeground),
                  onPress: _openAccountConsole,
                ),
                FTile(
                  prefix: const Icon(FIcons.image),
                  title: const Text('Profile picture'),
                  subtitle: const Text('Upload or change your picture'),
                  suffix: Icon(FIcons.externalLink, color: colors.mutedForeground),
                  onPress: _openProfilePicture,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          const SectionHeader(icon: FIcons.palette, title: 'Appearance'),
          AnimatedBuilder(
            animation: ThemeService.instance,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ThemeModePicker(
                  mode: ThemeService.instance.mode,
                  onChange: ThemeService.instance.setMode,
                ),
                const SizedBox(height: 12),
                _AccentPicker(
                  accent: ThemeService.instance.accent,
                  onChange: ThemeService.instance.setAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const NotificationSettingsSection(),
          const SectionHeader(icon: FIcons.server, title: 'Server'),
          FTileGroup(
            divider: FItemDivider.full,
            children: [
              FTile(
                prefix: Icon(BackendConfig.isCustom ? FIcons.server : FIcons.cloud),
                title: const Text('Backend server'),
                subtitle: Text(server),
                suffix: const Icon(FIcons.chevronRight),
                onPress: _openServerDialog,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const PrivacySettingsSection(),
          const SectionHeader(icon: FIcons.info, title: 'About'),
          FTileGroup(
            divider: FItemDivider.full,
            children: [
              FTile(
                prefix: const Icon(FIcons.bookOpen),
                title: const Text('Documentation'),
                subtitle: const Text('docs.schuly.dev'),
                suffix: Icon(FIcons.externalLink, color: colors.mutedForeground),
                onPress: () => launchUrl(Uri.parse('https://docs.schuly.dev/'), mode: LaunchMode.externalApplication),
              ),
              FTile(
                prefix: const Icon(FIcons.scrollText),
                title: const Text('Open-source licenses'),
                suffix: const Icon(FIcons.chevronRight),
                onPress: () => showLicensePage(context: context, applicationName: 'Schuly'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openAccountConsole() async {
    Uri? url;
    try {
      final cfg = await OidcConfig.settings();
      url = Uri.parse('${cfg.authority}/account');
    } catch (_) {
      url = null;
    }
    if (!mounted) return;
    if (url == null || !await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showFToast(context: context, title: const Text("Couldn't open the account page"));
      }
    }
  }

  Future<void> _openProfilePicture() async {
    Uri? url;
    try {
      final cfg = await OidcConfig.settings();
      url = Uri.parse('${cfg.authority}/avatar/ui');
    } catch (_) {
      url = null;
    }
    if (!mounted) return;
    if (url == null || !await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showFToast(context: context, title: const Text("Couldn't open the picture page"));
      }
      return;
    }
    ProfileRefreshRequests.request();
  }

  Future<void> _openServerDialog() async {
    final changed = await showFDialog<bool>(
      context: context,
      builder: (ctx, style, animation) => _ServerDialog(animation: animation),
    );
    if (changed != true || !mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class _ThemeModePicker extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChange;
  const _ThemeModePicker({required this.mode, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;

    Widget option(ThemeMode value, IconData icon, String label) {
      final selected = mode == value;
      return Expanded(
        child: FTappable(
          onPress: () => onChange(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? colors.primary : colors.background,
              border: Border.all(color: selected ? colors.primary : colors.border),
              borderRadius: context.theme.style.borderRadius,
            ),
            child: Column(
              children: [
                Icon(icon, size: 20, color: selected ? colors.primaryForeground : colors.mutedForeground),
                const SizedBox(height: 6),
                Text(label,
                    style: typography.xs.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected ? colors.primaryForeground : colors.foreground,
                    )),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(ThemeMode.system, FIcons.smartphone, 'System'),
        const SizedBox(width: 10),
        option(ThemeMode.light, FIcons.sun, 'Light'),
        const SizedBox(width: 10),
        option(ThemeMode.dark, FIcons.moon, 'Dark'),
      ],
    );
  }
}

class _AccentPicker extends StatelessWidget {
  final AppAccent accent;
  final ValueChanged<AppAccent> onChange;
  const _AccentPicker({required this.accent, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: context.theme.style.borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FIcons.paintbrush, size: 16, color: colors.mutedForeground),
              const SizedBox(width: 8),
              Text('Accent colour', style: typography.sm.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(accent.label, style: typography.sm.copyWith(color: colors.mutedForeground)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final a in AppAccent.values)
                FTappable(
                  onPress: () => onChange(a),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: a.swatch,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: a == accent ? colors.foreground : colors.border,
                        width: a == accent ? 2.5 : 1,
                      ),
                    ),
                    child: a == accent ? const Icon(FIcons.check, size: 18, color: Color(0xFFFFFFFF)) : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServerDialog extends StatefulWidget {
  final Animation<double> animation;
  const _ServerDialog({required this.animation});

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  bool _custom = BackendConfig.isCustom;
  late final _urlCtrl =
      TextEditingController(text: BackendConfig.isCustom ? BackendConfig.url : '');
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    String? url; // null = hosted
    if (_custom) {
      final raw = _urlCtrl.text.trim();
      final uri = Uri.tryParse(raw);
      final valid = raw.isNotEmpty &&
          uri != null &&
          (uri.isScheme('http') || uri.isScheme('https')) &&
          uri.host.isNotEmpty;
      if (!valid) {
        setState(() => _error = 'Enter a valid http(s) URL.');
        return;
      }
      if (BackendConfig.isInsecure(raw)) {
        setState(() => _error = null);
        return;
      }
      setState(() {
        _busy = true;
        _error = null;
      });
      final version = await BackendConfig.probe(raw);
      if (!mounted) return;
      if (version == null) {
        setState(() {
          _busy = false;
          _error = "Couldn't reach a Schuly backend at this URL.";
        });
        return;
      }
      url = raw;
    } else {
      if (!BackendConfig.isCustom) {
        Navigator.of(context).pop(false);
        return;
      }
      setState(() => _busy = true);
    }

    // Log out of the provider we are still pointed at - after the switch the
    // end-session call would land on the new backend's provider.
    await AuthService.signOut();
    await BackendConfig.setUrl(url);
    OidcConfig.reset();
    await PrivateAccountStore.instance.clear();
    await ActiveAccountService.instance.clear();
    SchoolDataService.instance.clear();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;

    Widget option(String label, String sub, bool selected, VoidCallback onTap) {
      return GestureDetector(
        onTap: _busy ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? FIcons.circleCheck : FIcons.circle,
                size: 20,
                color: selected ? colors.primary : colors.mutedForeground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(sub,
                        style: typography.xs
                            .copyWith(color: colors.mutedForeground)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FDialog(
      animation: widget.animation,
      title: const Text('Backend server'),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          option('Schuly Cloud', 'The official Schuly server', !_custom,
              () => setState(() {
                    _custom = false;
                    _error = null;
                  })),
          option('Self-hosted', 'Your own Schuly backend', _custom,
              () => setState(() => _custom = true)),
          if (_custom) ...[
            const SizedBox(height: 10),
            FTextField(
              control: FTextFieldControl.managed(controller: _urlCtrl),
              label: const Text('Backend URL'),
              hint: 'https://schuly.example.com',
              autocorrect: false,
            ),
            if (BackendConfig.isInsecure(_urlCtrl.text)) ...[
              const SizedBox(height: 6),
              Text(
                'Use https:// (http only works for localhost)',
                style: typography.xs.copyWith(color: colors.destructive),
              ),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: typography.sm.copyWith(color: colors.error)),
          ],
          const SizedBox(height: 12),
          Text('Changing the server signs you out.',
              style: typography.xs.copyWith(color: colors.mutedForeground)),
        ],
      ),
      actions: [
        FButton(
          style: FButtonStyle.outline(),
          onPress: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FButton(
          onPress: _busy ? null : _save,
          child: Text(_busy ? 'Checking...' : 'Save'),
        ),
      ],
    );
  }
}
