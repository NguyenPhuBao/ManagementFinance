/// Lời từ chối tham số chung cho các tool bước 2 (spec mục 3.9). Tool từ chối
/// vẫn TÍNH LÀ ĐÃ CHẠY (chốt L1 của 4b) và tốn một suất trong trần 3; lời phải
/// đủ để mô hình gọi lại đúng ngay lần sau.
library;

import 'hang_so_lieu.dart';

String loiGiaTri(String thamSo, Object? giaTri, Iterable<String> hopLe) =>
    '$thamSo "$giaTri" không hợp lệ. Chỉ nhận: ${hopLe.join(', ')}.';

KetQuaCongCu loiKhongKhop(String thamSo, String hoi, List<String> tenCo) =>
    KetQuaCongCu.loi(
      '$thamSo "$hoi" không khớp tên nào. Chỉ có: ${tenCo.join(', ')}.',
      tenLienQuan: tenCo,
    );

KetQuaCongCu loiKhopNhieu(String thamSo, String hoi, List<String> tenKhop) =>
    KetQuaCongCu.loi(
      '$thamSo "$hoi" khớp nhiều tên: ${tenKhop.join(', ')}. '
      'Gọi lại với đúng một tên.',
      tenLienQuan: tenKhop,
    );
