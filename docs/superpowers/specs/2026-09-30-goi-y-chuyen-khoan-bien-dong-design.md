# Gợi ý Chuyển khoản từ biến động số dư — thiết kế

**Ngày:** 2026-09-30 · **Trạng thái:** đã duyệt trong chat (người dùng chốt ba câu hỏi, rồi duyệt thiết kế) ·
**Việc sau D1 số 2** (`docs/BIEN_DONG_SO_DU_FEATURE.md` mục 6) · **Stitch:** màn *"Thêm giao dịch - Gợi ý chuyển khoản
từ biến động"* (lượt tạo trả về timeout — mã màn ghi vào đây khi màn hiện ra).

## 1. Vì sao

Form mở từ một hàng biến động số dư (D1) luôn ghi **Chi tiêu** hoặc **Thu nhập**. Tiền chuyển giữa hai ví của chính người
dùng mà ghi như thế là đếm đôi: một khoản chi ở ví này, một khoản thu ở ví kia — thống kê chi/thu sai, trong khi thứ
thật sự xảy ra là một **chuyển khoản** (`type = 'transfer'`, bị `khoanVaoThongKe` loại khỏi thống kê).

### 1.1 Dữ liệu thật lật giả định ban đầu

Luật được chốt lúc đầu là *"cặp biến động chi + thu cùng tiền, ≤ 5 phút, hai nguồn khác"*. Đo năm hàng đang chờ trên
Realme (tài khoản 10, 2026-09-30):

| Hàng | Nội dung tin (đã qua `docTinBienDong`) | Thật ra là |
|---|---|---|
| +10.000 · MB Bank ×3 | `149346965345-TRAN QUANG DAT chuyen tien qua MoMo-CHUYEN TIEN-OQCH000LKkVs-MOMO149346965345MOMO` | rút từ MoMo về MB |
| −10.000 · MB Bank ×2 | `TRAN QUANG DAT chuyen tien` | chuyển MB → MoMo |

**MoMo không bắn tin nào** ở cả hai chiều (đã ghi ở bàn giao D1: MoMo / ZaloPay không bắn tin khi chuyển đi; lượt đo này
cho thấy chiều nhận từ ngân hàng cũng không). Luật cặp một mình sẽ **0 lần** gợi ý với ba nguồn đang đọc (MB Bank ·
MoMo · ZaloPay) — nó chỉ bắt được khi **cả hai phía** đều đăng tin (giữa hai ngân hàng; chưa đo). Người dùng chốt:
**cả hai luật** — cặp **và** nội dung tin.

## 2. Phép nhận — hàm thuần `transaction/domain/goi_y_chuyen_khoan.dart`

```dart
class GoiYChuyenKhoan {
  final String nguonTu;   final String? duoiTu;   // nguồn tiền ĐI
  final String nguonDen;  final String? duoiDen;  // nguồn tiền ĐẾN
  final String? khoaCap;  // dedupeKey của hàng đi cặp (luật cặp); null = luật nội dung
}

GoiYChuyenKhoan? goiYChuyenKhoan(DienSanBienDong d, List<DienSanBienDong> dangCho);
String? nguonNhacTrongTin(String noiDung, {required String nguonCuaTin});
```

- **Đầu vào `dangCho`**: mọi hàng loại 20 chưa gạt của tài khoản, dựng từ `deeplink` bằng **đúng**
  `dienSanBienDongTuQuery` (một hợp đồng query, không đọc lại `title` / `body`). Hàng không dựng được thì bỏ.
- **Thiếu `soTien` / `chieu` ở hàng đang mở → `null`** (không đủ căn cứ cho cả hai luật).

### 2.1 Luật cặp (xét trước)

Hàng khác `p` (`p.khoa != d.khoa`) thoả **cả bốn**: `p.chieu` ngược `d.chieu` · `|p.soTien − d.soTien| < 0.5` (ngưỡng
nửa đồng, `amount` là `double`) · cả hai có `thoiGian` và lệch **≤ 5 phút** · `p.nguon != d.nguon`.

