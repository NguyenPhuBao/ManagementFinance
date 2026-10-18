/// Hằng và enum của gói (spec Premium 2026-10-06 mục 5.1 / 5.2; tách khỏi `trang_thai_goi.dart` ·
/// `tran_goi.dart` ở spec G94 2026-10-18 mục 4.1 để model sang `data/models/` mà không vòng import).
///
/// Giá và số ngày mặc định của gói — server đè bằng `price` / `packageDays`
/// của `/payment/subscription-info` khi backend thêm hai trường ấy (đơn
/// CAN-LAM); tới lúc đó đây là con số của `.env` backend ngày 2026-10-06.
const int kGiaPremium = 49000;
const int kSoNgayGoi = 30;

enum LoaiGoi { basic, premium }

/// Loại bản ghi có trần ở gói Basic (`TranGoi.cua`, `conTaoDuoc`).
enum LoaiTran { vi, nganSach, mucTieu, hoaDon, danhMucRieng }
