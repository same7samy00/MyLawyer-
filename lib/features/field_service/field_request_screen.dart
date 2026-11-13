import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/geo_naming_service.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_choice_chip.dart';
import '../../core/widgets/app_field_error.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../core/widgets/line_illustration.dart';
import '../../data/models/field_info.dart';
import 'field_input.dart';
import 'field_pin_screen.dart';
import 'field_services.dart';
import 'field_terms_screen.dart';

/// طلب خدمة ميدانية (محضر، نيابة، جلسة، مجلس عرفي، مصلحة): ليك (مكانك من الـ GPS) ولا لشخص تاني (دبوس على الخريطة)، والتفاصيل
class FieldRequestScreen extends StatefulWidget {
  final String problemTitle;
  final String initialDescription;

  const FieldRequestScreen({super.key, required this.problemTitle, this.initialDescription = ''});

  @override
  State<FieldRequestScreen> createState() => _FieldRequestScreenState();
}

class _FieldRequestScreenState extends State<FieldRequestScreen> {
  late final TextEditingController _description = TextEditingController(text: widget.initialDescription);
  final TextEditingController _personName = TextEditingController();
  bool _forOther = false;
  bool _detained = false;
  String _relation = '';

  /// «ليا أنا»: الموكل في المكان، فالمكان هو موقعه من الـ GPS
  FieldPlace? _myPlace;
  bool _locating = false;
  String? _locationError;

  /// «لشخص تاني»: دبوس على الخريطة
  FieldPlace? _otherPlace;

