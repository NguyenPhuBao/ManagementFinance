/// A5 mục 11.2 + 11.2b — sheet *"Thêm phần"* của khối tách (Stitch `98133eb8…`): chọn danh mục, rồi
/// - **chọn món** (form mở từ ảnh quét loại hoá đơn có danh sách món): tick món, tiền = Σ món đã tick; món đã thuộc phần
///   khác hiện mờ kèm tên danh mục ấy, không tick được; *"Nhập số tiền thủ công"* chuyển sang ô số;
/// - **nhập số** (mọi trường hợp khác).
///
/// Trả [PhanTach] mới / đã sửa; `null` = đóng không đổi. App KHÔNG đoán danh mục món (A5b).
library;

import 'package:flutter/material.dart';

import '../../../../core/category/category_visuals.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/gioi_han_do_dai.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/doc_mon_hang.dart';
import '../../domain/khoang_tien.dart';
import '../../domain/tach_giao_dich.dart';

Future<PhanTach?> moSheetThemPhan(
  BuildContext context, {
  required List<Category> chonDuoc,
  required Set<String> daDung,
  PhanTach? dangSua,
  List<MonHang> mon = const [],
  Map<int, String> monCuaPhanKhac = const {},
}) =>
    showModalBottomSheet<PhanTach>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SheetThemPhan(
        chonDuoc: chonDuoc,
        daDung: daDung,
        dangSua: dangSua,
        mon: mon,
        monCuaPhanKhac: monCuaPhanKhac,
      ),
    );

class _SheetThemPhan extends StatefulWidget {
  const _SheetThemPhan({
    required this.chonDuoc,
    required this.daDung,
    required this.dangSua,
    required this.mon,
    required this.monCuaPhanKhac,
  });

  final List<Category> chonDuoc;
  final Set<String> daDung;
  final PhanTach? dangSua;
  final List<MonHang> mon;
  final Map<int, String> monCuaPhanKhac;

  @override
  State<_SheetThemPhan> createState() => _SheetThemPhanState();
}

class _SheetThemPhanState extends State<_SheetThemPhan> {
  String? _dm;
  late Set<int> _tick;
  late bool _nhapSo;
  final _so = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = widget.dangSua;
    _dm = s?.categoryId;
    _tick = {...?s?.monIds};
    // Không có món → chỉ nhập số. Đang sửa một phần nhập số → giữ ô số.
    _nhapSo = widget.mon.isEmpty || (s != null && s.monIds.isEmpty);
    if (s != null && _nhapSo) _so.text = CurrencyFormatter.formatSoThoi(s.soTien);
    _so.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _so.dispose();
    super.dispose();
  }

  double get _tien => _nhapSo
      ? (double.tryParse(_so.text.replaceAll(RegExp(r'[.,\s]'), '')) ?? 0)
      : widget.mon.where((m) => _tick.contains(m.id)).fold(0.0, (s, m) => s + m.soTien);

  bool get _xongDuoc => _dm != null && _tien > kDungSaiTien;

  static const _nhan = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final chon = [
      for (final c in widget.chonDuoc)
        if (!widget.daDung.contains(c.id) || c.id == widget.dangSua?.categoryId) c,
    ];
    return Padding(
      key: const Key('sheet-them-phan'),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(widget.dangSua == null ? 'Thêm phần' : 'Sửa phần',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                if (widget.mon.isNotEmpty)
                  const Text('Tách danh mục theo từng món trên hoá đơn',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                const Text('DANH MỤC', style: _nhan),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in chon)
                      ChoiceChip(
                        key: Key('phan-danh-muc-${c.id}'),
                        label: Text(c.name),
                        selected: _dm == c.id,
                        avatar: CircleAvatar(radius: 5, backgroundColor: categoryColorFrom(c.colour)),
                        onSelected: (_) => setState(() => _dm = c.id),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!_nhapSo) ..._danhSachMon() else ..._oSo(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _nhapSo
                          ? const SizedBox.shrink()
                          : Text(
                              'Đã chọn ${_tick.length} món · ${CurrencyFormatter.format(_tien)}',
                              key: const Key('phan-da-chon'),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                    ),
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
                    const SizedBox(width: 4),
                    FilledButton(
                      key: const Key('phan-xong'),
                      onPressed: _xongDuoc
                          ? () => Navigator.pop(
                                context,
                                PhanTach(
                                  categoryId: _dm!,
                                  soTien: _tien,
                                  monIds: _nhapSo ? const {} : {..._tick},
                                ),
                              )
                          : null,
                      child: const Text('Xong'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _oSo() => [
        const Text('SỐ TIỀN', style: _nhan),
        const SizedBox(height: 8),
        TextField(
          key: const Key('phan-so-tien'),
          controller: _so,
          autofocus: widget.dangSua == null,
          keyboardType: TextInputType.number,
          inputFormatters: const [GioiHanSoChuSo(kSoChuSoToiDaSoTien)],
          decoration: const InputDecoration(hintText: '0', suffixText: 'đ'),
        ),
      ];

  List<Widget> _danhSachMon() => [
        Row(
          children: [
            const Expanded(child: Text('CHỌN MÓN TỪ HOÁ ĐƠN', style: _nhan)),
            Text('${widget.mon.length} món', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        for (final m in widget.mon) _dongMon(m),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('phan-nhap-so'),
            onPressed: () => setState(() {
              _nhapSo = true;
              _tick.clear();
            }),
            icon: const Icon(Icons.edit_note, size: 18),
            label: const Text('Nhập số tiền thủ công'),
          ),
        ),
      ];

  Widget _dongMon(MonHang m) {
    final cuaPhanKhac = widget.monCuaPhanKhac[m.id];
    final tick = _tick.contains(m.id);
    final dong = InkWell(
      key: Key('mon-${m.id}'),
      onTap: cuaPhanKhac != null
          ? null
          : () => setState(() => tick ? _tick.remove(m.id) : _tick.add(m.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              tick ? Icons.check_box : Icons.check_box_outline_blank,
              size: 22,
              color: tick ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(m.ten, style: const TextStyle(fontSize: 14)),
                  if (cuaPhanKhac != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(cuaPhanKhac, style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              CurrencyFormatter.format(m.soTien),
              style: TextStyle(fontSize: 14, color: m.soTien < 0 ? AppColors.expense : AppColors.primary),
            ),
          ],
        ),
      ),
    );
    return cuaPhanKhac == null ? dong : Opacity(opacity: 0.45, child: dong);
  }
}
