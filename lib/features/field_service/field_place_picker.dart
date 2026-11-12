import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_message.dart';
import '../../data/models/field_info.dart';
import '../../data/repositories/field_repository.dart';
import 'field_input.dart';

/// اختيار المكان بالاسم: الموكل بيكتب والنتايج بتظهر تحته. لو المكان مش ظاهر بيكتبه بإيده
class FieldPlacePicker extends StatefulWidget {
  final String hint;
  final FieldPlace? selected;
  final ValueChanged<FieldPlace?> onChanged;

  const FieldPlacePicker({super.key, required this.hint, required this.selected, required this.onChanged});

  @override
  State<FieldPlacePicker> createState() => _FieldPlacePickerState();
}

class _FieldPlacePickerState extends State<FieldPlacePicker> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<FieldPlace> _results = const [];
  bool _searching = false;
  bool _searched = false;
  int _searchId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTyped(String text) {
    _debounce?.cancel();
    final words = text.trim();
    if (words.length < 2) {
      setState(() {
        _results = const [];
        _searched = false;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(words));
  }

  Future<void> _search(String words) async {
    final id = ++_searchId;
    setState(() => _searching = true);
    final found = await FieldRepository.places(words);
    if (!mounted || id != _searchId) return;
    setState(() {
      _results = found;
      _searching = false;
      _searched = true;
    });
  }

  /// المكان اللي بالاسم مش لاقيه: الاسم من الموكل والنقطة هي مكانه دلوقتي
  Future<void> _useManual() async {
    final name = _controller.text.trim();
    if (name.length < 3) {
      showAppMessage(context, const SnackBar(content: Text('اكتب اسم المكان الأول')));
      return;
    }
    final location = await LocationService.instance.checkAndRequestPermission(fresh: true);
    final position = location.position;
    if (!mounted) return;
    if (position == null) {
      showAppMessage(context, SnackBar(content: Text(location.errorMessage ?? 'شغّل الموقع عشان نحدد المكان')));
      return;
    }
    widget.onChanged(FieldPlace(name: name, lat: position.latitude, lon: position.longitude, verified: false));
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    if (selected != null) return _selectedCard(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onTyped,
          textInputAction: TextInputAction.search,
          style: fieldTextStyle,
          decoration: fieldDecoration(hint: widget.hint, icon: Icons.search_rounded),
        ),
        if (_searching)
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Center(child: AppLoader.inline(size: 22)))
        else ...[
          for (final place in _results) _resultTile(place),
          if (_searched || _controller.text.trim().length >= 3) _manualTile(),
        ],
      ],
    );
  }

  Widget _resultTile(FieldPlace place) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: () => widget.onChanged(place),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: fieldTextStyle.copyWith(fontWeight: FontWeight.w800)),
                  if (place.address.isNotEmpty) Text(place.address, style: fieldMutedStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _manualTile() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: _useManual,
        child: Row(
          children: [
            const Icon(Icons.edit_location_alt_rounded, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _results.isEmpty ? 'مش لاقيين المكان؟ استخدم اللي كتبته وإنت في المكان' : 'المكان مش في النتايج؟ استخدم اللي كتبته وإنت في المكان',
                style: fieldMutedStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedCard(FieldPlace place) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(7.0)),
            child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name, style: fieldTextStyle.copyWith(fontWeight: FontWeight.w800)),
                if (place.address.isNotEmpty) Text(place.address, style: fieldMutedStyle),
              ],
            ),
          ),
          TextButton(
            onPressed: () => widget.onChanged(null),
            child: const Text('تغيير'),
          ),
        ],
      ),
    );
  }
}
