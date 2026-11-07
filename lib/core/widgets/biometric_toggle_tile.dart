import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_sheet.dart';
import 'line_illustration.dart';

/// سطر «الدخول بالبصمة» في صفحة الحساب بنفس شكل باقي السطور، وبيختفي لو الموبايل مفيهوش بصمة.
/// [card]: كارت لوحده زي صفحة الموكل، ومن غيره سطر جوه قايمة زي صفحة المحامي
class BiometricToggleTile extends StatefulWidget {
  final bool card;

  const BiometricToggleTile({super.key, this.card = false});

  @override
  State<BiometricToggleTile> createState() => _BiometricToggleTileState();
}

class _BiometricToggleTileState extends State<BiometricToggleTile> {
  bool? _available;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await BiometricService.isAvailable();
    final enabled = available && await BiometricService.enabledIdentifier() != null;
    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled = enabled;
    });
  }

  Future<void> _toggle(bool on) async {
    if (!on) {
      await BiometricService.disable();
      return _load();
    }
    final identifier = await AuthService.savedLoginPhone();
    if (!mounted || identifier == null || identifier.isEmpty) return;
    final done = await AppSheet.show<bool>(context, builder: (_) => _EnableBiometricSheet(identifier: identifier));
    if (done == true) await _load();
  }

  static const _title = TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.dark);

  Widget get _switch => Switch(value: _enabled, onChanged: _toggle, activeColor: AppColors.primary);

  @override
  Widget build(BuildContext context) {
    if (_available != true) return const SizedBox.shrink();
    if (widget.card) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          onTap: () => _toggle(!_enabled),
          child: Row(
            children: [
              const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('الدخول بالبصمة', style: _title.copyWith(fontWeight: FontWeight.w600))),
              _switch,
            ],
          ),
        ),
      );
    }
    return ListTile(
      onTap: () => _toggle(!_enabled),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(7.0),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 20),
      ),
      title: const Text('الدخول بالبصمة', style: _title),
      subtitle: const Text(
        'افتح حسابك بلمسة من غير باسورد',
        style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 11, color: AppColors.textMuted),
      ),
      trailing: _switch,
    );
  }
}

/// بوتن شيت تفعيل البصمة: رسمة، والباسورد للتأكيد، وبعدين البصمة
class _EnableBiometricSheet extends StatefulWidget {
  final String identifier;

  const _EnableBiometricSheet({required this.identifier});

  @override
  State<_EnableBiometricSheet> createState() => _EnableBiometricSheetState();
}

class _EnableBiometricSheetState extends State<_EnableBiometricSheet> {
  final _password = TextEditingController();
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final password = _password.text.trim();
    if (password.isEmpty) {
      setState(() => _error = 'اكتب الباسورد الأول');
      return;
    }
    setState(() => _error = null);
    final check = await AuthService.loginUser(identifier: widget.identifier, password: password);
    if (!mounted) return;
    if (!check.success) {
      setState(() => _error = check.message);
      return;
    }
    final ok = await BiometricService.enable(widget.identifier, password);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = 'ما اتأكدتش البصمة\nجرّب تاني');
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'تفعيل الدخول بالبصمة',
      children: [
        const Center(child: LineIllustration(icon: Icons.fingerprint_rounded, height: 90)),
        const SizedBox(height: 12),
        const Text(
          'أكد الباسورد بتاع حسابك\nوبعدها حط صباعك على البصمة',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, height: 1.6, fontWeight: FontWeight.w600, color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _password,
          obscureText: _obscure,
          autofocus: true,
          onSubmitted: (_) => _confirm(),
          style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'الباسورد',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: AppColors.cardBorder)),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w700, color: AppColors.danger),
          ),
        ],
        const SizedBox(height: 16),
        AppButton.primary(text: 'تأكيد وتفعيل', icon: Icons.fingerprint_rounded, height: 48, onPressed: _confirm),
      ],
    );
  }
}
