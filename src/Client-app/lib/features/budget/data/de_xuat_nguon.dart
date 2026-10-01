/// Đọc repository → `chonDeXuat` — MỘT chỗ cho cả thẻ *Chưa đặt ngân sách*
/// (`BudgetCubit`) và tool `danh_sach_ngan_sach chon=chua_dat` (2026-09-27,
/// spec chắn oan + chưa đặt). Tách từ `BudgetCubit._deXuat`; luật ẩn vẫn nằm
/// ở `chonDeXuat`, ở đây chỉ gom đầu vào.
library;

import '../domain/de_xuat_ngan_sach.dart';
import 'models/budget_entity.dart';
import 'repositories/budget_repository.dart';

/// [dangChay] là ngân sách đang chạy (đã lọc `isExpired`) — danh mục của chúng
/// là *đã có ngân sách*. `null` khi tài khoản quá trẻ hoặc không có ứng viên.
Future<GoiDeXuat?> deXuatTuKho(
  BudgetRepository repository,
  int idaccount,
  List<BudgetView> dangChay, {
  int toiDa = kToiDaDeXuat,
}) async {
  final soNgay = await repository.soNgayCuaSoNhinLai(idaccount);
  if (soNgay == null) return null;

  final daCo = {
    for (final v in dangChay)
      if (v.budget.categoryId case final id?) id,
  };
  // `getExpenseCategories` ĐÃ lọc `classify = 'chi'` — đừng lọc lần nữa.
  final cats = await repository.getExpenseCategories(idaccount);

  final muc = <String, double?>{};
  for (final c in cats) {
    if (daCo.contains(c.id)) continue;
    muc[c.id] = await repository.suggestAmount(idaccount, c.id);
  }

  return chonDeXuat(
    danhMucChi: [
      for (final c in cats)
        (id: c.id, ten: c.name, icon: c.icon, colour: c.colour),
    ],
    daCoNganSach: daCo,
    mucThangTheoDanhMuc: muc,
    soNgayCuaSo: soNgay,
    toiDa: toiDa,
  );
}
