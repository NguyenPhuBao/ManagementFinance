import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/thu_tu_khoi_dao.dart';
import '../domain/thu_tu_khoi.dart';

/// Kết quả một lượt đọc: thứ tự hiện tại + cụm nên đề xuất (`null` = im).
class KetQuaThuTu {
  const KetQuaThuTu({required this.thuTu, this.deXuat});
  final List<CumKhoi> thuTu;
  final CumKhoi? deXuat;
}

/// Ghép DAO với luật thuần. **Phần phụ**: hỏng thì trả mặc định và
/// `debugPrint`, không làm hỏng trang Phân tích (spec 4.2).
abstract interface class ThuTuKhoiNguon {
  Future<KetQuaThuTu> doc(int idaccount, DateTime now);
  Future<void> ghiPhanHoi(int idaccount, String ketQua, CumKhoi? cum, DateTime luc);
  Future<void> congGiay(int idaccount, DateTime ngay, Map<CumKhoi, int> giay);
}

class ThuTuKhoiNguonDrift implements ThuTuKhoiNguon {
  ThuTuKhoiNguonDrift({required this.dao, String Function()? taoId})
      : _taoId = taoId ?? (() => const Uuid().v4());

  final ThuTuKhoiDao dao;
  final String Function() _taoId;

  @override
  Future<KetQuaThuTu> doc(int idaccount, DateTime now) async {
    try {
      final tu = DateTime(now.year, now.month, now.day - kCuaSoNgayDeXuat);
      final giay = <GiayXem>[];
      for (final h in await dao.giayXemTu(idaccount, maNgay(tu))) {
        final ngay = ngayTuMa(h.ngay);
        final cum = cumTuMa(h.cum);
        if (ngay == null || cum == null) continue;
        giay.add(GiayXem(ngay: ngay, cum: cum, giay: h.giay));
      }
      final ph = <PhanHoiThuTu>[];
      for (final h in await dao.phanHoi(idaccount)) {
        if (h.ketQua == kThuTuVeMacDinh) {
          ph.add(PhanHoiThuTu(ketQua: h.ketQua, luc: h.createdAt));
          continue;
        }
        final cum = cumTuMa(h.cum);
        if (cum == null) continue;
        ph.add(PhanHoiThuTu(ketQua: h.ketQua, cum: cum, luc: h.createdAt));
      }
      final thuTu = thuTuTu(ph);
      return KetQuaThuTu(
        thuTu: thuTu,
        deXuat: deXuatDuaLen(giayXem: giay, phanHoi: ph, thuTu: thuTu, now: now),
      );
    } catch (e) {
      debugPrint('[ThuTuKhoi] đọc hỏng, dùng thứ tự mặc định: $e');
      return const KetQuaThuTu(thuTu: kThuTuCumMacDinh);
    }
  }

  @override
  Future<void> ghiPhanHoi(int idaccount, String ketQua, CumKhoi? cum, DateTime luc) async {
    try {
      await dao.ghiPhanHoi(PhanTichThuTuPhanHoisCompanion.insert(
        id: _taoId(),
        idaccount: idaccount,
        cum: cum?.ma ?? '',
        ketQua: ketQua,
        createdAt: luc,
      ));
    } catch (e) {
      debugPrint('[ThuTuKhoi] ghi phản hồi hỏng: $e');
    }
  }

  @override
  Future<void> congGiay(int idaccount, DateTime ngay, Map<CumKhoi, int> giay) async {
    if (giay.isEmpty) return;
    try {
      await dao.congGiay(
        idaccount,
        maNgay(ngay),
        {for (final e in giay.entries) e.key.ma: e.value},
        xoaTruoc: maNgay(DateTime(ngay.year, ngay.month, ngay.day - kNgayGiuGiayXem)),
      );
    } catch (e) {
      debugPrint('[ThuTuKhoi] ghi giây xem hỏng: $e');
    }
  }
}