- Nhiều hàng thoả → lấy hàng lệch giờ **nhỏ nhất**; hai hàng cùng lệch nhỏ nhất → **`null`** (mơ hồ — gợi ý sai ví tệ
  hơn không gợi ý).
- Hướng: hàng **chi** là nguồn ĐI, hàng **thu** là nguồn ĐẾN; `duoi` đi theo hàng của nó. `khoaCap = p.khoa`.

### 2.2 Luật nội dung

`nguonNhacTrongTin(d.ghiChu, nguonCuaTin: d.nguon)` — nội dung nhắc **đúng một** nguồn khác nguồn của tin:

| Nguồn | Từ nhận ra (trọn từ, không phân biệt hoa thường, so sau khi bỏ dấu) |
|---|---|
| MoMo | `momo` |
| ZaloPay | `zalopay`, `zalo pay` |
| MB Bank | `mb bank`, `mbbank` (**không** `mb` trần — quá ngắn, trùng mã GD) |
| Vietcombank | `vietcombank`, `vcb` |
| Techcombank | `techcombank`, `tcb` |
| BIDV | `bidv` |

- **"Trọn từ" tính cả biên chữ ↔ số**: `MOMO149346965345MOMO` phải nhận ra `momo` (tin MB dính mã GD liền chữ). Biên là
  chuyển giữa chữ cái và không-chữ-cái; chữ cái liền trước / sau thì không nhận (`momoney` không phải MoMo).
- Nhắc chính nguồn của tin → bỏ qua. Nhắc **≥ 2** nguồn khác → `null` (mơ hồ). *Tin nhắn (SMS)* không có từ nhận ra.
- Hướng: hàng **thu** → ĐI = nguồn được nhắc, ĐẾN = nguồn của tin; hàng **chi** → ngược lại. `duoi` phía được nhắc là
  `null` (tin không mang số tài khoản phía kia). `khoaCap = null`.

Trên dữ liệu thật: bắt **3/5** hàng. Hai hàng −10.000 không bắt được — `docTinBienDong` cắt phần `DEN: <tên> - PSP<số>`;
giữ phần ấy là việc khác, **ngoài phạm vi** (§7).

## 3. Chọn ví

- **Phía nguồn của tin**: luật D1 hiện có — `ViTheoNguonStore.doc(id, d.nguon, d.duoi)`, chỉ nhận ví **hoạt động**.
- **Phía kia** (người dùng chốt): (1) `ViTheoNguonStore.doc(id, nguonKia, duoiKia)` trong ví hoạt động → (2) ví hoạt động
  **duy nhất** có tên chứa tên nguồn (so bằng `normalizeCategoryName` + bỏ khoảng trắng, không bỏ dấu — quy tắc 7;
  *"Ví MoMo"* chứa *"momo"*) → (3) trống. Hai ví cùng chứa tên → trống (không đoán).
- Luật cặp: phía kia cũng có `duoi` thật (từ hàng cặp) nên bước (1) dùng đúng đuôi ấy.

Phép chọn ví theo tên là hàm thuần trong cùng tệp (`viTheoTenNguon(nguon, wallets)`), để test không cần dựng trang.

## 4. Giao diện — form mở từ biến động

- Sau khi `_dienTuBienDong` điền xong, form đọc các hàng đang chờ (tham số tiêm `hangBienDongCho`, mặc định đọc
  `NotificationDao.getAll` lọc loại 20 chưa gạt) rồi gọi `goiYChuyenKhoan`. Lỗi đọc → không gợi ý, không chặn gì.
- Có gợi ý → **thẻ gợi ý** ngay dưới dải nguồn (Stitch): biểu tượng `swap_horiz`, *"Có vẻ là chuyển khoản"*, dòng phụ
  *"Từ MoMo sang MB Bank"*, nút viền **Ghi là chuyển khoản** (`Key('goi-y-chuyen-khoan')`).
