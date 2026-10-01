/// Adapter tool `danh_sach_danh_muc` (spec mở rộng tool 2026-09-27 §4.3): danh
/// mục con chọn được của tài khoản + ngân sách đang chạy (để gắn "có ngân
/// sách") → `hangDanhMuc`.
library;

import '../../budget/data/repositories/budget_repository.dart';
import '../../category/data/repositories/category_management_repository.dart';
import '../domain/chinh_tham_so.dart';
import '../domain/cong_cu.dart';
import '../domain/hang_danh_muc.dart';
import '../domain/hang_so_lieu.dart';
import 'nguon_goi_so.dart';

class CongCuDanhMuc implements CongCu {
  CongCuDanhMuc({required this.danhMuc, required this.nganSach});
  final CategoryManagementRepository danhMuc;
  final BudgetRepository nganSach;

  @override
  KhaiBaoCongCu get khaiBao => KhaiBaoCongCu(
        ten: kTenCongCuDanhMuc,
        moTa: 'Gọi khi hỏi có những danh mục nào, có bao nhiêu danh mục. Trả tên từng '
            'danh mục kèm loại và có ngân sách hay chưa; không có số tiền. Hỏi danh '
            'mục chưa đặt ngân sách thì gọi $kTenCongCuNganSach.',
        thamSo: {
          'type': 'object',
          'properties': {
            'loai': {
              'type': 'string',
              'enum': kLoaiDanhMuc.keys.toList(),
              'description': 'khoan_chi, khoan_thu, vay_no; tat_ca là mặc định.',
            },
          },
        },
      );

  @override
  Future<KetQuaCongCu> chay(
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
    String cauHoi = '',
  }) async {
    final a = chinhThamSoDanhMuc(cauHoi, args).args;
    final maLoai = a['loai']?.toString().trim();
    final ds = await danhMuc.selectableChildrenAll(accountId: idaccount);
    final dangChay = nganSachDangChay(
      await nganSach.watchBudgets(idaccount, now: now).first,
      now,
    );
    return hangDanhMuc(
      ds,
      coNganSach: {
        for (final b in dangChay)
          if (b.budget.categoryId != null) b.budget.categoryId!,
      },
      loai: (maLoai == null || maLoai.isEmpty) ? kLoaiDanhMucMacDinh : maLoai,
    );
  }
}
