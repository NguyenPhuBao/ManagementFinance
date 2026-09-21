# Cửa sổ nhìn lại, và thẻ "Chưa đặt ngân sách"

**Viết:** 2026-09-21 · **Trạng thái:** ⬜ đã duyệt thiết kế, **chưa thi công**
**Thuộc:** mục ④ *"đề xuất tạo ngân sách"* của
`docs/superpowers/plans/2026-09-21-ai-viec-tiep-theo.md`

---

## 1. Vì sao có tài liệu này

Mục ④ trong danh sách việc ghi *"`suggestAmount` đã có số"*. **Câu ấy sai**, và
phép đo lật nó trước khi một dòng mã nào được viết.

`BudgetRepositoryImpl.suggestAmount` cộng chi của **ba tháng lịch đã đóng**
(với hôm nay 21/09/2026 là T6, T7, T8), rồi `if (total <= 0) return null`.
Đo trên CSDL dev ngày 2026-09-21:

| Đo | Kết quả |
|---|---|
| Tổng số giao dịch sống | **79** |
| Giao dịch **sớm nhất** trong toàn bộ CSDL | **02/09/2026** |
| Số giao dịch trước tháng 9 | **0** |
| Tài khoản có nhiều dữ liệu nhất (`Idaccount = 10`) | 37 giao dịch, **toàn tháng 9** (+ 2 hàng ghi ngày tương lai 10/10 và 10/11) |

Không tài khoản nào có một tháng lịch đã đóng nào có dữ liệu. Nên `suggestAmount`
trả **`null` cho mọi danh mục, mọi tài khoản** — và sẽ còn thế cho tới 01/10/2026.

**Hai hệ quả, cái thứ hai là một lỗi đang chạy:**

1. Dựng thẻ đề xuất trên nền hàm ấy thì thẻ **không bao giờ hiện**, và hỏng
   **im lặng** — đúng loại lỗi dự án này tốn nhiều công nhất để bắt.
2. **Gợi ý hạn mức trong form tạo ngân sách đang chết sẵn.** Nó vẫn gọi
   `suggestAmount` ở mỗi lần chọn danh mục và vẫn luôn nhận `null`. Tính năng
   ấy vào repo ngày 2026-09-06 — commit `f746a32` *"gợi ý hạn mức từ chi tiêu ba tháng trước khi chọn danh mục"*, và `PROJECT_CONTEXT.md` mô tả nó là *"Gợi ý hạn mức từ ba tháng trước"* — và
   **chưa từng hiện một con số nào trên dữ liệu thật**.

### 1.1 Và nó có một anh em

Lượt soát bán kính tìm ra thành viên thứ hai của cùng một họ:
`TaiPhanBoNguonImpl._thuNhap3Thang` lấy `chuoiVayNo(khoan, ky: ky, soKy: 4)`
rồi `.take(3)` — tức **ba tháng lịch liền trước**, cùng cửa sổ chết.

Hệ quả: `thuNhap3Thang` trả **0**, nên phép neo ngưỡng theo thu nhập
(`_neo(thuNhap3Thang, tiLe, san)` ở `ai_edge/domain/tai_phan_bo.dart`) luôn rơi
về **sàn**. Việc "neo ba ngưỡng tái phân bổ theo thu nhập" làm ngày 2026-09-21
(chặng 1.1) vì thế **chưa từng có hiệu lực thật** — nó đúng về mã, nhưng đầu vào
luôn bằng 0.

⚠️ **Quét toàn `lib/features/` cho thấy đúng HAI thành viên**, không hơn. Những
chỗ khác trông giống nhưng khác hẳn: `pham_vi_ky.dart` là phép tính kỳ **người
dùng tự chọn** trên trang Phân tích; `goal_history_filter.dart:86`
(`DateTime(now.year, now.month - 3, now.day)`) **đã** là cửa sổ cuộn theo ngày —
tức lối mà tài liệu này đang đề xuất, dự án vốn đã dùng ở một nơi.

---

## 2. Phạm vi

**Làm:**

