// lib/features/ai_edge/data/tai_tep_dio.dart
/// Phép tải tệp **thật** cho [MoHinhTaiVe] — bản Dio.
///
/// Tách khỏi `injection_container.dart` để **đo được**: mắt xích *"`huy()` có
/// cắt thật được kết nối không"* nằm ở đây, và một closure nằm giữa hàng trăm
/// dòng đăng ký DI thì không ca test nào với tới. Bản đầu viết inline trong DI,
/// và chính vì thế lỗi "nút Huỷ không dừng được lượt tải" sống qua cả hai task.
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'mo_hinh_tai_ve.dart';

/// ⚠️ **`Dio()` trần, cố ý KHÔNG phải `sl<DioClient>().dio`.**
///
/// `AuthInterceptor.onRequest` gắn `Authorization: Bearer <token>` vào **mọi**
/// request đi qua Dio của dự án, **không lọc theo host** — mà đích ở đây là
/// `huggingface.co`. Dùng chung là gửi access token của người dùng cho một bên
/// thứ ba, im lặng. Tải mô hình là một lượt GET tệp công khai, không cần thứ gì
/// của phiên đăng nhập.
///
/// [dio] chỉ để test tiêm bản riêng; đường chạy thật luôn dựng `Dio()` mới.
Future<void> taiTepQuaDio(
  String url,
  File dich,
  void Function(double phanTram) bao,
  DauHuy dauHuy, {
  Dio? dio,
}) async {
  // Nút "Huỷ" phải CẮT kết nối, không phải chỉ thôi vẽ tiến độ: bản đầu để
  // `huy()` đặt một cờ rồi vẫn `await` cho tới khi tải xong trọn 2,41 GB —
  // người dùng bấm Huỷ trên dữ liệu di động vẫn mất chừng ấy dung lượng, im
  // lặng. `CancelToken` là phép cắt thật của Dio.
  final chotHuy = CancelToken();
  unawaited(dauHuy.khiHuy.then((_) {
    if (!chotHuy.isCancelled) chotHuy.cancel('người dùng huỷ');
  }));

  // ⚠️ **Đừng thêm `dio.close(force: true)` ở nhánh huỷ.** Đã thử, và đo ở tầng
  // socket thô: `cancel()` một mình đã cắt kết nối (phía phát nhận FIN và
  // không gửi thêm gói nào); đóng thêm adapter chỉ bớt đúng **một gói đang
  // bay** — 64 KB trên một tệp 2,41 GB — đổi lấy việc đóng hộ một `Dio` do
  // người gọi đưa vào.
  //
  // ⚠️ Và đừng nghiệm thu chỗ này bằng `HttpServer` của `dart:io`:
  // `HttpResponse.flush()` **về trơn tru trên cả kết nối đã chết**, nên phép
  // đếm "server gửi thêm bao nhiêu" ở tầng ấy báo *vẫn đang chảy* trong khi
  // thực tế đã đứt. Xem `tai_tep_dio_test.dart`.
  await (dio ?? Dio()).download(
    url,
    dich.path,
    cancelToken: chotHuy,
    onReceiveProgress: (n, t) => bao(t > 0 ? n / t : 0),
  );
}
