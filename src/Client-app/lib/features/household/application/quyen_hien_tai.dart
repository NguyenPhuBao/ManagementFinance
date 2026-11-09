/// "Lúc Lưu, tôi còn làm được [viec] ở nhà [idNha] không" — MỘT định nghĩa cho cả bốn form ghi dữ liệu nhà (khoản, danh mục,
/// góp / rút, ví chung; FINAL I-3). Đọc [NhaRepository.hienTai] lúc gọi, không chụp lúc mở form: vai có thể đổi giữa chừng
/// (hạ vai, nhà thành chỉ xem), mà server từ chối sau đó thì hàng kẹt `pending` hoặc bị xoá không báo gì.
library;

import '../data/repositories/nha_repository.dart';
import '../domain/quyen_nha.dart';

bool conDuocLamViecNha(NhaRepository repo, int idNha, ViecNha viec) {
  final t = repo.hienTai;
  final nha = t.nha;
  return nha != null && nha.id == idNha && duocLamViecNha(viec, vai: t.vai, trangThai: nha.trangThai);
}
