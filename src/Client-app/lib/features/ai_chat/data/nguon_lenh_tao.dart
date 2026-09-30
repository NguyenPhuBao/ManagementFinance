/// C3 — nguồn ví / danh mục cho lệnh tạo ở màn Trợ lý AI. Đặt ở `ai_chat/` chứ không ở `ai_edge/`: phép lọc danh mục
/// CHI là phép so chiều tiền, mà test quét 14 cấm nó trong lớp AI.
library;

import '../../../core/database/app_database.dart';
import '../../../core/di/injection_container.dart';
import '../../ai_edge/domain/lenh_tao.dart';
import '../../category/data/repositories/category_management_repository.dart';

/// Ví HOẠT ĐỘNG (`getActive` — bộ chọn ví, không kể ví lưu trữ) và danh mục chi chọn được của [idaccount]. Lỗi đọc →
/// danh sách rỗng: lệnh vẫn chạy, chỉ không điền ví / danh mục.
Future<NguonLenhTao> napNguonLenhTao(int idaccount) async {
  List<MucChon> vi = const [];
  List<MucChon> danhMucChi = const [];
  try {
    vi = [for (final w in await sl<AppDatabase>().walletDao.getActive(idaccount)) (id: w.id, ten: w.name)];
  } catch (_) {}
  try {
    final ds = await sl<CategoryManagementRepository>().selectableChildrenAll(accountId: idaccount);
    danhMucChi = [
      for (final c in ds)
        if (!c.isDeleted && !c.isGroup && c.classify == 'chi') (id: c.id, ten: c.name),
    ];
  } catch (_) {}
  return (vi: vi, danhMucChi: danhMucChi);
}
