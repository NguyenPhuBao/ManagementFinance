/// Nguồn dữ liệu cho xác suất vượt ngân sách M1 · M2 · M3 — BẢN THỬ NCKH (nhánh
/// TranQuangDat, không phát hành). Chỉ ngân sách TỔNG theo tháng dương lịch (đúng
/// thiết lập của bài); mọi lỗi trả `null` — phần phụ, không làm hỏng trang.
library;

import 'package:flutter/foundation.dart';

import '../domain/du_bao_vuot_ngan_sach.dart';
import 'datasources/budget_local_data_source.dart';
import 'models/budget_entity.dart';

abstract class DuBaoVuotNguon {
  Future<DuBaoVuot?> duBao(BudgetEntity nganSach, DateTime now);
}

class DuBaoVuotNguonImpl implements DuBaoVuotNguon {
  final BudgetLocalDataSource local;
  DuBaoVuotNguonImpl({required this.local});

  @override
  Future<DuBaoVuot?> duBao(BudgetEntity nganSach, DateTime now) async {
    try {
      if (nganSach.categoryId != null) return null;
      final ky = nganSach.currentPeriod(now);
      final dauThang = DateTime(now.year, now.month);
      final dauThangSau = DateTime(now.year, now.month + 1);
      if (ky.from != dauThang || ky.to != dauThangSau) return null;

      final moc = await local.mocGiaoDichDauTien(nganSach.idaccount);
      if (moc == null) return null;
      final thangDau = DateTime(moc.year, moc.month);
      final soThang = (now.year - thangDau.year) * 12 + now.month - thangDau.month + 1;
      if (soThang < 1) return null;
      final homNay = now.day;
      final thang = [
        for (var i = 0; i < soThang; i++)
          List<double>.filled(
            i == soThang - 1 ? homNay : DateTime(thangDau.year, thangDau.month + i + 1, 0).day,
            0,
          ),
      ];
      // `categoryId: null` = mọi khoản chi VÀO THỐNG KÊ — đúng định nghĩa ngân sách tổng.
      final chi = await local.getExpenses(
        idaccount: nganSach.idaccount,
        categoryId: null,
        from: thangDau,
        to: DateTime(now.year, now.month, now.day + 1),
      );
      for (final t in chi) {
        final i = (t.date.year - thangDau.year) * 12 + t.date.month - thangDau.month;
        if (i < 0 || i >= soThang) continue;
        final d = t.date.day - 1;
        if (d >= thang[i].length) continue;
        thang[i][d] += t.amount;
      }
      return duBaoVuotNganSach(
        thang: thang,
        soNgayKyNay: DateTime(now.year, now.month + 1, 0).day,
        nganSach: nganSach.amount,
      );
    } catch (e) {
      debugPrint('[DuBaoVuot] đọc hỏng: $e');
      return null;
    }
  }
}
