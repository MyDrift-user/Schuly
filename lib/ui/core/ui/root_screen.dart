import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/active_account_service.dart';
import '../../../services/app_mode_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/demo_data.dart';
import '../../../services/onboarding_service.dart';
import '../../../services/private_account_store.dart';
import '../../../services/push_service.dart';
import '../../../services/school_data_service.dart';
import '../../dashboard/dashboard_screen.dart';
import '../../onboarding/onboarding_screen.dart';
import '../../private/private_connect_flow.dart';

/// Full sign-out: clears tokens, the active school, cached school data, and
/// any on-disk private-mode credentials, then drops the app back to account
/// mode. Shared by the sign-out action and account deletion.
Future<void> signOutAndClear() async {
  if (AppModeService.instance.isPrivate) {
    await PrivateAccountStore.instance.clear();
    await AppModeService.instance.setMode(AppMode.account);
  } else {
    // Delete the device on the backend before signing out, while the access
    // token is still valid.
    await PushService.instance.onSignOut();
    await AuthService.signOut();
    await ActiveAccountService.instance.clear();
  }
  SchoolDataService.instance.clear();
  await SchoolDataService.instance.clearCache();
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  bool? _ready; // signed in (account) or connected (private)
  bool _onboarded = true; // assume seen until loaded, to avoid a flash
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AuthService.sessionEpoch.addListener(_refresh);
    AppModeService.instance.addListener(_refresh);
    OnboardingService.seen().then((seen) {
      if (mounted) setState(() => _onboarded = seen);
    });
    _refresh();
  }

  @override
  void dispose() {
    AuthService.sessionEpoch.removeListener(_refresh);
    AppModeService.instance.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    if (DemoData.enabled) {
      if (mounted) setState(() => _ready = true);
      return;
    }
    if (AppModeService.instance.isPrivate) {
      final account = await PrivateAccountStore.instance.load();
      if (account == null) SchoolDataService.instance.clear();
      if (mounted) setState(() => _ready = account != null);
      return;
    }
    final token = await AuthService.getAccessToken();
    // A refresh that failed on the network still leaves a usable session - the
    // dashboard shows its own offline state. Only a session that is really gone
    // drops the active school and goes back to the sign-in screen.
    final signedIn = token != null || await AuthService.hasSession();
    if (!signedIn) {
      await ActiveAccountService.instance.clear();
      SchoolDataService.instance.clear();
    }
    if (mounted) setState(() => _ready = signedIn);
    if (token != null) unawaited(PushService.instance.onSignedIn());
  }

  Future<void> _signIn({bool register = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.signIn(register: register);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectPrivate() async {
    final ok = await runPrivateConnectFlow(context);
    if (ok) await _refresh();
  }

  Future<void> _onboardWithAccount() async {
    await OnboardingService.markSeen();
    if (mounted) setState(() => _onboarded = true);
    await AppModeService.instance.setMode(AppMode.account);
    await _signIn(register: true);
  }

  Future<void> _onboardWithPrivate() async {
    await OnboardingService.markSeen();
    if (mounted) setState(() => _onboarded = true);
    await AppModeService.instance.setMode(AppMode.private);
    await _connectPrivate();
  }

  Future<void> _signOut() async {
    await signOutAndClear();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready;

    if (ready == null) {
      return const FScaffold(child: Center(child: FCircularProgress()));
    }
    if (ready) {
      return DashboardScreen(onSignOut: _signOut);
    }
    if (!_onboarded) {
      return OnboardingScreen(
        onChooseAccount: _onboardWithAccount,
        onChoosePrivate: _onboardWithPrivate,
      );
    }

    return _SignInLanding(
      busy: _busy,
      error: _error,
      isPrivate: AppModeService.instance.isPrivate,
      onSignIn: _signIn,
      onConnectPrivate: _connectPrivate,
      onSwitchMode: (mode) => AppModeService.instance.setMode(mode),
    );
  }
}

class _SignInLanding extends StatelessWidget {
  final bool busy;
  final String? error;
  final bool isPrivate;
  final Future<void> Function() onSignIn;
  final Future<void> Function() onConnectPrivate;
  final ValueChanged<AppMode> onSwitchMode;

  const _SignInLanding({required this.busy, required this.error, required this.isPrivate, required this.onSignIn, required this.onConnectPrivate, required this.onSwitchMode});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final typography = context.theme.typography;

    return FScaffold(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/cropped_schuly_icon.png',
                          height: 48,
                          color: colors.primaryForeground,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Welcome to Schuly',
                      textAlign: TextAlign.center,
                      style: typography.xl3.copyWith(fontWeight: FontWeight.w800, height: 1.1)),
                  const SizedBox(height: 8),
                  Text(
                    isPrivate
                        ? 'Private mode: no account, nothing leaves this device.'
                        : 'Your grades, timetable and absences in one place.',
                    textAlign: TextAlign.center,
                    style: typography.base.copyWith(color: colors.mutedForeground),
                  ),
                  const SizedBox(height: 28),
                  const _Feature(icon: FIcons.chartColumn, text: 'Grades with class averages'),
                  const _Feature(icon: FIcons.calendarDays, text: 'Your timetable, tests and events'),
                  const _Feature(icon: FIcons.bellRing, text: 'Notifications when something changes'),
                  const SizedBox(height: 28),
                  if (error != null) ...[
                    FAlert(
                      style: FAlertStyle.destructive(),
                      icon: const Icon(FIcons.triangleAlert),
                      title: const Text('Could not sign in'),
                      subtitle: Text(error!),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (isPrivate) ...[
                    FButton(
                      prefix: const Icon(FIcons.school),
                      onPress: busy ? null : onConnectPrivate,
                      child: const Text('Connect a school'),
                    ),
                    const SizedBox(height: 10),
                    FButton(
                      style: FButtonStyle.ghost(),
                      prefix: const Icon(FIcons.cloud),
                      onPress: busy ? null : () => onSwitchMode(AppMode.account),
                      child: const Text('Use a Schuly account instead'),
                    ),
                  ] else ...[
                    FButton(
                      prefix: busy ? null : const Icon(FIcons.logOut),
                      onPress: busy ? null : onSignIn,
                      child: Text(busy ? 'Waiting for the browser…' : t.signIn),
                    ),
                    const SizedBox(height: 10),
                    FButton(
                      style: FButtonStyle.ghost(),
                      prefix: const Icon(FIcons.shieldCheck),
                      onPress: busy ? null : () => onSwitchMode(AppMode.private),
                      child: const Text('Use without an account'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Feature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: context.theme.colors.mutedForeground),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: context.theme.typography.sm)),
          ],
        ),
      );
}
