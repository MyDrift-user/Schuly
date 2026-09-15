import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import '../../domain/school_system.dart';
import '../../services/api_client.dart';
import '../../services/api_error.dart';
import '../widgets/dynamic_login_form.dart';

class UnifiedConnectScreen extends StatefulWidget {
  final SchoolSystem system;
  const UnifiedConnectScreen({required this.system, super.key});

  @override
  State<UnifiedConnectScreen> createState() => _UnifiedConnectScreenState();
}

class _UnifiedConnectScreenState extends State<UnifiedConnectScreen> {
  late final DynamicLoginFormController _form;
  late final TextEditingController _nameCtrl;
  bool _busy = false;
  String? _error;

  SchoolSystem get _system => widget.system;

  @override
  void initState() {
    super.initState();
    _form = DynamicLoginFormController(_system.loginFields);
    _nameCtrl = TextEditingController(text: _system.displayName);
  }

  @override
  void dispose() {
    _form.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final missing = _form.validateRequired();
    if (missing != null) {
      setState(() => _error = missing);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fields = {
        for (final f in _system.loginFields) f.key: _form.value(f.key),
      };
      final name = _nameCtrl.text.trim();
      final res = await ApiClient.instance.dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {
          'systemKey': _system.key,
          'fields': fields,
          'displayName': name.isEmpty ? _system.displayName : name,
        },
        options: ApiClient.handled(),
      );
      final accountId = res.data?['accountId']?.toString();
      // Only once the credentials are known good, so a manager is never asked
      // to save something that did not work.
      TextInput.finishAutofillContext();
      if (mounted) Navigator.of(context).pop(accountId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ApiError.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: Text('Add ${_system.displayName}'),
        prefixes: [FHeaderAction.back(onPress: () => Navigator.of(context).pop())],
      ),
      childPad: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.viewPaddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            _ConnectIntro(system: _system),
            DynamicLoginForm(controller: _form),
            FTextField(
              control: FTextFieldControl.managed(controller: _nameCtrl),
              label: const Text('Display Name'),
            ),
            FButton(
              prefix: _busy ? null : const Icon(FIcons.plus),
              onPress: _busy ? null : _connect,
              child: Text(_busy ? 'Connecting…' : 'Connect'),
            ),
            if (_error != null)
              FAlert(
                style: FAlertStyle.destructive(),
                icon: const Icon(FIcons.triangleAlert),
                title: const Text('Could not connect'),
                subtitle: Text(_error!),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectIntro extends StatelessWidget {
  final SchoolSystem system;
  const _ConnectIntro({required this.system});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    return Row(
      children: [
        Icon(FIcons.school, size: 28, color: colors.mutedForeground),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sign in to ${system.displayName}', style: typography.base.copyWith(fontWeight: FontWeight.w700)),
              Text('Use the login you normally use for the school portal.',
                  style: typography.sm.copyWith(color: colors.mutedForeground)),
            ],
          ),
        ),
      ],
    );
  }
}
