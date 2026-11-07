import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';

/// سطر «الدخول بالبصمة» في صفحة الحساب، وبيختفي لو الموبايل مفيهوش بصمة
class BiometricToggleTile extends StatefulWidget {
  const BiometricToggleTile({super.key});

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
    final password = await _askPassword();
    if (password == null || password.isEmpty) return;
    final check = await AuthService.loginUser(identifier: identifier, password: password);
    if (!mounted) return;
    if (!check.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(check.message, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback))));
      return;
    }
    await BiometricService.enable(identifier, password);
    await _load();
  }

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('أكد الباسورد', style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontWeight: FontWeight.w900, fontSize: 17)),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'الباسورد بتاع حسابك'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback))),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('متابعة', style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_available != true) return const SizedBox.shrink();
    return SwitchListTile(
      value: _enabled,
      onChanged: _toggle,
      activeColor: AppColors.primary,
      secondary: const Icon(Icons.fingerprint_rounded, color: AppColors.primary),
      title: const Text('الدخول بالبصمة', style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.dark)),
      subtitle: const Text('افتح حسابك بلمسة من غير باسورد', style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, color: AppColors.textMuted)),
    );
  }
}