  /// غلط كل خانة، بيظهر أحمر تحت عنوانها وبيختفي لما تتصلّح
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _locateMe();
    _personName.addListener(() => _clearError('name'));
    _description.addListener(() => _clearError('description'));
  }

  void _clearError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors.remove(key));
  }

  @override
  void dispose() {
    _description.dispose();
    _personName.dispose();
    super.dispose();
  }

  /// موقع الموكل دلوقتي واسم المنطقة اللي هو فيها
  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    final location = await LocationService.instance.checkAndRequestPermission(fresh: true);
    final position = location.position;
    if (position == null) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        // التحديث اللي فشل ما بيمسحش المكان اللي اتحدد قبله
        if (_myPlace == null) _locationError = location.errorMessage ?? 'تعذر تحديد موقعك، حاول تاني';
      });
      return;
    }
    final name = await GeoNamingService.instance.getCityAndGovernorate(position.latitude, position.longitude);
    if (!mounted) return;
    setState(() {
      _locating = false;
      _errors.remove('place');
      _myPlace = FieldPlace(name: name, lat: position.latitude, lon: position.longitude, verified: false);
    });
  }

  void _continue() {
    final place = _forOther ? _otherPlace : _myPlace;
    final description = _description.text.trim();
    final name = _personName.text.trim();
    final errors = <String, String>{
      if (_forOther && name.isEmpty) 'name': 'اكتب اسم الشخص',
      if (place == null) 'place': _forOther ? 'حدد المكان على الخريطة' : (_locating ? 'استنى لحد ما نحدد مكانك' : 'لازم نحدد مكانك الأول'),
      if (description.length < 5) 'description': 'اكتب تفاصيل الطلب باختصار',
    };
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FieldTermsScreen(
          draft: FieldDraft(
            serviceTitle: widget.problemTitle,
            description: description,
            place: place!,
            forOther: _forOther,
            personName: name,
            relation: _relation,
            detained: _forOther && _detained,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'تفاصيل الطلب', isInnerPage: true),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // اسم الخدمة جوه الكارت اللي في الرسمة
                    RepaintBoundary(child: Center(child: LineIllustration(icon: Icons.edit_note_rounded, height: 90, label: widget.problemTitle))),
                    const SizedBox(height: 22),
                    const Text('الطلب ده لمين؟', style: fieldLabelStyle),
                    const SizedBox(height: 8),
                    _whoToggle(),
                    if (_forOther) ..._personSection(),
                    const SizedBox(height: 18),
                    Text(_forOther ? 'المكان اللي المحامي هيروحه' : 'المحامي هيجيلك على مكانك', style: fieldLabelStyle),
                    AppFieldError(_errors['place']),
                    const SizedBox(height: 8),
                    if (_forOther) _otherPlaceCard() else _myPlaceCard(),
                    const SizedBox(height: 18),
                    const Text('اكتب تفاصيل الطلب باختصار', style: fieldLabelStyle),
                    AppFieldError(_errors['description']),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _description,
                      minLines: 4,
                      maxLines: 6,
                      maxLength: 500,
                      style: fieldTextStyle,
                      decoration: fieldDecoration(hint: 'اكتب هنا ملخصًا لما حصل، وأي ورق أو تفاصيل المحامي محتاج يعرفها'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AppButton.primary(text: 'المتابعة', onPressed: _continue, height: 50),
            ),
          ],
        ),
      ),
    );
  }

  /// مكان الموكل من الـ GPS: بيتحدد لوحده، ولو فشل يحاول تاني
  Widget _myPlaceCard() {
    final place = _myPlace;
    // أول مرة: سطر Skeleton مكان اسم المنطقة. التحديث بيسيب الاسم القديم لحد ما الجديد يوصل
    final String? text = place?.name ?? (_locating ? null : (_locationError ?? 'لازم نحدد مكانك'));
    return _placeCard(
      icon: Icons.my_location_rounded,
      text: text,
      problem: place == null && !_locating,
      note: 'موقعك من الـ GPS. اطلب وإنت في المكان',
      trailing: _locating
          ? const Center(child: AppLoader.inline(size: 20))
          : TextButton(onPressed: _locateMe, child: Text(place == null ? 'حاول تاني' : 'تحديث')),
    );
  }

  /// مكان الشخص التاني: المحافظة وبعدين دبوس على الخريطة
  Widget _otherPlaceCard() {
    final place = _otherPlace;
    return _placeCard(
      icon: Icons.location_on_rounded,
      text: place?.name ?? 'حدد المكان على الخريطة',
      note: place == null ? 'اختار المحافظة وحط الدبوس على المكان بالظبط' : 'المحامي هيروح النقطة اللي حددتها',
      trailing: TextButton(onPressed: _pickOtherPlace, child: Text(place == null ? 'تحديد' : 'تغيير')),
      onTap: _pickOtherPlace,
    );
  }

  Future<void> _pickOtherPlace() async {
    final place = await Navigator.of(context).push<FieldPlace>(
      MaterialPageRoute(builder: (_) => FieldPinScreen(serviceTitle: widget.problemTitle)),
    );
    if (place != null && mounted) setState(() => _otherPlace = place);
  }

  Widget _placeCard({
    required IconData icon,
    required String? text,
    required String note,
    required Widget trailing,
    bool problem = false,
    VoidCallback? onTap,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(7.0)),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (text == null)
                  const AppSkeleton(child: FractionallySizedBox(widthFactor: 0.7, child: SkeletonBox(height: 14)))
                else
                  Text(
                    text,
                    style: problem ? fieldTextStyle.copyWith(color: AppColors.danger) : fieldTextStyle.copyWith(fontWeight: FontWeight.w800),
                  ),
                const SizedBox(height: 4),
                Text(note, style: fieldMutedStyle),
              ],
            ),
          ),
          // مقاس ثابت للزرار والتحميل، عشان الكارت ما يتغيرش لما تدوس «تحديث»
          SizedBox(width: 84, height: 40, child: trailing),
        ],
      ),
    );
  }

  Widget _whoToggle() {
    Widget option(String text, IconData icon, bool other) {
      final on = _forOther == other;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() {
            _forOther = other;
            _errors.clear();
          }),
          borderRadius: BorderRadius.circular(7.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: on ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(7.0),
              border: Border.all(color: on ? AppColors.primary : AppColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: on ? Colors.white : AppColors.textMuted),
                const SizedBox(width: 6),
                Text(text, style: fieldLabelStyle.copyWith(color: on ? Colors.white : AppColors.dark)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option('ليا أنا', Icons.person_rounded, false),
        const SizedBox(width: 10),
        option('لشخص تاني', Icons.group_rounded, true),
      ],
    );
  }

  List<Widget> _personSection() {
    return [
      const SizedBox(height: 14),
      TextField(
        controller: _personName,
        maxLength: 120,
        textInputAction: TextInputAction.next,
        style: fieldTextStyle,
        decoration: fieldDecoration(hint: 'اسم الشخص', icon: Icons.badge_rounded),
      ),
      AppFieldError(_errors['name']),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final relation in FieldServices.relations)
            AppChoiceChip(
              label: relation,
              selected: _relation == relation,
              onSelected: (on) => setState(() => _relation = on ? relation : ''),
            ),
        ],
      ),
      if (FieldServices.asksDetained(widget.problemTitle)) ...[
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('الشخص محبوس أو محتجز', style: fieldLabelStyle),
          subtitle: const Text('لو معاهوش تليفون، المحامي هيأكد وصوله معاك بدل الكود', style: fieldMutedStyle),
          value: _detained,
          onChanged: (on) => setState(() => _detained = on),
        ),
      ],
      const SizedBox(height: 4),
      const Text(
        'هيظهرلك كود من 4 أرقام بعد الدفع. اديه للشخص، وهو يقوله للمحامي لما يقابله',
        style: fieldMutedStyle,
      ),
    ];
  }
}
