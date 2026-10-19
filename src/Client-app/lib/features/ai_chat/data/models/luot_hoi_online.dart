/// Một lượt hỏi trợ lý online đang chạy: luồng sự kiện SSE + hàm huỷ. Hàm huỷ là Dart thuần để trang không cầm
/// `CancelToken` của Dio (quét 31, mục 8 `KIEN_TRUC_CLIENT_APP.md`).
library;

import '../../domain/su_kien_online.dart';

class LuotHoiOnline {
  const LuotHoiOnline({required this.suKien, required this.huy});

  /// Kết thúc bằng đúng một sự kiện cuối ([XongOnline] / [DuPhongOnline] / [LoiOnline]) — hợp đồng của datasource.
  final Stream<SuKienOnline> suKien;

  /// Cắt yêu cầu đang chạy; [lyDo] chỉ để log. Gọi sau khi luồng đã xong thì vô hại.
  final void Function(String lyDo) huy;
}
