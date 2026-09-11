# Thiết kế: tự động thanh toán hoá đơn (client, schema v17)

> **Trạng thái: ĐÃ THI CÔNG** (soát lại 2026-09-08) —
> `lib/features/bill/domain/bill_auto_pay.dart` +
> `bill_auto_pay_runner.dart`, cột `autoPayEnabled` ở
> `lib/core/database/tables/other_tables.dart:174`.
> ⚠️ Cột ấy vẫn là **cục bộ**: hai máy cùng bật là hai khoản chi. Việc backend
> tương ứng nằm ở `CAN-LAM/README.md` mục 2.

**Ngày:** 2026-09-06 · **Phạm vi:** `src/Client-app` · **Tiền lệ:** trích tiền
tự động của mục tiêu (mục 3.12–3.14 `docs/GOAL_FEATURE.md`, schema v15).

> Đây là chỗ **thứ hai** trong app tự chuyển tiền khi người dùng vắng mặt, nên
> phần lớn thiết kế là về việc *dừng đúng lúc*.

## 1. Ba lựa chọn người dùng đã chốt

| Câu hỏi | Chốt | Hệ quả |
|---|---|---|
| Trừ từ ví nào | **Ví thanh toán của hoá đơn** (`bills.walletId`) | Chỉ cần MỘT cột mới; khoản chi sinh ra giống hệt khi bấm Thanh toán tay |
| Mở app muộn, hoá đơn đã quá hạn | **Trả bù, có trần** | Tối đa 3 kỳ mỗi hoá đơn mỗi lượt; dừng ngay khi ví không đủ |
| Giờ trả trong ngày đến hạn | **Bất kỳ lúc nào** | Lượt quét đầu tiên từ 00:00 ngày đến hạn là trả; không có ô chọn giờ |

## 2. Lược đồ v17

- `bills.autoPayEnabled` — `BoolColumn`, mặc định `false`, **CỤC BỘ**: không
  vào payload đẩy, nhánh kéo không đọc, `sync_payload_contract_test` không
  đổi. Cùng khuôn với `generatedFromBillId` (v16).
- Không có cột "lần chạy cuối": mỗi kỳ hoá đơn là **một hàng riêng**, cờ đã
  trả (`isPaid`/`payStatus`) chính là chốt chống trả hai lần.
- Migration `from < 17`: `addColumn`, **không** bật cho hoá đơn cũ — chưa ai
  đồng ý cho app tự chuyển tiền.
- `BillRepositoryImpl._nextPeriodOf` chép cờ sang kỳ kế tiếp. Quên là chuỗi
  tự trả dừng sau đúng một kỳ.

## 3. Phần quyết định thuần — `features/bill/domain/bill_auto_pay.dart`

Hàm thuần, không Drift, không `DateTime.now()`.

- `denLuotTuTra(Bill, DateTime now)`: bật cờ ∧ chưa trả (đọc cả hai cột) ∧
  chưa xoá ∧ có `walletId` ∧ có `categoryId` ∧ `dueDate` (so theo **ngày**)
  ≤ hôm nay.
- `quyetDinhTuTra(soTien, soDuVi)` → `LoaiTuTra.traDu` hoặc `viKhongDu`
  (`soTien ≤ 0` → `khongChayDuoc`). Không trả một phần. Số dư 0 sau khi trả
  là hợp lệ.
- Hằng `tranKyMoiLuot = 3`.
- `khoaKyTuTra(billId, dueDate)` → `'<id>:<yyyy-MM-dd>'`, dùng cho khoá chống
  trùng thông báo.

## 4. Bộ chạy — `features/bill/domain/bill_auto_pay_runner.dart`

`BillAutoPayRunner(db, repository, toiDaMoiLuot = 3).chay(idaccount, now)` →
`List<BillAutoPayEvent{billId, billName, ky (= dueDate), loai, soTien, tenVi}>`.

Với mỗi hoá đơn đến lượt (lặp tối đa `toiDaMoiLuot` lần):

1. Đọc ví; ví không còn → `khongChayDuoc`, dừng hoá đơn này.
2. `quyetDinhTuTra(bill.amount, ví.balance)`; `viKhongDu` → ghi sự kiện,
   **dừng, không đổi gì** (lượt sau tự thử lại).
3. `repository.payBill(bill, walletId: bill.walletId, amount: bill.amount,
   occurredAt: bill.dueDate)` — đi qua đường tiền hiện có, nên hoàn tác vẫn
   lần được (`transactions.billId`). Ném lỗi → `khongChayDuoc`, dừng.
4. Kỳ kế tiếp qua `billDao.getGeneratedFrom(bill.id)`; nếu nó cũng
   `denLuotTuTra` thì lặp tiếp với nó, không thì dừng.

Mỗi hoá đơn độc lập; lỗi một hoá đơn không chặn hoá đơn khác. Nơi gọi là
`NotificationScanner.scan()` ngay **sau** `markOverdue` (hoá đơn đọc lên phải
mang trạng thái mới nhất), cùng kiểu closure `runAutoPays` như
`runAutoDeposits`; lỗi bị nuốt để không giết trung tâm thông báo.