- Bấm nút: `_chonHuong('transfer')` (đúng đường người dùng chạm đoạn), đặt `_selectedWallet` = ví ĐI và
  `_destinationWallet` = ví ĐẾN — ô nào không đoán được thì **để trống** (không rơi về ví mặc định, cùng lý do D1 §3.3);
  đặt `_nguoiDungDaChonVi = true`; thẻ ẩn. **Không lưu** (bất biến ④ nhóm C).
- Người dùng tự đổi đoạn về Chi / Thu sau đó: không khôi phục gì — form đi theo lựa chọn tay như mọi khi.
- Thẻ không hiện ở đường sửa, đường tạo mới thường, và khi form đã ở đoạn Chuyển khoản.

## 5. Lưu

Lưu khi form ở đoạn Chuyển khoản **và** đã áp gợi ý (`_goiYDaApDung != null`):

- Xoá cứng hàng đang mở (như D1) **và** hàng `khoaCap` nếu có — không thì hàng cặp vẫn chờ ghi và người dùng ghi đôi.
- Nhớ ví cho **cả hai** nguồn, mỗi phía theo luật "chỉ ghi ở lần đầu của cặp nguồn + đuôi": phía ĐI ←
  `_selectedWallet`, phía ĐẾN ← `_destinationWallet`.
- ⚠️ **Sửa đường nhớ ví hiện có**: `_dongBienDong(..., viDaLuu: _selectedWallet)` giả định ví của nguồn tin là ví nguồn.
  Hàng **thu** ghi thành chuyển khoản thì ví của nguồn tin là **ví đích** — nhớ `_selectedWallet` là gắn ví MoMo vào
  cặp *MB Bank · 262*, và mọi tin MB sau đó chọn sẵn sai ví, **im lặng**. Nay ví nhớ cho nguồn tin lấy theo **phía** của
  nguồn tin trong gợi ý.
- Không áp gợi ý mà người dùng tự chạm đoạn Chuyển khoản: giữ hành vi D1 hiện nay (không đụng tới trong lát này).

## 6. Kiểm thử

- `goi_y_chuyen_khoan_test.dart` (thuần): nguyên văn ba tin *"qua MoMo"* và tin −10.000 thật; cặp hai nguồn (hướng,
  đuôi, `khoaCap`); cặp cùng nguồn không nhận; lệch 5 phút có / 6 phút không; hai ứng viên cùng lệch → `null`; nhắc
  chính nguồn → `null`; nhắc hai nguồn → `null`; `MOMO` dính số nhận, `momoney` không; `mb` trần không nhận; thiếu
  `soTien` → `null`; `viTheoTenNguon` (một ví khớp · hai ví · không ví · ví lưu trữ bị loại ở chỗ gọi).
- Widget (khuôn `dien_tu_bien_dong_test.dart`): thẻ hiện với tin *"qua MoMo"*, không hiện với tin trần; bấm → đoạn
  Chuyển khoản, ví đi = *Ví MoMo* (theo tên), ví đến = ví nhớ của MB; Lưu → `repo.added` là `transfer` đúng hai ví,
  hàng bị xoá; cặp → **hai** hàng bị xoá; nhớ ví đúng phía (bản sai có chủ ý: nhớ `_selectedWallet` cho nguồn tin thì
  ca đỏ); 360 × 640 không tràn.
- Nghiệm thu Realme: ba hàng *"qua MoMo"* đang chờ.

## 7. Ngoài phạm vi

- Giữ phần `DEN: <tên> - PSP<số>` của tin MB chiều trừ để nhận chuyển **sang** ví điện tử — đổi `docTinBienDong`, cần
  xét riêng (nội dung tin ở lại máy, mức che).
- Thẻ gợi ý ở trung tâm thông báo (người dùng chọn chỉ trong form).
- Nhận chuyển khoản cho chính mình qua tên chủ tài khoản (*"TRAN QUANG DAT chuyen tien"*) — app không lưu tên ấy.

Không đổi schema, không đổi payload đồng bộ, không đụng backend.
