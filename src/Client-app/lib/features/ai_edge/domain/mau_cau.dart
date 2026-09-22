import 'bo_dien_giai.dart';
import 'goi_so.dart';
import 'nhan_xet.dart';

/// Bản thi công KHÔNG mô hình — chạy tức thì, offline, test được trọn vẹn.
/// Đây đã là "Edge AI" theo đúng định nghĩa của đặc tả: số từ tầng tất định,
/// câu từ mẫu.
class MauCau implements BoDienGiai {
  const MauCau();

  @override
  Future<NhanXet> dienGiai(GoiSo goi) async => goi.mauCau();
}
