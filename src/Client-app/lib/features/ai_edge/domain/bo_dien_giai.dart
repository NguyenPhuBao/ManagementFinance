import 'goi_so.dart';
import 'nhan_xet.dart';

/// Giao diện chung của hai bản thi công: `MauCau` (P2) và `Slm` (P3). Cả hai
/// nhận **cùng** gói số; bản SLM rơi về `goi.mauCau()` khi mô hình chưa có,
/// máy yếu, hay câu sinh ra không qua bộ kiểm số.
abstract class BoDienGiai {
  Future<NhanXet> dienGiai(GoiSo goi);
}
