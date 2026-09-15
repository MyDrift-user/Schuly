import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:schuly_api/schuly_api.dart';

import '../../config/oidc_config.dart';
import '../../services/active_account_service.dart';
import '../../services/api_client.dart';
import '../../services/api_error.dart';
import '../../services/app_mode_service.dart';
import '../../services/school_data_service.dart';
import '../../services/toast_service.dart';
import '../authenticator/authenticator_vault_screen.dart';
import '../core/dates.dart';
import '../core/ui/accents.dart';
import '../core/ui/section_header.dart';
import '../documents/documents_page.dart';
import '../settings/settings_screen.dart';
import 'classes_screen.dart';
import 'teachers_screen.dart';

class AccountPage extends StatefulWidget {
  final String? pictureUrl;
  final String? userName;
  final VoidCallback onSignOut;
  const AccountPage({super.key, required this.pictureUrl, required this.userName, required this.onSignOut});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String? _version;
  bool _syncing = false;
  String? _syncMsg;
  DateTime? _lastSync;
  String? _syncStatus;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadSyncStatus();
  }

  Future<void> _loadSyncStatus() async {
    try {
      final active = ActiveAccountService.instance.active;
      final accountId = active?.pluginAccountId;
      final base = active?.pluginBasePath;
      if (accountId == null || base == null || base.isEmpty) return;
      final res = await ApiClient.instance.dio
          .get<Map<String, dynamic>>('$base/accounts/$accountId/sync');
      final data = res.data;
      if (!mounted || data == null) return;
      setState(() {
        final last = data['lastSync'];
        _lastSync = last is String ? DateTime.tryParse(last)?.toLocal() : null;
        _syncStatus = data['syncStatus']?.toString();
        _syncError = data['syncError']?.toString();
      });
    } catch (_) {}
  }

  Future<void> _loadVersion() async {
    try {
      final active = ActiveAccountService.instance.active;
      final base = active?.pluginBasePath;
      if (base == null || base.isEmpty) return;
      final res =
          await ApiClient.instance.dio.get<Map<String, dynamic>>('$base/status');
      final data = res.data;
      if (mounted) setState(() => _version = data?['version']?.toString());
    } catch (_) {}
  }

  Future<void> _syncNow() async {
    final active = ActiveAccountService.instance.active;
    if (active == null) {
      setState(() => _syncMsg = 'No connected account to sync');
      return;
    }
    final target = await ActiveAccountService.instance.resolvePluginTarget(active);
    if (target == null) {
      if (!mounted) return;
      setState(() => _syncMsg = 'No connected account to sync');
      return;
    }
    setState(() {
      _syncing = true;
      _syncMsg = null;
    });
    try {
      await ApiClient.instance.dio.post<dynamic>(
        '${target.basePath}/accounts/${target.accountId}/sync',
        options: ApiClient.handled(),
      );
      await SchoolDataService.instance.refresh();
      await _loadSyncStatus();
      if (mounted) setState(() => _syncMsg = 'Synced just now');
      ToastService.success('Synced', 'Fetched fresh data from the provider.');
    } catch (e) {
      // One path for every failure: the reason on the row, and a toast because
      // the user may have scrolled away from it.
      if (mounted) setState(() => _syncMsg = ApiError.describe(e));
      ToastService.error('Sync failed', e);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final svc = SchoolDataService.instance;
    final me = svc.me;
    final classes = me?.classes ?? const <UserClassDto>[];
    final isPrivate = AppModeService.instance.isPrivate;
    final hasPlugin = ActiveAccountService.instance.active?.pluginBasePath?.isNotEmpty ?? false;

    final fullName = me == null ? (widget.userName ?? '') : '${me.firstName} ${me.lastName}'.trim();
    final initial = fullName.isNotEmpty ? fullName.characters.first.toUpperCase() : '?';
    final fallback = Text(initial,
        style: typography.xl.copyWith(color: colors.mutedForeground, fontWeight: FontWeight.w700));
    final providerPfp = OidcConfig.resolveUrl(me?.profilePictureUrl);
    final avatarUrl = providerPfp ?? widget.pictureUrl;
    final address = [
      me?.street,
      [me?.zip, me?.city].where((s) => (s ?? '').isNotEmpty).join(' '),
    ].where((s) => (s ?? '').isNotEmpty).join(', ');

    return RefreshIndicator(
      onRefresh: () async {
        await svc.refresh();
        await _loadVersion();
        await _loadSyncStatus();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.background,
              border: Border.all(color: colors.border),
              borderRadius: context.theme.style.borderRadius,
            ),
            child: Row(
              children: [
                (avatarUrl == null || avatarUrl.isEmpty)
                    ? FAvatar.raw(size: 64, child: fallback)
                    : FAvatar(size: 64, image: NetworkImage(avatarUrl), fallback: fallback),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fullName.isEmpty ? 'Account' : fullName,
                          style: typography.lg.copyWith(fontWeight: FontWeight.w800)),
                      if (me?.schoolName?.isNotEmpty ?? false)
                        Text(me!.schoolName!,
                            style: typography.sm.copyWith(color: colors.mutedForeground),
                            overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FBadge(
                            style: FBadgeStyle.secondary(),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_roleIcon(me?.role), size: 12),
                                const SizedBox(width: 4),
                                Text(_roleLabel(me?.role)),
                              ],
                            ),
                          ),
                          if (isPrivate) ...[
                            const SizedBox(width: 6),
                            FBadge(
                              style: FBadgeStyle.outline(),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(FIcons.shieldCheck, size: 12),
                                  SizedBox(width: 4),
                                  Text('Private'),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FTileGroup(
            divider: FItemDivider.full,
            children: [
              if (classes.isNotEmpty)
                FTile(
                  prefix: const Icon(FIcons.bookOpen),
                  title: const Text('My classes'),
                  details: Text('${classes.length}'),
                  suffix: const Icon(FIcons.chevronRight),
                  onPress: () => _push(const ClassesScreen()),
                ),
              if (svc.teachers.isNotEmpty)
                FTile(
                  prefix: const Icon(FIcons.graduationCap),
                  title: const Text('Teachers'),
                  details: Text('${svc.teachers.length}'),
                  suffix: const Icon(FIcons.chevronRight),
                  onPress: () => _push(const TeachersScreen()),
                ),
              FTile(
                prefix: const Icon(FIcons.folder),
                title: const Text('Documents'),
                details: svc.documents.isNotEmpty ? Text('${svc.documents.length}') : null,
                suffix: const Icon(FIcons.chevronRight),
                onPress: () => _push(const DocumentsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FTileGroup(
            divider: FItemDivider.full,
            children: [
              FTile(
                prefix: const Icon(FIcons.keyRound),
                title: const Text('Authenticator'),
                suffix: const Icon(FIcons.chevronRight),
                onPress: () => _push(const AuthenticatorVaultScreen()),
              ),
              FTile(
                prefix: const Icon(FIcons.settings),
                title: const Text('Settings'),
                suffix: const Icon(FIcons.chevronRight),
                onPress: () => _push(const SettingsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeader(icon: FIcons.idCard, title: 'Contact details'),
          FTileGroup(
            divider: FItemDivider.full,
            children: [
              _InfoTile(icon: FIcons.mail, label: 'Email', value: me?.email),
              _InfoTile(icon: FIcons.phone, label: 'Phone', value: me?.phoneNumber),
              _InfoTile(icon: FIcons.mapPin, label: 'Address', value: address),
              _InfoTile(icon: FIcons.cake, label: 'Birthday', value: me?.birthday == null ? null : formatDate(fromApiDate(me!.birthday!))),
            ],
          ),
          if (hasPlugin) ...[
            const SizedBox(height: 24),
            const SectionHeader(icon: FIcons.refreshCw, title: 'Sync'),
            FTileGroup(
              divider: FItemDivider.full,
              children: [
                FTile(
                  prefix: _syncing ? const FCircularProgress() : const Icon(FIcons.refreshCw),
                  title: const Text('Sync now'),
                  subtitle: Text(_syncMsg ?? 'Fetch fresh data from the school'),
                  onPress: _syncing ? null : _syncNow,
                ),
                FTile(
                  prefix: Icon(
                    (_syncError?.isNotEmpty ?? false) ? FIcons.circleAlert : FIcons.circleCheck,
                    color: (_syncError?.isNotEmpty ?? false) ? Accent.red.color : Accent.green.color,
                  ),
                  title: const Text('Last sync'),
                  subtitle: (_syncError?.isNotEmpty ?? false)
                      ? Text(_syncError!, style: TextStyle(color: colors.destructive))
                      : (_syncStatus != null ? Text(_syncStatus!) : null),
                  details: Text(_lastSync != null ? timeAgo(_lastSync!) : 'Never'),
                ),
                if (_version != null)
                  FTile(
                    prefix: const Icon(FIcons.info),
                    title: const Text('Plugin version'),
                    details: Text(_version!),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          FButton(
            style: FButtonStyle.outline(),
            prefix: const Icon(FIcons.logOut),
            onPress: widget.onSignOut,
            child: Text(isPrivate ? 'Disconnect school' : 'Sign out'),
          ),
        ],
      ),
    );
  }

  static String _roleLabel(Roles? r) => switch (r) {
        Roles.teacher => 'Teacher',
        Roles.administrator => 'Administrator',
        _ => 'Student',
      };

  static IconData _roleIcon(Roles? r) => switch (r) {
        Roles.teacher => FIcons.graduationCap,
        Roles.administrator => FIcons.shield,
        _ => FIcons.backpack,
      };
}

class _InfoTile extends StatelessWidget with FTileMixin {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final has = value?.isNotEmpty ?? false;
    return FTile(
      prefix: Icon(icon),
      title: Text(label),
      subtitle: Text(has ? value! : 'Not set', style: has ? null : TextStyle(color: colors.mutedForeground)),
    );
  }
}
