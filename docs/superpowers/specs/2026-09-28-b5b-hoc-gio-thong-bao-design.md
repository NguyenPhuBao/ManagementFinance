# B5b — Học giờ và tần suất thông báo — thiết kế

**Ngày:** 2026-09-28 (tối). **Người dùng duyệt** bản thiết kế trong chat cùng ngày, với các lựa chọn: **chỉ đề xuất**
(không tự đổi) · áp cho **giờ nhắc hoá đơn, giờ tổng kết tuần, giờ nhắc ghi chép, đề xuất tắt nhóm bị lờ** · hiện ở
**cả hai**: trang Cài đặt thông báo và thẻ trong trung tâm thông báo · cửa dữ liệu **≥ 20**. Các con số 35 % · ô 30 phút ·
10 thông báo liên tiếp · 48 giờ · im 30 ngày là đề xuất của Claude, người dùng duyệt nguyên. Vị trí trong lộ trình 28/09:
**cuối nhóm B**, sau B5a (đọc bảng `AppNotificationEvents`). **Không đổi schema.**

## 1. Vì sao

Ba giờ nhắc hôm nay là hằng số người dùng tự đặt một lần rồi quên. Nhóm thông báo người dùng không bao giờ mở vẫn kêu
mãi. B5a ghi lại phản ứng; B5b đọc chúng và **đề xuất**. Đổi giờ hay tắt nhóm là quyết định của người dùng (tầng hậu quả
2, mục 10.5 `AI_EDGE_FEATURE.md`), nên app **không tự làm**.

## 2. Luật — hàm thuần `lib/core/notification/hoc_gio_thong_bao.dart`

Đầu vào: nhật ký `List<AppNotificationEvent>` của một tài khoản (180 ngày, đúng thời hạn giữ của B5a), danh sách
`AppNotification` (cho `osDeliveredAt`), `NotificationPrefs` hiện tại, mốc ghi giao dịch (mục 2.3), `now`.

**Nhóm của một khoá:** suy từ tiền tố `dedupeKey`. Dùng lại bảng tiền tố → nhóm nếu `notification_deeplink.dart` /
`notification_prefs.dart` đã có; không có thì viết **một** hàm `nhomTuKhoa(String dedupeKey) → NotificationGroup?` ở
tệp này, kèm ca test quét **mọi** `NotificationKind` (khuôn `tatCaUngVien()` của `notification_deeplink_test.dart`), để
thêm loại mới mà quên xếp nhóm thì test đỏ. Khoá nhắc ghi chép (`ghiChepDedupeKey`) không thuộc `NotificationKind` nào:
xử lý riêng ở 2.3.

**Phản ứng tích cực** = `cham_hdh`, `nut_tra_ngay`, `mo_trong_app`. `gat_bo`, `hoan`, `doc_tat_ca` **không** tích cực.

### 2.1 Giờ nhắc hoá đơn

- Phản ứng tích cực của nhóm Hoá đơn trong 180 ngày, theo **giờ trong ngày** của `luc`, xếp vào ô 30 phút (00:00,
  00:30, …).
- Đề xuất ô đông nhất ⇔ **≥ 20** phản ứng **và** ô ấy chiếm **≥ 35 %** **và** lệch `prefs.gioNhac:phutNhac` **≥ 60 phút**
  (khoảng cách vòng tròn 24 giờ: 23:30 và 00:30 cách nhau 60 phút, không phải 23 giờ).
- Hai ô bằng nhau → ô gần giờ đang đặt hơn (đề xuất ít xáo trộn hơn).

### 2.2 Giờ (và thứ) tổng kết tuần

- Cùng luật 2.1 cho nhóm `summary`. **Thứ** đề xuất theo cùng khuôn ô (bảy ô), cửa ≥ 35 %. Chỉ đề xuất thứ khi nó khác
  `prefs.thuTongKet`.

### 2.3 Giờ nhắc ghi chép

- Không đo phản ứng với thông báo, mà đo **lúc người dùng hay ghi giao dịch**. ⚠️ Bảng `Transactions` **không có
  `createdAt`**, chỉ có `updatedAt` (`transactions_table.dart:158`), và cột này đổi khi sửa hay khi pull. Mốc thay thế:
  `updatedAt` của giao dịch **chưa xoá** mà `updatedAt` **cùng ngày lịch** với `date` (ghi trong ngày, không ghi lùi
  ngày, và nhiều khả năng chưa sửa về sau). Giới hạn này ghi rõ ở mục 5.
- Cùng luật ô 30 phút, cửa ≥ 20 giao dịch đủ điều kiện, ≥ 35 %, lệch `prefs.gioNhacGhiChep:phutNhacGhiChep` ≥ 60 phút.

### 2.4 Đề xuất tắt nhóm bị lờ

- **Thông báo đã tới máy** của một nhóm:
  - hàng `AppNotifications` có `osDeliveredAt != null`, mốc = `osDeliveredAt`;
  - **hoặc** một `dat_lich` có `luc < now` mà **không** có `huy_lich` cùng `dedupeKey` sau nó, mốc = `luc`.
  - Khử trùng theo `dedupeKey`, lấy mốc sớm nhất.
- Nhóm có **≥ 20** thông báo tới máy trong 180 ngày, **và** **10** cái gần nhất đều **không** có phản ứng tích cực nào
  trong **48 giờ** sau mốc → đề xuất tắt nhóm.
- Nhóm đang tắt thì không xét.

### 2.5 Bỏ qua đề xuất

