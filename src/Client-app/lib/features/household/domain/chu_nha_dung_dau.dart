import 'vai_nha.dart';

/// Chủ nhà đứng đầu, còn lại giữ thứ tự máy chủ trả (Stitch `e462a7e8…`, `quan_ly_tv`). Sắp ổn định, trả danh sách MỚI: không
/// đụng danh sách gốc (kho đồng bộ ghi theo thứ tự server). Dùng chung cho Nhà mình và Quản lý thành viên.
List<T> chuNhaDungDau<T>(List<T> ds, VaiNha Function(T) vaiCua) =>
    [...ds.where((t) => vaiCua(t) == VaiNha.chu), ...ds.where((t) => vaiCua(t) != VaiNha.chu)];
