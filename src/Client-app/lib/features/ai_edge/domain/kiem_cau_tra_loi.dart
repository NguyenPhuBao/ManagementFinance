/// Phép kiểm MỘT CÂU trả lời của màn Trợ lý AI — **định nghĩa duy nhất**, để
/// đường streaming (`gacTheoCau`) và mọi chỗ khác không mỗi nơi gọi một tổ
/// hợp khác nhau.
///
/// Sáu lớp chắn, thiếu lớp nào cũng đã vấp thật:
/// - `kiemSoNhieuGoi` — số bịa (điều kiện 10 đặc tả gốc);
/// - `kiemNhan` — số thật gán tên sai (mục 9.5 `AI_EDGE_FEATURE.md`);
/// - `kiemGiong` — giọng ngược mức. ⚠️ Trước 2026-09-22 đường hỏi đáp **không
///   gọi** lớp này; điểm 5 cổng A ghi "chưa đo" nhưng thật ra là chưa nối;
/// - `kiemTen` — tên bịa trong câu **không có số** (bẫy 4.48, cổng D lần 10 B1
///   *"mục tiêu mua xe hoặc mua nhà"* — ba lớp trên không có gì để kiểm);
/// - `kiemPhuDinh` — câu không số nói *"không có dữ liệu"* trong khi tool vừa
///   trả hàng (bẫy 4.52, lát 1 mở rộng tool, câu L5);
/// - `kiemKy` — chữ kỳ của câu lệch kỳ của con số (G5 (b) cổng F, E21 *"Thu hôm
///   nay là 15.135.000 đ"* với số tháng này).
library;

import 'goi_so.dart';
import 'kiem_giong.dart';
import 'kiem_ky.dart';
import 'kiem_nhan.dart';
import 'kiem_phu_dinh.dart';
import 'kiem_so.dart';
import 'kiem_ten.dart';
import 'nhan_xet.dart';

/// Mức của cả câu trả lời khi nó rút số từ **nhiều** gói: có gói cảnh báo thì
/// cả câu không được trấn an — người hỏi về ví mà đọc "yên tâm" trong khi
/// ngân sách đã 90 % là sai theo chiều nguy hiểm. Không gói nào cảnh báo thì
/// bình thường; gói thiếu dữ liệu không kéo mức về đâu cả.
MucNhanXet mucTongHop(List<GoiSo> goi) {
  final mucs = [for (final g in goi) g.mauCau().muc];
  if (mucs.contains(MucNhanXet.canhBao)) return MucNhanXet.canhBao;
  if (mucs.contains(MucNhanXet.binhThuong)) return MucNhanXet.binhThuong;
  return MucNhanXet.thieuDuLieu;
}

bool kiemCauTraLoi(String cau, List<GoiSo> goi) =>
    kiemSoNhieuGoi(cau, goi) &&
    kiemNhan(cau, goi) &&
    kiemGiong(cau, mucTongHop(goi)) &&
    kiemTen(cau, goi) &&
    kiemPhuDinh(cau, goi) &&
    kiemKy(cau, goi);
