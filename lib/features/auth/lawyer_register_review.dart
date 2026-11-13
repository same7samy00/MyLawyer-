part of 'lawyer_register_screen.dart';

extension _LawyerRegisterReview on _LawyerRegisterScreenState {
  Widget _buildStep4ReviewAndSubmit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        // بطاقة الملخص الشامل للمحامي
        AppCard(
          padding: const EdgeInsets.all(16.0),
          isDashed: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ملخص ملف المحامي المهني',
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 14),

              _buildSummaryItem(
                label: 'الاسم الرباعي (النقابي):',
                value: _nameController.text.trim(),
                icon: Icons.badge_outlined,
                onEdit: () => _update(() => _currentStep = 0),
              ),
              const Divider(height: 20, color: AppColors.cardBorder),

              _buildSummaryItem(
                label: 'رقم الهاتف المحمول:',
                value: _phoneController.text.trim(),
                icon: Icons.phone_android_rounded,
                isLtr: true,
                onEdit: () => _update(() => _currentStep = 0),
              ),
              const Divider(height: 20, color: AppColors.cardBorder),

              _buildSummaryItem(
                label: 'رقم القيد بالنقابة:',
                value: _syndicateNumberController.text.trim(),
                icon: Icons.verified_user_outlined,
                isLtr: true,
                onEdit: () => _update(() => _currentStep = 0),
              ),
              const Divider(height: 20, color: AppColors.cardBorder),

              _buildSummaryItem(
                label: 'البريد الإلكتروني المهني:',
                value: _emailController.text.trim(),
                icon: Icons.mail_rounded,
                isLtr: true,
                onEdit: () => _update(() => _currentStep = 1),
              ),
              const Divider(height: 20, color: AppColors.cardBorder),

              _buildSummaryItem(
                label: 'كلمة المرور:',
                value: '•••••••• (محمية ومطابقة للشروط)',
                icon: Icons.lock_rounded,
                onEdit: () => _update(() => _currentStep = 1),
              ),
              const Divider(height: 20, color: AppColors.cardBorder),

              // الصورة الشخصية
              Row(
                children: [
                  const Icon(Icons.person_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'الصورة الشخصية:',
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_profilePhotoPath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(7.0),
                      child: Image.file(File(_profilePhotoPath!), width: 44, height: 44, fit: BoxFit.cover),
                    ),
                  AppPressable(
                    child: IconButton(
                      onPressed: () => _update(() => _currentStep = 2),
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                      tooltip: 'تعديل',
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: AppColors.cardBorder),

              // مستند الكارنيه
              Row(
                children: [
                  const Icon(Icons.document_scanner_outlined, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'صورة كارنيه النقابة:',
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_syndicateCardPath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(7.0),
                      child: Image.file(
                        File(_syndicateCardPath!),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                  AppPressable(
                    child: IconButton(
                    onPressed: () => _update(() => _currentStep = 2),
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    tooltip: 'تعديل',
                  ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // أزرار التنقل والإرسال
        Row(
          children: [
            Expanded(
              flex: 4,
              child: AppPressable(
                child: OutlinedButton(
                onPressed: _isLoading ? null : _goToPreviousStep,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7.0),
                  ),
                ),
                child: const Text(
                  'السابق',
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
              ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: AppButton.primary(
                text: 'إرسال طلب التسجيل',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _handleRegister,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        const Center(
          child: Text(
            'بإرسال الطلب، فإنك تؤكد صحة كافة البيانات المقدمة وتوافق على ميثاق العمل المهني لـ My Lawyer',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onEdit,
    bool isLtr = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                textDirection: isLtr ? TextDirection.ltr : null,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
        ),
        AppPressable(
          child: IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
          tooltip: 'تعديل',
        ),
        ),
      ],
    );
  }
}
