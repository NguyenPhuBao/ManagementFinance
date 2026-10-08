import '../../../core/di/injection_container.dart';
import '../domain/quyen_tinh_nang.dart';
import 'goi_repository.dart';

/// Cửa quyền của những thứ chạy NỀN, không có `BuildContext` — bộ tự trả hoá đơn, bộ trích tự động, thông báo cân
/// đối ngân sách, nhập biến động số dư / biên lai (spec phân quyền 2026-10-08 mục 4.3 (3)). Không có quyền → người gọi
/// BỎ LƯỢT: không ghi gì, không đổi mốc, cờ của người dùng giữ nguyên (chốt *"dừng chạy, giữ công tắc"*).
///
/// Chưa có phiên (`idaccount == null`) → `true`: không có lượt nào chạy lúc ấy, và không đoán khi chưa biết tài khoản.
bool coQuyenNen(MaQuyen ma, {GoiRepository? goi, DateTime Function()? clock}) {
  final g = goi ?? sl<GoiRepository>();
  if (g.idaccount == null) return true;
  return duocDung(ma, g.hienTai, (clock ?? DateTime.now)());
}