1. Một **định nghĩa cửa sổ nhìn lại** dùng chung.
2. `suggestAmount` và `_thuNhap3Thang` đổi sang cửa sổ ấy.
3. Thẻ **"Chưa đặt ngân sách"** trên trang Ngân sách (mục ④ gốc).

**Không làm:**

- Không gộp **phép cộng** của hai chỗ gọi (xem mục 3.1).
- Không đụng `pham_vi_ky.dart`, `goal_history_filter.dart`, hay bất kỳ phép
  tính kỳ nào của trang Phân tích.
- Không đổi schema, không thêm trường đồng bộ.
- Không thêm loại thông báo nào. Người dùng đã chốt **thẻ**, không phải thông
  báo, ở lượt brainstorm 2026-09-21.

---

## 3. Thiết kế

### 3.1 Dùng chung CỬA SỔ, không dùng chung phép cộng

Hai chỗ gọi cộng hai thứ khác nhau bằng hai đường khác nhau:

| | `suggestAmount` | `_thuNhap3Thang` |
|---|---|---|
| Cộng cái gì | chi của **một danh mục** | **thu nhập** của tài khoản |
| Bằng đường nào | `sumExpenses` (truy vấn SQL) | `thuNhapCua` trên danh sách trong bộ nhớ |
| Luật riêng | làm tròn lên bội 10.000 | trừ tiền đi vay / thu nợ / vay-nợ tiền vào (bẫy A8 #8) |

Gộp cả phép cộng buộc một bên bẻ mình theo hình dạng bên kia — và vế "trừ tiền
đi vay" của bên phải là một luật đã tốn công đúng một lần rồi, không được làm
mờ. Thứ **thật sự** trùng lặp chỉ là cửa sổ. Nên dùng chung đúng cửa sổ.

### 3.2 `cuaSoNhinLai` — hàm thuần, một định nghĩa

**Nơi đặt:** `lib/features/budget/domain/cua_so_nhin_lai.dart` (cả hai chỗ gọi
đều thuộc mảng `budget`).

```dart
/// Cửa sổ nhìn lại để suy một mức "mỗi tháng" từ lịch sử.
class CuaSoNhinLai {
  final DateTime from;   // mốc bắt đầu, đóng
  final DateTime to;     // mốc kết thúc, MỞ  → biên [from, to)
  final int soNgay;      // số ngày thật của cửa sổ
}

CuaSoNhinLai? cuaSoNhinLai(DateTime now, DateTime? mocDauTien);
```

**Luật:**

- `to = now` — ⚠️ **chặn ở cả hai đầu**. CSDL thật có giao dịch ghi **ngày
  tương lai** (10/10 và 10/11 — khoản trích tự động của mục tiêu). Cửa sổ hở
  đầu sau sẽ nuốt tiền **chưa tiêu** vào một con số nói về quá khứ. Cùng họ với
  bẫy của *Tổng tài sản theo thời gian* (mục 3.30 `ANALYTICS_FEATURE.md`), nơi
  vế `[moc, now]` phải đóng cả hai đầu vì `wallets.balance` cộng mọi hàng bất kể
  ngày.
- `from = max(now − kSoNgayNhinLai, mocDauTien)` với `kSoNgayNhinLai = 90`.
- `mocDauTien == null` (tài khoản chưa có giao dịch nào) → trả **`null`**.
- `soNgay < kSoNgayToiThieu` (**14**) → trả **`null`**.

**`null` có đúng MỘT nghĩa: *chưa đủ để nói*.** Người gọi phải im hẳn, không
được `?? 0` — một số 0 ở đây đọc như "bạn không chi gì", khác hẳn "tôi chưa
biết". Cùng luật với `duBaoHoanThanh` của mục tiêu.

**Quy về mức tháng** — người gọi tự làm, vì tử số là của riêng nó:

```dart
mucThang = tong / cs.soNgay * 30
```

⚠️ **Mẫu số là tuổi dữ liệu của TÀI KHOẢN, không phải của danh mục.** Nếu mỗi
danh mục tự tính tuổi riêng thì một danh mục vừa phát sinh **hôm qua** có mẫu số
1 ngày, và mức tháng của nó phồng lên **30 lần** — một con số hoàn toàn hợp lý
về hình thức và hoàn toàn sai. Đây là chỗ dễ vấp nhất của cả tài liệu này.

### 3.3 Nguồn `mocDauTien`

Chưa có truy vấn nào cho việc này trong mảng `budget` (`grep` ngày 2026-09-21:
`BudgetLocalDataSource` có **11** hàm, không hàm nào trả mốc sớm nhất; bản duy nhất
trong `lib/` là một vòng lặp cục bộ ở `analytics_repository_impl.dart:412`).

Thêm **`BudgetLocalDataSource.mocGiaoDichDauTien(int idaccount)`** →
`Future<DateTime?>`, cài bằng một truy vấn `MIN(date)` có lọc `idaccount` và
`isDeleted = false`.

⚠️ **Phải lọc `isDeleted`**: một giao dịch đã xoá mềm vẫn nằm trong bảng, và để
nó làm mốc là kéo dài mẫu số bằng dữ liệu người dùng đã bỏ đi.

### 3.4 `suggestAmount` sau khi đổi

```dart
final cs = cuaSoNhinLai(moment, await localDataSource.mocGiaoDichDauTien(idaccount));
if (cs == null) return null;
final tong = await localDataSource.sumExpenses(
  idaccount: idaccount, categoryId: categoryId, from: cs.from, to: cs.to,
);
if (tong <= 0) return null;
const step = 10000;
return (tong / cs.soNgay * 30 / step).ceil() * step.toDouble();
```

Giữ nguyên: làm tròn **lên** bội 10.000, và `null` khi tổng ≤ 0.
Bỏ: vòng lặp ba tháng và hằng `months`.

### 3.5 `_thuNhap3Thang` sau khi đổi

Vẫn đi qua `thuNhapCua` — **không** phải `type == 'thu'` trần — chỉ đổi tập đầu
vào: lọc `khoan` theo `[cs.from, cs.to)` thay vì dựng bốn kỳ tháng rồi `take(3)`.
Kết quả vẫn là **mức MỘT tháng**, đúng như chú thích hiện có cảnh báo.

⚠️ **Đổi tên.** `thuNhap3Thang` nay sẽ nói dối về cửa sổ của chính nó. Đổi thành
**`thuNhapMoiThang`** ở `DuLieuTaiPhanBo`, ở tham số của `_neo`, và ở chỗ đăng
ký DI. Trường `tb3ThangTheoNganSach` cũng đổi thành **`mucThangTheoNganSach`**.

**Bốn chỗ, trong hai tệp** đang ghi *"TB 3 tháng"* / *"trung bình 3 tháng"* phải sửa:
`docs/AI_EDGE_FEATURE.md` (3 chỗ: dòng ~81, ~466, ~481) và
`docs/NOTIFICATION_FEATURE.md` (~986). ⚠️ `docs/AI/AI_Edge-SLM.md/Client-app.md`
là **tài liệu do backend quản** — chỗ sai của nó đi qua
`CAN-LAM/AI_EDGE_SLM_SUA_TAI_LIEU.md`, **không sửa thẳng**.

### 3.6 Thẻ "Chưa đặt ngân sách"

**Chỗ đứng:** trang Ngân sách, trong `budget_tabs_view.dart`, **dưới** khối
Nhận xét và thẻ kế hoạch tái phân bổ, **trên** tiêu đề *"Danh mục chi tiêu"*.

**Luật chọn danh mục** — hàm thuần, để test được không cần widget:

1. Danh mục **chi** — loại bỏ `classify` thu và `vay_no`. Ngân sách nói về
   tiêu, và một danh mục vay/nợ đặt hạn mức là vô nghĩa.
2. **Chưa có ngân sách đang chạy** — không nằm trong `state.active`.
   (`_assertCategoryFree` đã bảo đảm mỗi danh mục tối đa một ngân sách chạy.)
3. `suggestAmount` trả **khác `null`**.
4. Xếp theo mức tháng **giảm dần**, lấy tối đa **3**.

**Không danh mục nào đủ điều kiện → ẩn hẳn thẻ**, đúng luật vừa chốt cùng ngày ở
mục **3.34** `ANALYTICS_FEATURE.md`: một thẻ rỗng chiếm chỗ mà không mang tin.

**Mỗi dòng:** tên danh mục · mức tháng gợi ý · nút **Tạo** mở form tạo ngân sách
đã điền sẵn danh mục và số tiền.

⚠️ **Phải nói ra khi con số suy từ mẫu ngắn.** Khi `cs.soNgay < 90`, thẻ kèm một
dòng phụ dạng *"suy từ 20 ngày gần nhất"*. Hứa một mức "mỗi tháng" dựng từ 14
ngày mà không nói gì là bịa một lời hứa — cùng loại sai mà `duBaoHoanThanh` phải
trả `null` thay vì `?? 0`.

⚠️ **Khối mới → vẽ Stitch trước khi thi công**, theo nếp của dự án.

---

## 4. Những cái bẫy, gom lại

| # | Bẫy | Hỏng thế nào |
|---|---|---|
| 1 | Mẫu số lấy theo **danh mục** thay vì theo **tài khoản** | Danh mục mới phát sinh phồng mức tháng lên tới 30 lần; con số trông hợp lý |
| 2 | Cửa sổ hở đầu sau (`to` mở tới vô cực) | Nuốt giao dịch ghi **ngày tương lai** — có thật trong CSDL — vào một con số nói về quá khứ |
| 3 | `?? 0` thay cho `null` | "Chưa đủ dữ liệu" biến thành "bạn không chi gì"; thẻ hiện `0 đ` thay vì im |
| 4 | Không lọc `isDeleted` khi lấy mốc đầu tiên | Giao dịch đã xoá kéo dài mẫu số, mọi mức tháng nhỏ đi |
| 5 | Giữ tên `thuNhap3Thang` | Một cái tên nói dối về cửa sổ của chính nó; người sau đọc tên rồi suy sai |
| 6 | Không nói "suy từ N ngày" | Một lời hứa "mỗi tháng" dựng từ hai tuần, không ai biết |
| 7 | Gộp luôn phép cộng của hai chỗ gọi | Làm mờ luật "thu nhập không gồm tiền đi vay" (bẫy A8 #8) |

---

## 5. Kiểm

**Hàm thuần** (`cua_so_nhin_lai_test.dart`): biên **13 / 14 ngày**;
`mocDauTien == null`; `mocDauTien` cũ hơn 90 ngày (cửa sổ bị kẹp còn 90);
`mocDauTien` mới hơn 90 ngày (cửa sổ ngắn lại, `soNgay` đúng); `to` đóng nên
giao dịch ngày tương lai nằm ngoài.

**Hai chỗ gọi:** `suggestAmount` trả `null` khi tài khoản quá trẻ và trả số làm
tròn lên 10k khi đủ; `_thuNhap3Thang` vẫn **không** đếm tiền đi vay (ca này đã
có, phải giữ xanh).

**Thẻ:** ẩn khi không có danh mục nào đủ điều kiện; hiện tối đa 3 dòng, xếp
giảm dần; có dòng "suy từ N ngày" khi cửa sổ < 90 ngày; nút Tạo mở form đã điền.
Mỗi ca **đòi kết quả**, không chỉ đòi vắng mặt.

**Nghiệm thu máy ảo bắt buộc** — tài khoản thật có **20 ngày** dữ liệu nên nay
vượt ngưỡng 14 và thẻ **phải hiện thật**. Đây là phép kiểm quan trọng nhất của
cả tài liệu: nó chứng minh mục ④ thôi chết.

---

## 6. Xong khi

- `flutter test` trọn bộ xanh, `flutter analyze` **26 issue, 0 error**.
- Mọi ca mới **đỏ với bản sai có chủ ý** trước khi xanh.
- Thẻ hiện thật trên máy ảo với dữ liệu thật, và ẩn khi lọc hết danh mục.
- Bốn chỗ tài liệu ghi "TB 3 tháng" đã sửa; tài liệu backend thì **chỉ** ghi
  vào `CAN-LAM/`.
- Không đổi schema, không thêm trường đồng bộ.
