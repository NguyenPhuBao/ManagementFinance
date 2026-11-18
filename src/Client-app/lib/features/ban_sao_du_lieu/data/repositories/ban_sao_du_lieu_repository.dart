import '../models/yeu_cau_ban_sao.dart';

/// Cổng duy nhất trang "Dữ liệu của tôi" gọi (quét 31 cấm trang import datasource API).
/// Lỗi ném ra là `LoiBanSao` (`data/datasources/ban_sao_du_lieu_api.dart`); lưu tệp hỏng ném lỗi nền tảng.
abstract class BanSaoDuLieuRepository {
  Future<YeuCauBanSao?> layMoiNhat();
  Future<YeuCauBanSao> yeuCau();

  /// Tải tệp rồi lưu: đường dẫn hiển thị, hoặc `null` khi đã mở sheet chia sẻ.
  Future<String?> taiVaLuu(String id, String dinhDang);
}
