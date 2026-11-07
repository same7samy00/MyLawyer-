import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/app_button.dart';
import 'session_router.dart';

/// شاشة حالة اعتماد المحامي: قيد المراجعة أو مرفوض
/// لا يصل منها المحامي لواجهة الطلبات قبل اعتماد حسابه من إدارة المنصة
class LawyerApprovalStatusScreen extends StatefulWidget {
  final bool isRejected;

  const LawyerApprovalStatusScreen({super.key, required this.isRejected});

  @override
  State<LawyerApprovalStatusScreen> createState() => _LawyerApprovalStatusScreenState();
}

class _LawyerApprovalStatusScreenState extends State<LawyerApprovalStatusScreen> {
  String? _notice;

  Future<void> _refreshStatus() async {
    final navigator = Navigator.of(context);
    final check = await AuthService.restoreSession();
    if (!mounted) return;

    final isUnchanged = check.status == SessionStatus.lawyerPending && !widget.isRejected ||
        check.status == SessionStatus.lawyerRejected && widget.isRejected;
    if (isUnchanged) {
      setState(() => _notice = 'لم تتغير حالة حسابك بعد، سنراجع بياناتك في أقرب وقت');
      return;
    }
    await SessionRouter.openSession(navigator, check);
  }

  Future<void> _signOut() {
    return SessionRouter.signOut(Navigator.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final isRejected = widget.isRejected;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                isRejected ? Icons.gpp_bad_rounded : Icons.verified_user_rounded,
                size: 72,
                color: isRejected ? AppColors.danger : AppColors.primary,
              ),
              const SizedBox(height: 20),
              Text(
                isRejected ? 'لم يتم اعتماد حسابك' : 'حسابك قيد المراجعة',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isRejected
                    ? 'راجعت إدارة المنصة بياناتك ولم يتم قبولها\nيرجى التواصل مع الدعم الفني لمعرفة التفاصيل'
                    : 'نراجع بيانات القيد والكارنيه الخاصة بك، وهتقدر تستقبل الطلبات فور اعتماد حسابك',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_notice != null) ...[
                const SizedBox(height: 12),
                Text(
                  _notice!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              AppButton.primary(
                text: 'تحديث حالة الحساب',
                icon: Icons.refresh_rounded,
                onPressed: _refreshStatus,
              ),
              const SizedBox(height: 10),
              AppButton.outlined(
                text: 'تسجيل الخروج',
                onPressed: _signOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
