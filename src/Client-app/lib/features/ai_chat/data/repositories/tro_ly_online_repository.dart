import '../../domain/su_kien_online.dart';
import '../models/luot_hoi_online.dart';

/// Cổng của trang Trợ lý AI tới chatbot backend (spec trợ lý online 2026-10-11) — bọc `TroLyOnlineRemoteDataSource`, giấu
/// `CancelToken`. Không luật nghiệp vụ: luật rơi ở `domain/duong_hoi.dart`.
abstract class TroLyOnlineRepository {
  LuotHoiOnline hoi({required String cauHoi, required String conversationId, required List<TinLichSu> history});
}
