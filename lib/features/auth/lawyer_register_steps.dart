part of 'lawyer_register_screen.dart';

extension _LawyerRegisterSteps on _LawyerRegisterScreenState {
  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الخطوة ${_currentStep + 1} من 4: ${_getStepTitle(_currentStep)}',
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
              Text(
                '${((_currentStep + 1) / 4 * 100).round()}%',
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(4, (index) {
              final isPassed = index <= _currentStep;
              return Expanded(
                child: Container(
                  height: 4.5,
                  margin: EdgeInsets.only(
                    left: index == 0 ? 4 : 0,
                    right: index == 3 ? 4 : (index == 0 ? 0 : 4),
                  ),
                  decoration: BoxDecoration(
                    color: isPassed ? AppColors.primary : AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(7.0),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// الخطوة الأولى: البيانات الشخصية والمهنية
  Widget _buildStep1PersonalAndProfessionalData() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // 1. الاسم الرباعي
          _buildInputLabel('الاسم الرباعي (مطابق لكارنيه النقابة)', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hintText: 'مثال: أحمد محمود إبراهيم الشافعي',
              prefixIcon: Icons.badge_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال الاسم الرباعي كاملاً';
              }
              final parts = value.trim().split(RegExp(r'\s+'));
              if (parts.length < 3) {
                return 'يرجى إدخال الاسم ثلاثياً أو رباعياً على الأقل';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // 2. رقم الهاتف
          _buildInputLabel('رقم الهاتف المحمول', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
            decoration: _inputDecoration(
              hintText: '01xxxxxxxxx',
              prefixIcon: Icons.phone_android_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال رقم الهاتف المحمول';
              }
              final clean = value.trim();
              if (!RegExp(r'^01[0125][0-9]{8}$').hasMatch(clean)) {
                return 'يرجى إدخال رقم هاتف مصري صحيح مكون من 11 رقماً يبدأ بـ 01';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // 3. رقم القيد بالنقابة
          _buildInputLabel('رقم القيد بنقابة المحامين', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _syndicateNumberController,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'مثال: 582410',
              prefixIcon: Icons.verified_user_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال رقم القيد بالنقابة';
              }
              if (value.trim().length < 4) {
                return 'رقم القيد يجب أن يتكون من 4 أرقام على الأقل';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          _buildInputLabel('سنوات الخبرة', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _experienceController,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'مثال: 5',
              prefixIcon: Icons.verified_outlined,
            ),
            validator: (value) {
              final years = int.tryParse(value?.trim() ?? '');
              if (years == null) return 'اكتب عدد سنوات خبرتك';
              if (years > 70) return 'سنوات الخبرة غير صحيحة';
              return null;
            },
          ),
          const SizedBox(height: 32),

          // زر المتابعة للخطوة التالية 24.0px
          AppButton.primary(
            text: 'بيانات الحساب',
            onPressed: _validateAndAdvanceStep1,
          ),
        ],
      ),
    );
  }

  /// الخطوة الثانية: بيانات الحساب
  Widget _buildStep2AccountData() {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // 1. البريد الإلكتروني
          _buildInputLabel('البريد الإلكتروني المهني', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'lawyer@example.com',
              prefixIcon: Icons.mail_outline_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال البريد الإلكتروني لتفعيل الحساب';
              }
              final clean = value.trim();
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(clean)) {
                return 'يرجى إدخال بريد إلكتروني بصيغة صحيحة';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // 2. كلمة المرور
          _buildInputLabel('كلمة المرور', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'أدخل كلمة مرور قوية لحماية حسابك المهني',
              prefixIcon: Icons.lock_outline_rounded,
              suffixWidget: AppPressable(
                child: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                onPressed: () {
                  _update(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال كلمة المرور';
              }
              if (value.length < 8) {
                return 'كلمة المرور يجب ألا تقل عن 8 خانات';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // شريط قوة كلمة المرور فقط دون شارات
          PasswordStrengthWidget(strength: _passwordStrength),
          const SizedBox(height: 32),

          // أزرار التنقل (السابق + التالي)
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
                  text: 'مستندات المحامي',
                  onPressed: _validateAndAdvanceStep2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// الصورة الشخصية بتظهر للموكلين وبتراجعها الإدارة مع الكارنيه
  Widget _buildPhotoPicker() {
    final photo = _profilePhotoPath;
    return AppCard(
      isDashed: true,
      padding: const EdgeInsets.all(12),
      onTap: () => _showImageSourceModal(forPhoto: true),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(7.0),
            ),
            child: photo == null
                ? const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 32)
                : Image.file(File(photo), fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              photo == null ? 'اضغط هنا لالتقاط أو اختيار صورتك' : 'اضغط لتغيير الصورة',
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// الخطوة الثالثة: مستندات المحامي (إرفاق ومعاينة صورة كارنيه النقابة)

  Widget _buildInputLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixWidget,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontFamily: 'AppFont',
        fontFamilyFallback: appFontFallback,
        fontSize: 13,
        color: AppColors.textMuted,
      ),
      prefixIcon: Icon(prefixIcon, color: AppColors.textMuted, size: 20),
      suffixIcon: suffixWidget,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 15.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
      ),
    );
  }
}
