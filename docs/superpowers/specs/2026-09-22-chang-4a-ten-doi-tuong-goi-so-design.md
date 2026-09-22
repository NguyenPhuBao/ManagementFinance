# Chặng 4a — tên đối tượng trong gói số (thiết kế)

**Ngày:** 2026-09-22 (tối muộn) · **Nhánh:** `TranQuangDat` @ `3a477b3` · **Trạng thái:** đã duyệt
**Đầu vào:** bảng đo 20 câu, mục **5.6** `docs/AI_AGENT_ARCHITECTURE.md` (chặng 3, cổng B qua)
**Lối đã chốt:** **C** — làm phần rẻ trước, đo lại, rồi mới dựng tool-calling (lát 4b)

---

## 1. Vì sao lát này tồn tại

Chặng 3 đo 20 câu trên máy thật: **✅ 5 · rơi mẫu 3 · sai 0 · lệch câu hỏi 12**. Ba lớp chắn giữ
đúng bất biến — không một con số sai nào lọt ra — nhưng **quá nửa** câu trả lời đúng số, đúng
nhãn, mà không trả lời điều được hỏi.

Đọc kỹ **12 câu lệch cộng câu 7** — câu 7 chấm là *rơi mẫu* nhưng cùng bệnh với nhóm C, nên xếp
chung ở đây; **13 hàng, 12 câu lệch** — thì chúng **không cùng một bệnh**:

| Nhóm | Câu | Bệnh | Thuốc |
|---|---|---|---|
| **A** | 3, 8, 13, 15 | gói mang **giá trị** mà không mang **định danh** | lát này |
| **B** | 12, 14, 20 | số **đã có sẵn** trong gói, mô hình chọn nhầm | lát này |
| **C** | 2, 5, 9, *(7 — rơi mẫu)* | gói **thiếu** số (tổng còn lại, gợi ý hạn mức, kỳ tuỳ ý) | lát 4b |
| **D** | 16, 17 | cần **so sánh** / **trừ** giữa hai gói | lát 4b |

🛑 **Nhóm A và B không cần tool nào.** Dựng tool-calling cho chúng là chữa nhầm bệnh — đó là lý
do lối C đặt lát này **trước** lát 4b, và là cùng bài học đã cứu chặng 3 khỏi ba tool thừa.

**Ví dụ sống của nhóm A** (câu 3): hỏi *"ngân sách nào sắp hết"*, nhận *"Ngân sách căng nhất là
90,0%"*. Người dùng muốn nghe **"Giáo dục"**. Con số đúng, nhãn đúng, câu vô dụng.

**Ví dụ sống của nhóm B** (câu 14): hỏi *"tiền trong ví còn bao nhiêu"* (13.004.000 đ), nhận
*"Còn lại là 12.994.000 đ"* — đó là `thu − chi` của kỳ, một đại lượng khác hẳn. Hai số **chênh
đúng 10.000 đ**, nên người dùng không có cách nào nhận ra mình vừa đọc nhầm đại lượng.

---

## 2. Chỗ hỏng trong mã, đo được

`SoLieu` (`ai_edge/domain/goi_so.dart:22`) có **bốn** trường:

```dart
class SoLieu {
  final String nhan;    // "Tỉ lệ" — tên CHỈ SỐ
  final double soTho;
  final String chuoi;   // "90,0%"
  final LoaiSo loai;
}
```

Không có chỗ nào cho **tên đối tượng**. Gói ngân sách biết *"90,0%"* là một *Tỉ lệ*, nhưng
**không** biết nó là tỉ lệ **của Giáo dục** — thông tin ấy bị bỏ lại ở tầng domain, nơi
`BudgetView` vẫn mang tên danh mục đầy đủ.

Đây là một phép **thu hẹp có chủ ý** từ thời mẫu câu: khối Nhận xét chỉ nói về *một* đối tượng
nên tên nằm trong câu mẫu, không cần vào `SoLieu`. Hỏi đáp tự do phá giả định ấy.

---

## 3. Thiết kế

### 3.1 `SoLieu` thêm **một** trường

```dart
class SoLieu {
  final String nhan;
  final String? ten;   // MỚI — tên đối tượng: "Giáo dục", "Tiền mặt", "Kiem"
  final double soTho;
  final String chuoi;
  final LoaiSo loai;
}
```

`ten == null` nghĩa là **số không thuộc về một đối tượng nào** (tổng thu, tổng chi, số ví) — đó
là ca thường, không phải ca thiếu dữ liệu.

