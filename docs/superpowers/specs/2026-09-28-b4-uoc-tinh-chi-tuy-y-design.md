# B4 — Khối Dự báo: tầng 3 *"ước tính theo thói quen"* — thiết kế

**Ngày:** 2026-09-28 (tối). **Người dùng mở lại quyết định 16/09** (*dự báo 30 ngày chỉ chiếu thứ đã biết chắc*) và
duyệt bản thiết kế trong chat cùng ngày, với các lựa chọn: khoảng **thấp – cao theo tuần** · **hiện ngay** (không công
tắc) · **không** vẽ lên biểu đồ · **không** dự báo thu nhập · hiện cả dòng *"còn khoảng A – B"*. Vị trí trong lộ trình
28/09: B1 → B5a → B2 → B3 → **B4** → B5b. **Không đổi schema.** Làm **sau B3** (dùng chung phép dời hàm của B3 Task 1).

## 1. Vì sao, và vì sao lần này khác 16/09

Khối *Dự báo 30 ngày tới* (mục 3.27 `ANALYTICS_FEATURE.md`) có hai tầng: **chắc chắn** (hoá đơn, trích tự động) và
**nếu tiêu đúng ngân sách**. Nó cố ý không đoán chi tuỳ ý, vì *"một con số đoán ngồi cạnh những con số thật"* sẽ mượn
độ tin của chúng. Hệ quả là người không đặt ngân sách thấy *"còn tiêu được 12 triệu"* trong khi mỗi tháng họ vẫn chi
khoảng 3 triệu ngoài hoá đơn.

B4 thêm tầng thứ ba mà **không** làm lại lỗi ấy:

- Tầng ước tính là **một dòng riêng**. Hai con số cũ và biểu đồ **không đổi**.
- Nó là một **khoảng**, không phải một con số, kèm số tuần dữ liệu đã dùng.
- Nó chỉ tính **phần chưa ai tính**: chi tuỳ ý ngoài hoá đơn, mục tiêu và ngân sách.

## 2. Chi tuỳ ý là gì — loại trừ để không đếm đôi

Một khoản là *chi tuỳ ý* khi đủ cả bốn điều:

1. Thuộc nhóm *Chi*: `phanLoaiCua(...) == 'chi'` **và** `khoanVaoThongKe(...)`, đúng định nghĩa của donut và của B3.
2. **Không** gắn hoá đơn hay mục tiêu. `KhoanThuChi` hôm nay **không** mang `billId` / `goalId`, nên thêm trường
   `final bool laKhoanCamKet;`, mặc định `false` để mọi chỗ dựng cũ không đổi. `AnalyticsRepositoryImpl._dung` đặt
   `t.billId != null || t.goalId != null`. Thiếu vế này thì lịch sử trả hoá đơn nằm trong ước tính, trong khi hoá đơn
   30 ngày tới đã ở tầng 1. Đo 2026-09-28: khoản *"Tích lũy mục tiêu: MuaXe 500.000 đ"* có lúc là **chi**, không phải
   chuyển ví.
3. Danh mục **không** có ngân sách đang chạy (ngân sách chưa hết hạn, `categoryId` khác null, trong `nganSachHomNay`).
   Những danh mục ấy đã ở tầng 2.
4. ⚠️ Nếu đang có **ngân sách tổng** (`categoryId == null`, chưa hết hạn) thì tầng 3 **im hẳn** (`null`): tầng 2 đã phủ
   mọi khoản chi, và mọi con số tầng 3 sẽ là đếm đôi.

## 3. Hàm thuần — `lib/features/analytics/domain/uoc_tinh_chi_tuy_y.dart`

`UocTinhChiTuyY? uocTinhChiTuyY(List<KhoanThuChi> khoan, {required DateTime now, required CuaSoNhinLai? cuaSo, required Set<String> danhMucCoNganSach, required bool coNganSachTong})`

- `cuaSo == null` (tài khoản quá trẻ) hoặc `coNganSachTong` → `null`.
- **Tuần** = tuần ISO (thứ Hai 00:00 → thứ Hai kế), dùng `bienTuan` ở `core/notification/tuan_iso.dart` (một định nghĩa,
  cùng bộ chọn kỳ và *Tổng kết tuần*). Chỉ lấy tuần **đã đóng** nằm **trọn** trong `[cuaSo.from, now)`. Tuần đầu bị
  cửa sổ cắt ngang thì bỏ, vì nửa tuần sẽ kéo phân vị xuống.
- Cần **≥ 4** tuần. Tuần không có khoản chi tuỳ ý nào vẫn tính là **0**: đó là số liệu thật (khác B3, nơi tháng 0 bị bỏ
  vì câu hỏi khác).
- `thap = lamTronBuoc(p25 × 30 / 7, 10.000)`, `cao = lamTronBuoc(p75 × 30 / 7, 10.000)`. Phân vị nội suy tuyến tính.
  `cao == 0` (người không có chi tuỳ ý) → `null`, vì một dòng *"khoảng 0 – 0 đ"* chỉ là tiếng ồn.
