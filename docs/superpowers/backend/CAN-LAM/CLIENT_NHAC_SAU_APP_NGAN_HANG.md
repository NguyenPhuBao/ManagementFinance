# Thông báo: client dùng thêm quyền *Truy cập dữ liệu sử dụng* — nhắc ghi sau khi dùng app ngân hàng

**Ngày:** 2026-10-03 · **Người viết:** phía Client-app · **Nhánh:** `TranQuangDat`
**Loại:** **thông báo**, kèm hai câu hỏi có mặc định. **Không xin đổi mã backend, không migration, không trường đồng bộ
mới, không xin sửa tài liệu.** Backend không trả lời thì client làm theo mặc định ở mục 4.

---

## Tệp cần đọc

| Tệp | Vì sao |
|---|---|
| `docs/superpowers/backend/DA-XONG/CLIENT_DOC_BIEN_DONG_SO_DU_TREN_MAY.md` | đơn gốc của D1 và phản hồi duyệt toàn diện của backend (2026-09-26) — trong đó yêu cầu **màn xin đồng ý bắt buộc** |
| `docs/superpowers/backend/CAN-LAM/CLIENT_CHIA_SE_BIEN_LAI.md` | thông báo trước của cùng lượt (2026-10-02): biên lai cứu giao dịch khi người dùng **nhớ** chia sẻ |
| `docs/superpowers/specs/2026-10-03-nhac-ghi-sau-app-ngan-hang-design.md` | thiết kế phía client, người dùng duyệt 2026-10-03 |
| `docs/BIEN_DONG_SO_DU_FEATURE.md` mục 8 | hiện trạng sau khi làm, bảng đo chạy nền và bảng nghiệm thu máy thật |

---

## 1. Vì sao có tính năng này

D1 chỉ đọc **thông báo đã hiện trên máy**. Đo trên Realme 2026-10-02: sáu lần chuyển từ MB Bank, **một lần không có
thông báo biến động**; MoMo / ZaloPay **không bao giờ** bắn tin khi chuyển tiền đi. Chia sẻ biên lai (thông báo trước)
chỉ cứu được khoản ấy khi người dùng **nhớ** chia sẻ. Bản này nhắc **khi người dùng quên**.

Tín hiệu hợp lệ duy nhất để biết *"vừa dùng app ngân hàng"* trên Android là quyền **Truy cập dữ liệu sử dụng**
(`PACKAGE_USAGE_STATS`): giờ một app lên / rời màn hình. Client **không** dùng quyền Trợ năng (đọc cả màn hình — đã
loại ở D1), không đọc nội dung app khác, không mở lại liên kết ngân hàng (nhóm đã bỏ 2026-09-18).

## 2. Client đã làm gì

Tính năng mới, **mặc định TẮT**, công tắc riêng ở *Cài đặt thông báo → Tự động hoá giao dịch*:

1. Bật lần đầu → **màn đồng ý** (cùng khuôn màn đồng ý D1): liệt kê ba app theo dõi; cam kết chỉ đọc **giờ mở / giờ
   rời** của ba app ấy, không đọc màn hình hay nội dung app, không gửi gì ra khỏi máy, không tự tạo giao dịch. Đồng ý
   → trang *Truy cập dữ liệu sử dụng* của hệ thống, người dùng **tự bật** cho FlowMoney.
2. Người dùng dùng MB Bank / MoMo / ZaloPay (đúng danh sách trắng của D1) **≥ 20 giây**, và quanh phiên ấy **không có**
   tin biến động, biên lai hay giao dịch nào được ghi → FlowMoney hiện một dòng *"MB Bank · HH:mm – HH:mm — Chưa thấy giao
   dịch nào, chạm để ghi"* trong danh sách *Biến động*, và (khi FlowMoney chưa được mở lại) một thông báo **im lặng**
   *"Vừa dùng MB Bank — có giao dịch cần ghi?"* — **không số tiền**, kèm nút *Không có giao dịch*.
3. Chạm dòng → form Thêm giao dịch, **số tiền trống**, giờ = lúc mở app ngân hàng. Người dùng tự nhập và bấm Lưu — app
   **không tự tạo giao dịch** (bất biến của nhóm: AI / tự động chỉ điền sẵn, không ghi thẳng).

## 3. Những gì KHÔNG đổi

- **Không API, không liên kết tài khoản, không gọi mạng.** Không quyền Trợ năng, không `READ_SMS`.
- **Không gửi gì lên server.** Dòng nhắc (nguồn + giờ) nằm trong bảng thông báo **cục bộ** (không thuộc đường đồng bộ),
  xoá cứng khi người dùng Lưu / Bỏ qua / vuốt, tối đa 30 ngày; cộng một mốc thời gian theo tài khoản. Payload `/sync`
  không đổi (giao dịch vẫn **13** trường), lược đồ không đổi (vẫn v27).
- **Tối thiểu hoá:** tầng Android gốc lọc sự kiện sử dụng còn đúng ba gói theo dõi **trước** khi dùng; không lưu, không
  log app nào khác. Bản debug chỉ log **số đếm** (số sự kiện, số phiên, số phiên đáng nhắc); bản release không log.
- Tắt công tắc → huỷ lịch nền, gỡ thông báo. Quyền hệ thống app không tự thu hồi được — màn Cài đặt chỉ chỗ thu hồi.
  Đăng xuất → không thông báo, không dòng cho tài khoản đã đăng xuất.

## 4. Câu hỏi cho backend

| # | Câu hỏi | Mặc định của client |
|---|---|---|
| 1 | Ngoài màn đồng ý bắt buộc và công tắc tắt được bất cứ lúc nào, backend có đòi client làm thêm gì về đồng ý / Nghị định 13 cho quyền *Truy cập dữ liệu sử dụng* không? | **không** — cùng khuôn đồng ý mà backend đã duyệt cho D1; dữ liệu không rời máy |
| 2 | Có cần ghi tính năng này vào tài liệu backend quản (`Project.md`, `progress/Client-app.md`, chức năng 3 ở `docs/AI/LogicBusinessAI.md`)? | **không bắt buộc** — backend tự quyết; client không sửa tài liệu backend quản |

## 5. Kiểm lại phía client

- `grep -n "PACKAGE_USAGE_STATS\|NhacGhiReceiver" src/Client-app/android/app/src/main/AndroidManifest.xml` — một quyền
  (`tools:ignore="ProtectedPermissions"`), một receiver.
- `grep -n "Log\." src/Client-app/android/app/src/main/kotlin/com/flowmoney/flowmoney/PhienNganHang.kt` — ba dòng, đều
  sau `if (debug(ctx))`, chỉ in số đếm.
- `grep -n "androidx.work" src/Client-app/android/app/build.gradle.kts` — `work-runtime-ktx:2.11.0` (WorkManager định kỳ
  15 phút; trùng bản `background_downloader` đã kéo vào).
- Payload đồng bộ: `src/Client-app/test/core/sync/sync_payload_contract_test.dart` không đổi một dòng.
