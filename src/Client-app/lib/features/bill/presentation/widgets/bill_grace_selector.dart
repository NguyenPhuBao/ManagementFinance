import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/segmented_choice.dart';
import '../../domain/bill_an_han.dart';

/// Thanh chọn ân hạn của form hoá đơn: `0 · 7 · 15 · 30 · Khác`.
///
/// Dùng chung cho form Thêm và form Sửa để hai màn không mỗi nơi một kiểu (bài
/// học của thanh chu kỳ, 06/09). Bốn gợi ý là `kAnHanGoiY`; "Khác" mở một ô số
/// ba chữ số. Widget KHÔNG giữ giá trị — form giữ trong `BillSchedule.anHanNgay`
/// và truyền xuống; widget chỉ nhớ người dùng đang ở chế độ "Khác" hay không.
///
/// Hình dạng theo màn Stitch "Thêm Hóa Đơn Định Kỳ" (sửa 2026-09-12): cùng
/// rãnh xám bo 12px với thanh chu kỳ, ô số 72px bên phải khi chọn "Khác".
class BoChonAnHan extends StatefulWidget {
  const BoChonAnHan({
    super.key,
    required this.giaTri,
    required this.onChanged,
    this.loi,
  });

  final int giaTri;
  final ValueChanged<int> onChanged;

  /// Câu báo từ `loiAnHan`, hiện đỏ dưới thanh. `null` = hợp lệ.
  final String? loi;

  @override
  State<BoChonAnHan> createState() => _BoChonAnHanState();
}

class _BoChonAnHanState extends State<BoChonAnHan> {
  late bool _khac = !kAnHanGoiY.contains(widget.giaTri);
  late final _oSo = TextEditingController(
      text: kAnHanGoiY.contains(widget.giaTri) ? '' : '${widget.giaTri}');

  @override
  void dispose() {
    _oSo.dispose();
    super.dispose();
  }

  void _chon(int? v) {
    if (v == null) {
      setState(() => _khac = true);
      final n = int.tryParse(_oSo.text);
      if (n != null) widget.onChanged(n);
      return;
    }
    setState(() => _khac = false);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final chon = _khac ? null : widget.giaTri;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedChoice<int?>(
                keyPrefix: 'bill-grace',
                options: [
                  for (final n in kAnHanGoiY) SegmentedOption<int?>(n, '$n'),
                  const SegmentedOption<int?>(null, 'Khác'),
                ],
                selected: chon,
                onChanged: _chon,
              ),
            ),
            if (_khac) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: TextField(
                  key: const ValueKey('bill-grace-custom'),
                  controller: _oSo,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'ngày',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (s) {
                    final n = int.tryParse(s);
                    if (n != null) widget.onChanged(n);
                  },
                ),
              ),
            ],
          ],
        ),
        if (widget.loi != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              widget.loi!,
              key: const ValueKey('bill-grace-error'),
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
