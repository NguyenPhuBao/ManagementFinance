/// Lề hai đầu trục ngang cho biểu đồ đường **có vẽ chấm** (G79), tính theo
/// phần của cả dải.
///
/// Chấm của kỳ đầu và kỳ cuối nằm đúng `minX`/`maxX`, tức đúng mép vùng vẽ.
/// G55 đặt `FlClipData.vertical()` để chỉ cắt trên/dưới, nhưng trong fl_chart
/// 1.2.0 nó **vẫn cắt nửa chấm ở mép trái** (đo bằng ảnh, 2026-10-07; ca canh ở
/// `bieu_do_cham_test`) — trên Realme chấm T5/T10 mất nửa.
/// Bỏ cắt hẳn thì mất lớp phòng thủ của bẫy 4.17, nên lối chữa là **nới trục**
/// để chấm nằm trọn trong vùng vẽ.
///
/// 5 % dải ≈ 8,6 dp ở vùng vẽ hẹp nhất của app (~190 dp, trang Phân tích ở
/// 320 dp), đủ cho chấm to nhất (bán kính 5, viền 2).
const double kLeTrucCoCham = 0.05;

/// Dải trục ngang đã nới cho các điểm trải từ [min] tới [max].
({double min, double max}) trucNgangCoCham(double min, double max) {
  final dai = max - min;
  final le = dai > 0 ? dai * kLeTrucCoCham : 0.5;
  return (min: min - le, max: max + le);
}

/// Mốc trục [v] có đúng là một chỉ số kỳ (số nguyên) không.
///
/// fl_chart hỏi nhãn ở **cả hai biên** cộng các bội của `interval`; biên đã nới
/// là số lẻ (-0,25) mà `round()` ra 0, nên thiếu phép kiểm này thì nhãn kỳ đầu
/// in hai lần lệch nhau vài dp.
bool laMocChiSo(double v) => (v - v.roundToDouble()).abs() < 1e-6;
