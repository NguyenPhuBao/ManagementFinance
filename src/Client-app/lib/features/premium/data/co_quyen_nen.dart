import '../../../core/di/injection_container.dart';
import '../domain/quyen_tinh_nang.dart';
import 'repositories/goi_repository.dart';

/// Cửa quyền của những thứ chạy NỀN, không có `BuildContext` — bộ tự trả hoá đơn, bộ trích tự động, thông báo cân
/// đối ngân sách, nhập biến động số dư / biên lai (spec phân quyền 2026-10-08 mục 4.3 (3)). Không có quyền → người gọi
/// BỎ LƯỢT: không ghi gì, không đổi mốc, cờ của người dùng giữ nguyên (chốt *"dừng chạy, giữ công tắc"*).
///
/// Chưa có phiên (`idaccount == null`) → `true`: không đoán khi chưa biết tài khoản. Vì thế mọi lượt quét phải đặt gói
/// TRƯỚC — đường nền qua `datGoi` của `LuotNen`, đường trong app qua hook `datGoi` của `PhienDieuPhoiThat.moPhienCucBo`
/// (G93: thiếu nó thì lượt quét đầu mỗi phiên, chạy trước `AuthSuccess`, thả Basic qua).
bool coQuyenNen(MaQuyen ma, {GoiRepository? goi, DateTime Function()? clock}) {
  final g = goi ?? sl<GoiRepository>();
  if (g.idaccount == null) return true;
  return duocDung(ma, g.hienTai, (clock ?? DateTime.now)());
}