🛑 **KHÔNG ghép tên vào `nhan`.** Cách ghép (`nhan: 'Giáo dục · Tỉ lệ'`) rẻ hơn một dòng mã và
**hỏng ngay**: `kiemNhan` đòi câu chứa **mọi âm tiết có nghĩa** của nhãn, nên nhãn ghép đòi câu
phải chứa cả *"giáo"*, *"dục"*, *"tỉ"*, *"lệ"*. Câu tự nhiên nhất — *"Giáo dục đã dùng 90,0%"* —
thiếu "tỉ" và "lệ" nên **bị chặn**. Nhãn giàu hơn mà lại tự chặn chính mình; lỗi này im lặng và
chỉ lộ trên máy thật.

### 3.2 `NguonGoiSo` nhồi danh sách, có trần

Sáu gói nay mang **nhiều** đối tượng thay vì một:

| Gói | Trước | Sau |
|---|---|---|
| ngân sách | ngân sách căng nhất | tối đa **N** ngân sách, căng nhất trước |
| ví | tổng + số ví + số ví âm | tối đa **N** ví, ví âm trước |
| hoá đơn | tổng + đếm | tối đa **N** hoá đơn chưa trả, quá hạn trước |
| phân tích | tổng thu/chi + khoản lớn nhất | thêm tối đa **N** danh mục chi, lớn nhất trước |
| mục tiêu | mục tiêu ưu tiên nhất | tối đa **N** mục tiêu |
| trang chủ | *(không đổi)* | *(không đổi)* |

⚠️ **Trần `N` là tham số phải ĐO, không phải hằng đoán.** Prompt hiện **1.700 ký tự** và token
đầu đã **4,6 s** trên CPU Realme; nhồi bốn danh sách có thể đẩy lên 3.000+. Bước đo ở §5 đo cả
độ dài prompt lẫn token đầu, và `N` chốt theo số đo ấy. Bắt đầu từ **N = 4** (bằng đúng số ngân
sách và số ví của tài khoản thử, nên phủ hết ca thật mà không phồng).

**Thứ tự trong danh sách là thứ tự đáng chú ý**, không phải thứ tự CSDL — mô hình đọc từ trên
xuống, và khi phải chọn một nó hay lấy cái đầu.

### 3.3 `kiemNhan` chấp nhận tên — nới theo chiều an toàn

Luật hiện tại: một số hợp lệ khi câu chứa đủ từ khoá của **`nhan`** của một `SoLieu` khớp nó.

Luật mới: đủ từ khoá của **`nhan`** *hoặc* đủ từ khoá của **`ten`**.

Câu *"Giáo dục đã dùng 90,0%"* lọt nhờ vế `ten`; câu *"Tỉ lệ là 90,0%"* vẫn lọt nhờ vế `nhan`.
Và câu bịa nhãn — *"Dự báo tiết kiệm là 90,0%"* — vẫn **bị chặn**, vì nó không chứa đủ từ khoá
của vế nào.

⚠️ Đây là **nới**, không phải siết: mọi câu từng lọt vẫn lọt. Nên ca test phải chứng minh cả hai
chiều — thêm ca *"câu nêu đúng tên thì lọt"* **và** giữ nguyên mọi ca chặn cũ.

`kiemSo` **không đổi một chữ**: nó so giá trị, và bất biến *"mọi số trong câu phải có trong
gói"* không liên quan gì tới tên.

### 3.4 `theCuaCau` chọn nhãn theo câu — chữa **bẫy 4.27**

Hàm hiện tại khử trùng theo **giá trị**:

```dart
for (final s in soLieuKhop(x, goi)) {
  if (daCo.add(s.chuoi)) the.add('${s.nhan} ${s.chuoi}');
}
```

Hai `SoLieu` khác gói cùng `chuoi` thì **nhãn của gói đứng trước thắng**. Chặng 3 bắt được đúng
ca ấy: câu *"Ví đang âm: 1"* hiện thẻ **"Quá hạn 1"**, vì gói hoá đơn xếp trước gói ví và cả hai
cùng mang số **1**. Thẻ sinh ra để làm **nguồn kiểm chứng** lại nói về một đại lượng khác hẳn.

Luật mới: trong các `SoLieu` cùng giá trị, ưu tiên cái mà **câu thật sự nhắc tới** — mượn đúng
phép của `kiemNhan` (`tuKhoaNhan` ⊂ âm tiết câu, xét cả `ten`). Không cái nào khớp thì giữ hành
vi cũ (cái đầu theo thứ tự gói), vì khi ấy không có căn cứ nào để chọn.

