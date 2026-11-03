part of 'lawyer_register_screen.dart';

extension _LawyerRegisterDocuments on _LawyerRegisterScreenState {
  Widget _buildStep3Documents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInputLabel('صورتك الشخصية', isRequired: true),
        const SizedBox(height: 14),
        _buildPhotoPicker(),
        const SizedBox(height: 24),
        _buildInputLabel('صورة كارنيه نقابة المحامين (ساري)', isRequired: true),
        const SizedBox(height: 14),

        if (_syndicateCardPath == null)
          AppCard(
            isDashed: true,
            padding: EdgeInsets.zero,
            onTap: _showImageSourceModal,
            child: Container(
              height: 160,
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 36),
                  SizedBox(height: 10),
                  Text(
                    'اضغط هنا لالتقاط أو اختيار صورة الكارنيه',
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'صيغ JPG, PNG حتى 10 ميجابايت',
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          AppCard(
            isDashed: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14.0),
                  child: Image.file(
                    File(_syndicateCardPath!),
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 190,
                      color: AppColors.background,
                      alignment: Alignment.center,
                      child: const Text('تعذر تحميل معاينة الصورة محلياً'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppPressable(
                        child: OutlinedButton.icon(
                        onPressed: _showImageSourceModal,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'تغيير الصورة',
                          style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary, width: 1.2),
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
                        ),
                      ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppPressable(
                      child: IconButton(
                      onPressed: () {
                        _update(() {
                          _syndicateCardPath = null;
                        });
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                      tooltip: 'حذف الصورة',
                    ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 32),

        // أزرار التنقل
        Row(
          children: [
            Expanded(
              flex: 4,
              child: AppPressable(
                child: OutlinedButton(
                onPressed: _goToPreviousStep,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.0),
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
                text: 'مراجعة البيانات',
                onPressed: _validateAndAdvanceStep3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// الخطوة الرابعة: مراجعة وإرسال البيانات
}