- Kết quả `UocTinhChiTuyY { double thap; double cao; int soTuan; }`.
- `lamTronBuoc` hôm nay ở `ai_edge/domain/tai_phan_bo.dart:47`, nên **dời** về `analytics/domain/nguong_co_nghia.dart`
  (tệp B3 Task 1 tạo) và `tai_phan_bo.dart` import lại. Không đổi hành vi.

## 4. Nguồn và hiện

- `ThongKeKy.uocTinhChiTuyY` (tuỳ chọn, mặc định `null`), tính trong `_dung` từ `khoan` và `nganSachHomNay` sẵn có. Không
  stream mới, không đọc CSDL lần nữa. Không phụ thuộc kỳ đang xem (cùng lý lẽ tầng 2 tra ngân sách tại `now`).
- **Khối Dự báo** (`analytics_page.dart`), ngay dưới dòng *"nếu tiêu đúng ngân sách"*, một dòng mới:
  *"Nếu tiêu như thói quen ({soTuan} tuần gần nhất): chi thêm khoảng {thap} – {cao}, còn khoảng {A} – {B}."*, với
  `goc = duBao.conTieuDuocTheoNganSach` (bằng `conTieuDuoc` khi `!coNganSach`, vì `nganSachConLai` = 0 —
  `du_bao_dong_tien.dart:166–168`), `A = goc − cao`, `B = goc − thap`. Đọc getter có sẵn, không tính lại ở widget. Tiền qua `CurrencyFormatter`; A/B **được phép âm** (cùng luật khối Dự báo: không kẹp). Chữ màu phụ và cỡ nhỏ
  hơn, để không tranh với hai con số chính.
- Biểu đồ bậc thang **không đổi**.
- ⚠️ Khối có thêm một dòng → **cập nhật màn Stitch trước** (khối Dự báo, màn của mục 3.27). ✅ **Màn mới
  `7aa215e9bfee4ec58b15a012ced7e210`** *"Thống kê - Dự báo 30 ngày tới + ước tính theo thói quen"* (2026-09-29; lượt
  gọi trả **timeout**, màn hiện sau, người dùng xác nhận): dòng mới đứng **ngay dưới** hàng *"Nếu tiêu đúng ngân sách"*,
  đệm trên 4 px, chữ **12 px thường, xám `#767873`**, không biểu tượng, không hộp; phần còn lại y hệt màn cũ
  `73258777…`.
- Tool `du_bao_dong_tien` của Trợ lý AI **không** đổi (trần `tools_json`). Khối Nhận xét trang Phân tích **không** đổi.

## 5. Giới hạn nói trước

- Danh mục có ngân sách **hết kỳ trước mốc 30 ngày** thì phần sau kỳ không được ước tính (tầng 2 dừng ở cuối kỳ ngân
  sách, tầng 3 loại danh mục ấy). Không vá: vá là phải đoán kỳ ngân sách sau.
- Ước tính **không biết** kế hoạch sắp tới của người dùng (một chuyến du lịch). Nhãn *"nếu tiêu như thói quen"* nói đúng
  điều ấy.
- Không dự báo thu nhập (người dùng chốt).

## 6. Kiểm thử

- **Hàm thuần:** tám tuần có chi tuỳ ý (có hai tuần 0) → khoảng đúng phân vị tính tay; 3 tuần → `null`; tuần đầu bị cắt
  ngang không vào mẫu; khoản gắn hoá đơn (`laKhoanCamKet`) và khoản thuộc danh mục có ngân sách không vào; có ngân sách
  tổng → `null`; không có chi tuỳ ý nào → `null`; tuần vắt qua năm (29/12/2025 – 4/1/2026, tuần 1 ISO 2026) được cắt
  bằng `bienTuan` chứ không bằng `year`.
- **`KhoanThuChi.laKhoanCamKet`:** mặc định `false`; repository đặt đúng từ `billId` / `goalId` (ca test repository).
- **Phép dời `lamTronBuoc`:** test `tai_phan_bo` xanh không sửa kỳ vọng.
- **Widget:** khối Dự báo có dòng mới với đúng bốn con số; `uocTinhChiTuyY == null` → khối **y hệt** trước (mọi ca cũ
  xanh); A âm hiện dấu âm đúng quy ước `CurrencyFormatter`; khổ 411 dp không tràn.
- **Máy ảo:** tài khoản thật (dữ liệu từ 02/09) đã có khoảng 3 tuần đóng, nên dòng **im**; sau 4 tuần đóng thì dòng hiện.
  Nghiệm thu bằng tài khoản thử có dữ liệu ghi lùi ngày.

## 7. Tài liệu đi kèm

`ANALYTICS_FEATURE.md` mục 3.27 thêm khối *Tầng 3 — ước tính theo thói quen (B4, mở lại quyết định 16/09)*; banner ở đầu
3.27 rằng câu *"không chi tuỳ ý"* nay chỉ còn đúng cho **hai tầng đầu**. `CLAUDE.md` hàng *Đụng vào trang Phân tích*, câu
về dự báo. `PROJECT_CONTEXT.md` mục 14.