Thẻ hiển thị `ten` khi có: **"Giáo dục · Tỉ lệ 90,0%"**.

⚠️ Số nhỏ (`0`, `1`, `2`, `3`, `4`) trùng nhau giữa các gói là chuyện **thường**, không phải ca
hiếm — bẫy này sẽ tái phát ở mọi lát sau nếu luật chọn nhãn không dựa vào câu.

### 3.5 Prompt nêu tên

Dòng số liệu đổi từ `Tỉ lệ: 90,0%` thành `Giáo dục · Tỉ lệ: 90,0%` khi có `ten`.

Few-shot thêm **một** ví dụ dạng *"cái nào"* — hỏi tên, đáp bằng tên — vì đó chính là dạng câu
mà bốn câu nhóm A hỏng.

⚠️ Few-shot hiện có ba ví dụ; thêm cái thứ tư làm prompt dài thêm. Đo ở §5 phải tính cả phần này.

---

## 4. Những gì lát này KHÔNG làm

- **Không** tool-calling, **không** vòng lặp — đó là lát 4b, mở sau khi đo lại.
- **Không** đổi schema (v24), **không** thêm trường đồng bộ, **không** chạm `SyncEntityType`.
- **Không** đổi `SlmRuntime`, `gacTheoCau`, `kiemSo`, `kiemGiong`.
- **Không** chữa nhóm C và D (kỳ tuỳ ý, phép so sánh) — chúng cần tool thật.
- **Không** đụng sáu khối Nhận xét: chúng dùng mẫu câu, và `ten` là trường **thêm**, mặc định
  `null` nên mọi `SoLieu` cũ giữ nguyên hành vi.

---

## 5. Ra cổng — đo lại đúng 20 câu cũ

Cùng máy (Realme RMX2205, CPU), cùng tài khoản, cùng 20 câu, cùng cách chấm bốn cột. So hai cột
*trước / sau*.

**Đạt** khi cả ba điều sau đúng:

1. **Nhóm A (câu 3, 8, 13, 15) trả lời được bằng TÊN** — ít nhất 3/4.
2. **Nhóm B (câu 12, 14, 20) thôi chọn nhầm** — ít nhất 2/3.
3. **Không câu nào đang ✅ tụt xuống** — đặc biệt 6, 10, 18, 19; và **SAI vẫn = 0**.

⚠️ Điều 3 là chốt thật sự: §3.3 **nới** một lớp chắn, nên rủi ro là câu bịa nhãn bắt đầu lọt.
Nếu SAI > 0 thì lát này **hỏng**, bất kể nhóm A đẹp đến đâu.

Đo kèm: **độ dài prompt** và **token đầu** — hai số quyết định trần `N` ở §3.2, và là dữ kiện
cho lát 4b (tool-calling cộng thêm 2 lượt sinh nữa).

---

## 6. Bẫy đã biết trước, phải canh

| # | Bẫy | Hỏng thế nào |
|---|---|---|
| 1 | Ghép tên vào `nhan` | `kiemNhan` tự chặn câu đúng — §3.1, **im lặng** |
| 2 | Prompt phình quá trần | token đầu tăng, và trên CPU nó đã 4,6 s — người dùng thấy app đứng |
| 3 | Nới `kiemNhan` quá tay | câu bịa nhãn lọt, phá đúng thứ việc số 1 vừa dựng |
| 4 | Thẻ chọn nhãn theo thứ tự gói | bẫy **4.27**, tái phát với mọi số nhỏ trùng nhau |
| 5 | Ca test xanh ngay từ đầu | **phải thử bản sai có chủ ý** — luật dự án, và đã vấp hai lần ngày 2026-09-22 |
| 6 | `adb shell input text` hỏng chữ hoa giữa từ | `MuaXe` → `Mũae`; câu có tên riêng phải chụp màn kiểm chữ đã vào (bẫy **4.28**) |

---

## 7. Test

- Hàm thuần: `kiem_nhan_test` (thêm nhóm `ten`), `the_cua_cau_test` (thêm nhóm trùng giá trị),
  `nguon_goi_so_test` (danh sách + trần `N`), từng `goi_so_*_test` cho `ten`.
- Test quét `lib/` **không thêm cái nào** — lát này không sinh ràng buộc kiểu "chỉ một nơi".
- Mức nền trước lát: `flutter test` **3424/3424**, 3 skip; `flutter analyze` **26** issue, 0 error.
