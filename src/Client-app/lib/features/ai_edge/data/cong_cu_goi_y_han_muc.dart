/// Adapter tool `goi_y_han_muc`: khớp tên (nếu có) → cửa sổ nhìn lại →
/// `suggestAmount` từng danh mục → `hangGoiYHanMuc`. Tên sai thì từ chối TRƯỚC
/// khi hỏi `suggestAmount` (16 danh mục = 16 truy vấn cộng).
library;

import '../../../core/database/app_database.dart';
import '../../../core/utils/khop_ten.dart';
import '../../budget/data/repositories/budget_repository.dart';
import '../../budget/domain/cua_so_nhin_lai.dart';
import '../domain/cong_cu.dart';
import '../domain/hang_goi_y_han_muc.dart';
import '../domain/hang_so_lieu.dart';
import '../domain/loi_tham_so.dart';
import 'nguon_goi_so.dart';

class CongCuGoiYHanMuc implements CongCu {
  CongCuGoiYHanMuc(this.nganSach);
  final BudgetRepository nganSach;

  @override
  KhaiBaoCongCu get khaiBao => const KhaiBaoCongCu(
        ten: kTenCongCuGoiYHanMuc,
        moTa: 'Gợi ý hạn mức ngân sách MỖI THÁNG cho từng danh mục chi (theo TÊN): mức '
            'chi trung bình mỗi tháng suy từ các ngày gần nhất, kèm hạn mức hiện tại nếu '
            'danh mục đã có ngân sách. Gọi khi hỏi nên đặt ngân sách bao nhiêu, hạn mức '
            'có hợp lý không. danh_muc: tên một danh mục (tuỳ chọn).',
        thamSo: {
          'type': 'object',
          'properties': {
            'danh_muc': {
              'type': 'string',
              'description': 'Tên một danh mục chi. Bỏ trống để xem mọi danh mục.',
            },
          },
        },
      );

  @override
  Future<KetQuaCongCu> chay(
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
  }) async {
    var danhMuc = await nganSach.getExpenseCategories(idaccount);
    String? tenDaKhop;
    final hoi = args['danh_muc']?.toString().trim() ?? '';
    if (hoi.isNotEmpty) {
      switch (khopTheoTen<Category>(hoi, danhMuc, (c) => c.name)) {
        case KhopMot(:final muc):
          danhMuc = [muc];
          tenDaKhop = muc.name;
        case KhopNhieu(:final ds):
          return tuChoiKhopNhieu('danh_muc', hoi, [for (final c in ds) c.name],
              loai: 'danh mục chi');
        case KhongKhop():
          return tuChoiKhongKhop('danh_muc', hoi, [for (final c in danhMuc) c.name],
              loai: 'danh mục chi');
      }
    }

    final cuaSo = await nganSach.soNgayCuaSoNhinLai(idaccount, now: now);
    if (cuaSo == null) {
      return hangGoiYHanMuc(
        goiY: const [],
        soNgayCuaSo: null,
        soNgayConThieu:
            soNgayConThieu(await nganSach.soNgayCoDuLieu(idaccount, now: now)),
      );
    }

    // ⚠️ Chỉ ngân sách ĐANG CHẠY — ngân sách hết hạn không phải "đã có".
    final hanMuc = <String, double>{
      for (final v in nganSachDangChay(
        await nganSach.watchBudgets(idaccount, now: now).first,
        now,
      ))
        if (v.budget.categoryId != null) v.budget.categoryId!: v.budget.amount,
    };
    final goiY = <GoiYDanhMuc>[];
    for (final c in danhMuc) {
      final muc = await nganSach.suggestAmount(idaccount, c.id, now: now);
      if (muc == null) continue;
      goiY.add(GoiYDanhMuc(ten: c.name, mucThang: muc, hanMucHienTai: hanMuc[c.id]));
    }
    return hangGoiYHanMuc(
      goiY: goiY,
      soNgayCuaSo: cuaSo,
      soNgayConThieu: null,
      tenDaKhop: tenDaKhop,
    );
  }
}