`payBill` nhận thêm `occurredAt` tuỳ chọn: ngày của **giao dịch** là ngày đến
hạn của kỳ (trả bù ba kỳ không thành một cột dựng đứng ở ngày mở app — cùng
lý do mục 3.14 `GOAL_FEATURE.md`). Chặn giá trị ở tương lai. `updatedAt` vẫn
là "bây giờ". Đường trả tay không truyền tham số này.

## 5. Thông báo

Hai `NotificationKind` mới, nhóm **`bill`** trong `nhomCua`:

| Kind | Khoá chống trùng | Nội dung |
|---|---|---|
| `billAutoPaid` | `billAuto:<khoaKyTuTra>` | "Đã tự thanh toán hoá đơn" — "Đã trả *tên* *số tiền* từ ví *ví*." |
| `billAutoPayFailed` | `billAutoFail:<khoaKyTuTra>` | `viKhongDu`: "Ví *ví* không đủ tiền để tự trả *tên* (*số tiền*). Sẽ tự thử lại." · `khongChayDuoc`: "Không tự trả được *tên*: ví hoặc danh mục không còn dùng được. Mở hoá đơn để chọn lại." |

`createdAt` = lúc quét (tiền rời ví lúc nào báo lúc đó; trần 3 kỳ đã chặn cơn
lũ). `deeplink: '/bills'`, `subjectType: 'bill'`. Mức: thành công `info`,
thất bại `warning`.

`ReminderScheduler`: **không** thêm lịch mới. Lịch "sắp đến hạn" đang có đổi
thân câu cho hoá đơn bật tự trả: "*tên* đến hạn hôm nay. Mở app để hoá đơn
được tự trả." (khoá lịch không đổi).

## 6. Giao diện

- **Form Thêm và Sửa**: đưa lại khối theo Stitch "Thêm Hóa Đơn Định Kỳ" —
  biểu tượng `smart_toy`, "Tự động thanh toán" / "Trừ từ ví thanh toán khi đến
  hạn" — nằm dưới các chip nhắc, sau vạch mỏng. Công tắc **TẮT SẴN** (Stitch
  vẽ bật sẵn; đã gỡ ngày 06/09 vì hứa suông, nay có thứ đứng sau nhưng bật
  sẵn vẫn là chuyển tiền dựa trên lựa chọn người dùng chưa đưa ra). Khi bật,
  hiện một dòng phụ: "Trả khi bạn mở app vào ngày đến hạn. Chỉ nên bật trên
  một thiết bị." `BillDraft.autoPayEnabled`; cả hai companion ghi cột này.
- **Dòng danh sách**: thêm "Tự trả" vào dòng "Danh mục • Ví" của
  `BillStatusHeader`.

## 7. Đồng bộ, backend, rủi ro

- Cột cục bộ ⇒ cấu hình **không theo người dùng sang máy khác**.
- ⚠️ Hai máy cùng bật, cùng offline, cùng trả một kỳ ⇒ **hai** khoản chi và
  trừ hai ví; cờ đã trả đồng bộ theo LWW không chặn được. Ghi trong tài liệu
  và trong dòng phụ trên form. Đóng hẳn cần backend: việc **D** thêm vào
  `docs/superpowers/backend/DA-XONG/2026-09-06-bill-chuoi-ky-va-an-han.md`
  — cột `bill.Auto_pay` (bool) để cấu hình đồng bộ, và chốt chặn ở
  `/sync/push`: từ chối giao dịch thứ hai mang cùng `Idbill` khi cột đó có
  (phụ thuộc việc A).

## 8. Kiểm thử (viết trước)

| Tệp | Canh |
|---|---|
| `test/core/database/bill_schema_v17_test.dart` | Migration thêm cột, hàng cũ `false` |
| `test/features/bill/domain/bill_draft_test.dart` (+) | Cả hai companion mang cờ |
| `test/features/bill/data/repositories/bill_payment_test.dart` (+) | Kỳ sau kế thừa cờ; `occurredAt` ghi vào `date` của giao dịch, không phải `updatedAt`; tương lai bị chặn |
| `test/features/bill/domain/bill_auto_pay_test.dart` | Đến lượt: đúng ngày, không sớm, đã trả/xoá/thiếu ví/danh mục bị loại; quyết định: đủ / thiếu / 0 |
| `test/features/bill/domain/bill_auto_pay_runner_test.dart` | Trả đúng kỳ và sinh kỳ sau; trả bù đúng trần 3; ví thiếu → dừng, không đổi gì, lượt sau trả được khi ví có tiền; ví bị xoá → `khongChayDuoc`; hoá đơn không lặp trả xong là hết; ngày giao dịch = ngày hạn; hoàn tác vẫn được |
| `test/core/notification/notification_rules_test.dart` (+) | Hai loại, khoá theo kỳ, câu nêu ví và số tiền |
| `test/core/notification/prefs/...` (+) | `nhomCua` xếp vào nhóm `bill` |
| `test/core/notification/reminder_scheduler_test.dart` (+) | Thân câu cho hoá đơn tự trả |
| Widget test hai form và trang danh sách (+) | Công tắc tắt sẵn; bật thì draft mang cờ; dòng "Tự trả" |

Sau cùng: `flutter test`, `flutter analyze`, và **máy ảo 411dp**.
