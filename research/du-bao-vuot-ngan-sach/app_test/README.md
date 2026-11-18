# Kiểm thử trên hệ thống thật (2026-11-10)

Thiết lập: app FlowMoney bản debug dựng từ nhánh `TranQuangDat` (mã app không sửa), máy ảo Android 16
`FlowMoney_NCKH` (1080×2400), backend Node của dự án chạy cục bộ trên CSDL PostgreSQL `PersonFinance`
(không nối Redis dùng chung). Năm người dùng TabFormer đã chuyển sang chuẩn VN (`experiment/app_users.py`):
mỗi người lấy tháng 11 của một năm 2016–2019 cùng 7 tháng trước, dời nguyên năm sang 2026, tới ngày 10/11
(khoản ngày 10 kẹp ≤ 08:00); thêm một khoản lương giả ngày 1 mỗi tháng để ví không âm (khoản thu không vào
dự báo chi). Nạp qua API đồng bộ của chính app (`experiment/app_load.py`, `app_run_user.sh`): đăng ký tài
khoản `nckh_uN`, đăng nhập trên máy ảo, đẩy giao dịch + ngân sách tổng hằng tháng từ 01/11/2026 với
B = trung bình chi 3 tháng trước (cùng B của thí nghiệm), mở app, vào Ngân sách → Ngân sách tổng.

Đối chiếu: `experiment/dart_check/app_check.dart` chạy nguyên `nhip_chi.dart` của app ngoài `src/` trên cùng
dữ liệu, cùng giờ máy lúc chụp (`uN_dart.txt`). "Theo nhịp thường lệ" trên màn = B × phanDaChiMoiKhi(x).

| # | Bậc | B | Đã chi 10/11 | Chip app | Theo nhịp thường lệ: app | Dart | Dự phóng S+r_med | Cuối tháng thật | p1 · p2 · p3 (thí nghiệm, t = 10) |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Đi làm ổn định | 16.054.000 | 3.511.000 | Chậm hơn dự kiến | 4.965.176 | 4.965.176 | 12.631.000 | 16.986.000 (vượt) | 0,21 · 0,18 · 0,15 |
| 2 | Mới đi làm | 6.404.000 | 1.767.000 | Chậm hơn dự kiến | 2.198.954 | 2.198.954 | 6.076.000 | 8.609.000 (vượt) | 0,21 · 0,33 · 0,28 |
| 3 | Thu nhập cao | 22.961.000 | 5.680.000 | Đúng nhịp | 5.717.261 | 5.717.261 | 22.874.500 | 18.400.000 | 0,50 · 0,14 · 0,15 |
| 4 | Sinh viên | 3.226.000 | 1.476.000 | Nhanh hơn dự kiến | 878.969 | 878.969 | 4.276.500 | 2.859.000 | 0,79 · 0,84 · 0,84 |
| 5 | Sinh viên | 4.128.000 | 798.000 | Chậm hơn dự kiến | 1.266.831 | 1.266.831 | 2.858.500 | 3.043.000 | 0,21 · 0,22 · 0,15 |

Kết quả: 5/5 khớp từng đồng; app học đủ 6 kỳ (K = 6) như thí nghiệm. Hai ca (#1, #2) vượt ngân sách mà cả app
lẫn ba phương pháp đều báo thấp ở ngày 10; #4 là báo động nhầm của cả ba; #3 dự phóng của app sát B (22,87 /
22,96 triệu) còn p1 = 0,50. App không hiện xác suất — p1–p3 là phần bài thêm.

Tài khoản thử trên PersonFinance: `nckh_u1`…`nckh_u5` (idaccount 32–36), mật khẩu trong `app_load.py`; không xoá.
Môi trường: phải `npx prisma generate` trong `src/Backend` (client sinh sẵn thiếu cột `idfund_pair` → mọi
giao dịch bị từ chối `CONSTRAINT_VIOLATION`); người dùng cho phép đích danh 2026-11-10.

## M2 và M3 chạy trong app — bản thử (2026-11-10, nhánh TranQuangDat, không phát hành)

Mã: `src/Client-app/lib/features/budget/domain/du_bao_vuot_ngan_sach.dart` (chép `core.build_rows` theo ngày) +
`he_so_m3_vn.g.dart` (M3 khớp MỘT lần trên TabFormer-VN, tháng < 17, 4.000 dòng, seed 2026 — `experiment/app_m23.py`;
bài dùng khớp cuộn 6 tháng) + `data/du_bao_vuot_nguon.dart` (ngân sách tổng, tháng dương lịch; tháng đầu = tháng của
khoản chi sớm nhất). Thẻ Nhịp chi hiện "Xác suất vượt (thử nghiệm): M1 · M2 · M3"; bản debug in sáu chữ số
(`uN_m23_log.txt`). Đo lại 5 người trên máy ảo ngày 10/11/2026 (`sh experiment/app_m23_user.sh N`, ảnh `uN_detail_m23.png`),
so với Python trên cùng dữ liệu app (`results/app_m23.json`, tháng 4–11/2026, t = 10):

| # | p1 app | p2 app | p3 app | Lệch tối đa so với Python |
|---|---|---|---|---|
| 1 | 0,214286 | 0,173829 | 0,136914 | 3,6·10⁻⁷ |
| 2 | 0,214286 | 0,308193 | 0,292581 | 3,7·10⁻⁷ |
| 3 | 0,500000 | 0,123504 | 0,147117 | 1,9·10⁻⁷ |
| 4 | 0,785714 | 0,816814 | 0,811217 | 3,8·10⁻⁷ |
| 5 | 0,214286 | 0,196897 | 0,145438 | 3,5·10⁻⁷ |

(lệch còn lại là do log làm tròn sáu chữ số). Số p2/p3 khác cột "thí nghiệm" ở bảng trên vì app chỉ có dữ liệu từ
tháng 4/2026 và M3 dùng hệ số khớp một lần.

Kiểm số lượng lớn, cùng mã app:
- Tầng 1 (`experiment/app_bulk.py` + `dart_check/app_bulk.dart`): 328.670 dòng, 1.518 người — 0 dòng lệch `core.py`
  > 1e-6; Brier mã app M1 0,1657 · M2 0,1492 · M3 0,1481 (`results/app_bulk.json`).
- Tầng 2 (`src/Client-app/test/features/budget/data/du_bao_vuot_nguon_test.dart`, ca `experiment/app_drift_cases.py`):
  300 người, 985.834 giao dịch qua CSDL Drift của app kèm 5 loại hàng phải bỏ qua — 0 dòng lệch > 1e-6
  (`results/app_drift.json`).
