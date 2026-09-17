import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:schuly_api/schuly_api.dart';

import '../../config/oidc_config.dart';
import '../../domain/student_id.dart';
import '../../services/active_account_service.dart';
import '../../services/api_client.dart';
import '../../services/api_error.dart';
import '../../services/app_mode_service.dart';
import '../../services/demo_data.dart';
import '../../services/school_data_service.dart';
import '../../services/toast_service.dart';
import '../authenticator/authenticator_vault_screen.dart';
import '../core/dates.dart';
import '../core/ui/accents.dart';
import '../core/ui/dense_tile.dart';
import '../core/ui/section_header.dart';
import '../documents/documents_page.dart';
import '../settings/settings_screen.dart';
import 'classes_screen.dart';
import 'student_id_card.dart';
import 'teachers_screen.dart';

class AccountPage extends StatefulWidget {
  final String? pictureUrl;
  final String? userName;
  final VoidCallback onSignOut;
  const AccountPage({super.key, required this.pictureUrl, required this.userName, required this.onSignOut});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> with SingleTickerProviderStateMixin {
  String? _version;
  bool _syncing = false;
  String? _syncMsg;
  DateTime? _lastSync;
  String? _syncStatus;
  String? _syncError;
  late final AnimationController _idAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 420), reverseDuration: const Duration(milliseconds: 320));
  final _tileKey = GlobalKey();
  final _avatarKey = GlobalKey();
  OverlayEntry? _idEntry;
  static const _dragSpan = 160.0;

  bool get _idOpen => _idEntry != null;

  void _showId(StudentIdCard card, Widget Function(bool hideShared) tileBuilder, String initial) {
    if (_idEntry != null) return;
    Rect rectOf(GlobalKey key) {
      final box = key.currentContext!.findRenderObject() as RenderBox;
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final from = TileGeometry(tile: rectOf(_tileKey), avatar: rectOf(_avatarKey));
    _idEntry = OverlayEntry(
      builder: (_) => StudentIdOverlay(
        animation: _idAnim,
        from: from,
        tileBuilder: tileBuilder,
        card: card,
        initial: initial,
        onClose: _closeId,
        onDragUpdate: (dy) => _idAnim.value = (_idAnim.value + dy / _dragSpan).clamp(0.0, 1.0),
        onDragEnd: (v) => v < -300 || (_idAnim.value < 0.65 && v <= 300) ? _closeId() : _idAnim.forward(),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_idEntry!);
    setState(() {});
  }

  void _openId(StudentIdCard card, Widget Function(bool hideShared) tileBuilder, String initial) {
    _showId(card, tileBuilder, initial);
    _idAnim.forward();
  }

  void _closeId() {
    _idAnim.reverse().whenComplete(() {
      if (_idAnim.value > 0) return;
      _idEntry?.remove();
      _idEntry = null;
      if (mounted) setState(() {});
    });
  }

  void _pullUpdate(double dy, StudentIdCard card, Widget Function(bool hideShared) tileBuilder, String initial) {
    _showId(card, tileBuilder, initial);
    _idAnim.value = (_idAnim.value + dy / _dragSpan).clamp(0.0, 1.0);
  }

  void _pullEnd(double velocity) {
    if (_idEntry == null) return;
    if (velocity > 300 || _idAnim.value > 0.3) {
      _idAnim.forward();
    } else {
      _closeId();
    }
  }

  @override
  void dispose() {
    _idEntry?.remove();
    _idAnim.dispose();
    super.dispose();
  }

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

    final profileCard = me == null ? null : StudentIdCard.fromProfile(me, schoolName: ActiveAccountService.instance.active?.fullName ?? me.schoolName, photoUrl: avatarUrl);
    final card = profileCard != null && DemoData.enabled ? DemoData.studentId(profileCard) : profileCard;
    Widget buildTile({Key? key, bool keyed = false, bool hideShared = false}) => Container(
              key: key,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.background,
                border: Border.all(color: colors.border),
                borderRadius: context.theme.style.borderRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Opacity(
                        opacity: hideShared ? 0 : 1,
                        child: KeyedSubtree(
                          key: keyed ? _avatarKey : null,
                          child: (avatarUrl == null || avatarUrl.isEmpty)
                              ? FAvatar.raw(size: 64, child: fallback)
                              : FAvatar(size: 64, image: NetworkImage(avatarUrl), fallback: fallback),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fullName.isEmpty ? 'Account' : fullName, style: typography.lg.copyWith(fontWeight: FontWeight.w800)),
                            if (me?.schoolName?.isNotEmpty ?? false)
                              Text(me!.schoolName!, style: typography.sm.copyWith(color: colors.mutedForeground), overflow: TextOverflow.ellipsis),
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
                  if (me != null) ...[
                    const SizedBox(height: 12),
                    FDivider(style: (s) => s.copyWith(padding: EdgeInsets.zero)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(FIcons.idCard, size: 16, color: colors.mutedForeground),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Student ID', style: typography.sm.copyWith(fontWeight: FontWeight.w600))),
                        Text('Tap or swipe down', style: typography.xs.copyWith(color: colors.mutedForeground)),
                        const SizedBox(width: 4),
                        Icon(FIcons.chevronDown, size: 16, color: colors.mutedForeground),
                      ],
                    ),
                  ],
                ],
              ),
            );

    Widget pushedAside(Widget child) => AnimatedBuilder(
          animation: _idAnim,
          builder: (context, _) {
            final t = Curves.easeInOutCubic.transform(_idAnim.value);
            return Opacity(opacity: 1 - t, child: Transform.translate(offset: Offset(0, 120 * t), child: child));
          },
        );

    return PopScope(
      canPop: !_idOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeId();
      },
      child: RefreshIndicator(
      onRefresh: () async {
        await svc.refresh();
        await _loadVersion();
        await _loadSyncStatus();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          GestureDetector(
            onTap: card == null ? null : () => _openId(card, (hide) => buildTile(hideShared: hide), initial),
            onVerticalDragUpdate: card == null ? null : (d) => _pullUpdate(d.delta.dy, card, (hide) => buildTile(hideShared: hide), initial),
            onVerticalDragEnd: card == null ? null : (d) => _pullEnd(d.primaryVelocity ?? 0),
            onVerticalDragCancel: () => _pullEnd(0),
            child: Opacity(opacity: _idOpen ? 0 : 1, child: buildTile(key: _tileKey, keyed: true)),
          ),
          for (final w in <Widget>[
          const SizedBox(height: 20),
          FTileGroup(
            divider: FItemDivider.full,
            children: [
              if (classes.isNotEmpty)
                FTile(
                  prefix: const Icon(FIcons.bookOpen),
                  title: const Text('Classes'),
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
          ])
            pushedAside(w),
        ],
      ),
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
      style: denseTileStyle,
      prefix: Icon(icon, size: 18, color: colors.mutedForeground),
      title: Text(has ? value! : 'No $label', maxLines: 1, overflow: TextOverflow.ellipsis, style: has ? null : TextStyle(color: colors.mutedForeground)),
    );
  }
}
