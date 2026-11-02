import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/phan_tram.dart';
import '../../domain/muc_tieu_chung.dart';

// Màu của Stitch `7b5f0f89…` (đợt 2): không trùng token nào của `AppColors`, nên giữ cục bộ trong tệp này.
const _xanh = Color(0xFF006E1C);
const _xanhNhat = Color(0xFFE8F5E9);
const _cam = Color(0xFFE65100);
const _camNhat = Color(0xFFFFF3E0);
const _nen = Color(0xFFEAE8E3);
const _chuPhu = Color(0xFF454743);
const _chuDam = Color(0xFF1A1A19);

/// `12.000.000 / 20.000.000 đ`: ký hiệu `đ` chỉ ở vế sau, qua [CurrencyFormatter].
String _chuTien(TienDoMucTieuChung t) =>
    '${CurrencyFormatter.formatSoThoi(t.soDu.round())} / ${CurrencyFormatter.format(t.mucTieu)}';

Color _mauDay(TienDoMucTieuChung t) => t.trangThai == TrangThaiMucTieuChung.quaHan ? _cam : _xanh;

class _Thanh extends StatelessWidget {
  const _Thanh({required this.tienDo, required this.cao});

  final TienDoMucTieuChung tienDo;
  final double cao;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Tiến độ ${chuPhanTram(tienDo.tiLe)}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cao),
          child: SizedBox(
            height: cao,
            child: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: _nen)),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: tienDo.tiLe.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: ColoredBox(key: const Key('tien-do-day'), color: _mauDay(tienDo)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Nhãn viên thuốc: *Đã đạt mục tiêu* (xanh, có dấu tích) hoặc *Quá hạn* (cam).
class _VienThuoc extends StatelessWidget {
  const _VienThuoc({required this.nhan, required this.nen, required this.mau, this.icon});

  final String nhan;
  final Color nen;
  final Color mau;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: nen, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 13, color: mau), const SizedBox(width: 4)],
            Text(nhan,
                maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mau)),
          ],
        ),
      );
}

/// Một dòng số dài một dòng: co lại (không xuống dòng) khi 13 chữ số vượt bề rộng.
class _SoMotDong extends StatelessWidget {
  const _SoMotDong(this.chu, this.kieu, {this.canPhai = false});

  final String chu;
  final TextStyle kieu;
  final bool canPhai;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: canPhai ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(chu, maxLines: 1, style: kieu),
      );
}

/// Thanh tiến độ gọn ở dòng ví của Nhà mình (Stitch `7b5f0f89…`). Bề rộng do chỗ gọi đặt (thụt theo cột tên).
class TienDoGon extends StatelessWidget {
  const TienDoGon({super.key, required this.tienDo});

  final TienDoMucTieuChung tienDo;

  @override
  Widget build(BuildContext context) {
    final phanTram = chuPhanTram(tienDo.tiLe);
    const nho = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _chuPhu);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Thanh(tienDo: tienDo, cao: 6),
        const SizedBox(height: 6),
        switch (tienDo.trangThai) {
          TrangThaiMucTieuChung.daDat => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _VienThuoc(nhan: 'Đã đạt mục tiêu', nen: _xanhNhat, mau: _xanh, icon: Icons.check_circle),
                Text(phanTram, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _xanh)),
              ],
            ),
          _ => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: _SoMotDong(_chuTien(tienDo), nho)),
                    const SizedBox(width: 8),
                    Text(phanTram, style: nho.copyWith(fontWeight: FontWeight.w700, color: _chuDam)),
                  ],
                ),
                if (tienDo.trangThai == TrangThaiMucTieuChung.quaHan) ...[
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: _VienThuoc(nhan: 'Quá hạn', nen: _camNhat, mau: _cam),
                  ),
                ],
              ],
            ),
        },
      ],
    );
  }
}

/// Khối MỤC TIÊU trong thẻ số dư của Chi tiết ví (Stitch `7b5f0f89…`).
class KhoiMucTieuChiTiet extends StatelessWidget {
  const KhoiMucTieuChiTiet({super.key, required this.tienDo});

  final TienDoMucTieuChung tienDo;

  Widget _hang(String trai, Widget phai) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(trai, style: const TextStyle(fontSize: 13, color: _chuPhu)),
            const SizedBox(width: 12),
            Flexible(child: phai),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final quaHan = tienDo.trangThai == TrangThaiMucTieuChung.quaHan;
    final daDat = tienDo.trangThai == TrangThaiMucTieuChung.daDat;
    const dam13 = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _chuDam);
    final canGop = tienDo.canGopMoiThang;
    return Column(
      key: const Key('khoi-muc-tieu'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (quaHan) ...[const Icon(Icons.warning_amber_rounded, size: 14, color: _cam), const SizedBox(width: 4)],
            Text(quaHan ? 'MỤC TIÊU (QUÁ HẠN)' : 'MỤC TIÊU',
                maxLines: 1,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: quaHan ? _cam : _chuPhu)),
            const SizedBox(width: 12),
            Expanded(
              child: _SoMotDong('${_chuTien(tienDo)} — ${chuPhanTram(tienDo.tiLe)}',
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _chuDam),
                  canPhai: true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Thanh(tienDo: tienDo, cao: 7),
        const SizedBox(height: 4),
        if (daDat)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _VienThuoc(nhan: 'Đã đạt mục tiêu', nen: _xanhNhat, mau: _xanh, icon: Icons.check_circle),
            ),
          )
        else ...[
          _hang('Còn thiếu', _SoMotDong(CurrencyFormatter.format(tienDo.conThieu), dam13, canPhai: true)),
          if (quaHan)
            _hang(
                'Thời hạn',
                _SoMotDong('Đã hết hạn ngày ${DateFormatter.formatDate(tienDo.han)}',
                    dam13.copyWith(color: _cam),
                    canPhai: true))
          else ...[
            _hang(
              'Còn lại',
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${tienDo.conNgay} ngày', style: dam13),
                    TextSpan(
                        text: ' (hạn ${DateFormatter.formatDate(tienDo.han)})',
                        style: const TextStyle(fontSize: 13, color: _chuPhu)),
                  ]),
                  maxLines: 1,
                ),
              ),
            ),
            if (canGop != null)
              _hang(
                  'Cần góp',
                  _SoMotDong('khoảng ${CurrencyFormatter.format(canGop)} mỗi tháng', dam13.copyWith(color: _xanh),
                      canPhai: true)),
          ],
        ],
      ],
    );
  }
}