Bấm **Bỏ qua** / **Giữ** → ghi sự kiện `bo_qua_de_xuat` vào **chính bảng B5a**, `dedupeKey = 'deXuat:<loại>'` (`gioHoaDon` ·
`gioTongKet` · `thuTongKet` · `gioGhiChep` · `tatNhom:<tên nhóm>`). Đề xuất ấy im **30 ngày** tính từ hàng mới nhất.
`SuKienThongBao` thêm hằng `boQuaDeXuat = 'bo_qua_de_xuat'` (thêm mã mới thì được, đổi mã cũ thì không). **Áp dụng** thì
không cần ghi: tuỳ chọn đã đổi nên luật tự thôi đề xuất.

**Kết quả** `List<DeXuatThongBao>`, mỗi phần tử có `loai`, `nhom?`, `gioDeXuat?` (`({int gio, int phut})`), `thuDeXuat?`,
`soMau`.

## 3. Hiện

- **Trang Cài đặt thông báo:**
  - Dưới ô giờ liên quan: một dòng *"Bạn hay mở nhắc hoá đơn lúc khoảng 20:00."* với hai nút **Đổi sang 20:00** và **Bỏ
    qua**. Tổng kết tuần gộp thứ + giờ trong một dòng. Nhắc ghi chép dùng *"Bạn hay ghi giao dịch lúc khoảng …"*.
  - Dưới công tắc nhóm bị lờ: *"10 thông báo gần nhất của nhóm này chưa được mở."* với **Tắt nhóm** và **Giữ**.
  - *Áp dụng* đi qua **đường lưu tuỳ chọn có sẵn** của trang (`NotificationPrefsStore`), rồi `ReminderScheduler.resync`
    như khi người dùng tự đổi.
- **Trung tâm thông báo:** có ≥ 1 đề xuất → một thẻ đầu danh sách *"Có N gợi ý chỉnh thông báo"*, bấm vào mở trang Cài
  đặt thông báo (route có sẵn; `go` / `push` theo `thuocThanhTab`, bẫy 7.8). Thẻ **không** phải một hàng
  `AppNotifications`, không bắn ra hệ điều hành, không có badge.
- Tính **lúc mở trang** (một lần đọc), không nghe stream.
- ⚠️ Cả hai là giao diện mới → **thiết kế trên Stitch trước**.

## 4. Không làm

Không tự đổi giờ, không tự tắt nhóm. Không đổi `dedupeKey`, không đổi luật sinh thông báo. Không thông báo về đề xuất.
Không đổi schema.

## 5. Giới hạn nói trước

- **Im 3–6 tháng** sau khi B5a lên: nhắc hoá đơn vài lần một tháng, nên cần chừng ấy để có 20 phản ứng.
- Mốc *lúc ghi* giao dịch là **mốc thay thế** (`updatedAt` cùng ngày với `date`). Giao dịch sửa trong ngày lấy giờ sửa;
  giao dịch kéo về từ máy khác lấy giờ server. Cả hai đều vẫn là giờ người dùng đang dùng app.
- Vuốt thông báo khỏi khay hệ điều hành không ghi được (giới hạn B5a), nên nó đếm như *"không phản ứng"*, tức nghiêng
  về phía đề xuất tắt. Cửa 10 liên tiếp + 48 giờ là để bù.
- Quyền thông báo tắt sau khi đặt lịch → `dat_lich` vẫn đọc thành *"đã tới máy"* (giới hạn B5a), nên cũng nghiêng về đề
  xuất tắt. Trang Cài đặt đã có dòng cảnh báo quyền (`daCoQuyen`): khi quyền tắt, **không** hiện đề xuất tắt nhóm.

## 6. Kiểm thử

- **Hàm thuần:** 25 cú chạm nhắc hoá đơn, 12 cú lúc 20:00–20:29 → đề xuất 20:00; giờ đang đặt 20:00 → không; 19 cú →
  không; 25 cú rải đều (không ô nào ≥ 35 %) → không; 23:30 vs 00:30 cách 60 phút theo vòng tròn; `gat_bo` / `hoan` /
  `doc_tat_ca` không đếm; hai ô bằng nhau → ô gần giờ đặt; tổng kết tuần đề xuất thứ; ghi chép dùng `updatedAt` cùng
  ngày với `date`, giao dịch ghi lùi ngày bị loại; nhóm bị lờ: 20 tới máy, 10 gần nhất không mở → đề xuất; một trong 10
  có `cham_hdh` sau 30 giờ → không; sau 50 giờ → vẫn đề xuất; `dat_lich` có `huy_lich` sau nó không đếm là tới máy;
  `bo_qua_de_xuat` 29 ngày trước → im, 31 ngày → hiện lại; nhóm đang tắt → không xét.
- **`nhomTuKhoa`:** ca quét mọi `NotificationKind`.
- **Widget Cài đặt:** dòng gợi ý hiện đúng ô; **Đổi sang** → tuỳ chọn lưu giờ mới và `resync` được gọi; **Bỏ qua** →
  có hàng `bo_qua_de_xuat`, dòng biến mất; quyền tắt → không hiện đề xuất tắt nhóm.
- **Widget trung tâm:** N đề xuất → thẻ *"Có N gợi ý"*; 0 → không thẻ; bấm → điều hướng đúng route.
- **Máy ảo:** bơm nhật ký bằng một bản debug (hoặc ghi trực tiếp SQLite qua `run-as`, **tài khoản thử**) rồi kiểm hai
  chỗ hiện.

## 7. Tài liệu đi kèm

`NOTIFICATION_FEATURE.md` thêm mục *Học giờ và đề xuất (B5b)*: luật, bốn loại đề xuất, mã `bo_qua_de_xuat`, giới hạn.
`CLAUDE.md` hàng *Đụng vào thông báo*. `PROJECT_CONTEXT.md` mục 14. Bản đồ nhóm B: B5b ✅.
