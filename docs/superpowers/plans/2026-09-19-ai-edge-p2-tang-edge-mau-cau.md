# P2 — Tầng Edge tất định + mẫu câu — kế hoạch thi công

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (người dùng chốt
> thi công **inline trong phiên** — memory `thuc-thi-ke-hoach-inline-khong-dung-agent-con`).
> Steps use checkbox (`- [ ]`) syntax for tracking. TDD từng bước; ca xanh ngay từ đầu phải thử
> **bản sai có chủ ý**.

**Goal:** Bốn màn (Ngân sách · Phân tích · Trang chủ · Mục tiêu) có khối "Nhận xét" đọc từ **gói số
typed** dựng bằng hàm domain đã có; trang Ngân sách có **kế hoạch tái phân bổ chờ duyệt** (thâm hụt
→ nguồn bù → tick từng dòng → áp dụng); cờ **Cố định** trên danh mục; bảng phản hồi cục bộ; một
loại thông báo mới. **Chạy trọn không cần mô hình.**

**Architecture:** `lib/features/ai_edge/` — `domain/` thuần Dart (gói số, mẫu câu, Tầng 2, bộ kiểm
số, dấu vân), `data/` (DAO bảng phản hồi, nguồn dữ liệu Tầng 2), `presentation/` (khối nhận xét, thẻ
số liệu, sheet kế hoạch). Mọi con số lấy từ `budgetPaceOf`, `thuNhapCua`, `tyLeTietKiem`,
`phanTramSoVoi`, `duBaoCua`, `topKhoanChi`, `GoalEntity.*`, `pickHomeBudget`; lớp AI **không** đọc
bảng giao dịch, không so chiều tiền (test quét canh). Giao diện `BoDienGiai` có bản `MauCau` ở P2,
bản SLM cắm ở P3 cùng chỗ.

**Tech Stack:** Flutter 3.47 (sau P0), Dart 3.12+, drift 2.x (schema **v24**), flutter_bloc, go_router,
`crypto` (md5 cho dấu vân — gói đã có), Stitch MCP cho ba màn mới.

**Spec:** `docs/superpowers/specs/2026-09-19-ai-edge-slm-design.md` — mục 2, 3, 5, 6, 7 và hàng P2
của mục 1.

## Global Constraints

- Chỉ sửa `src/Client-app` và tài liệu. Không đụng `src/Backend`; chỗ backend cần sửa đi qua
  `docs/superpowers/backend/CAN-LAM/`.
- **Không đổi schema đồng bộ, không thêm trường payload.** `sync_payload_contract_test.dart` không
  đổi. Hai thứ mới của v24 là **cục bộ**: cột `categories.ai_co_dinh` và bảng `AiRebalancingFeedbacks`.
- Lớp `ai_edge` **không** chứa chuỗi `'thu'`, `'chi'`, `'transfer'`, `walletId`, `transactionDao`
  (test quét thứ 14 — Task 3). Mọi con số qua hàm domain đã có.
- Mọi số tiền hiển thị qua `CurrencyFormatter.format` (một `NumberFormat` duy nhất; test quét cấm chỗ
  khác); ký hiệu `đ` **có cách** và không nối tay (`ky_hieu_tien_mot_noi_test`).
- Mọi ô nhập tiền có `GioiHanSoChuSo(kSoChuSoToiDaSoTien)`.
- Mọi `IconButton` có `tooltip`. Không handler rỗng (`khong_co_nut_chet_test`).
- Khối giao diện mới phải có màn Stitch **được người dùng nghiệm thu** trước khi dựng (Task 1).
- Đụng giao diện thì nghiệm thu **máy ảo 411dp** (`FlowMoney_16G`, `-gpu swangle`) trước khi báo xong.
- `flutter test` toàn bộ và `flutter analyze` ở mức nền ghi trong `CLAUDE.md` sau P0. Chạy test nền,
  ghi log, `--timeout 60s`, không chạy hai lần cùng lúc.
- Test mới trong `test/` phải `git add -f` từng tệp (`.gitignore` chặn `test/`).
- Commit sau mỗi task; tài liệu cập nhật **trong** task chứ không dồn cuối.
- Nhãn, câu chữ tiếng Việt có dấu; số 0 không mang dấu; nền bằng 0 không in phần trăm.

---

### Task 0: Mở cửa bằng tài liệu — khung `AI_EDGE_FEATURE.md`, tài liệu CAN-LAM, hàng mới `CLAUDE.md`

**Files:**
- Create: `docs/AI_EDGE_FEATURE.md`
- Create: `docs/superpowers/backend/CAN-LAM/AI_EDGE_SLM_SUA_TAI_LIEU.md`
- Modify: `CLAUDE.md` — bảng "Rồi tuỳ việc" (thêm một hàng sau hàng "Đụng vào thông báo")
- Modify: `docs/CLIENT_APP_KNOWN_GAPS.md` — mục A6/A11 ghi "đang xử lý ở P2/P3 Edge-SLM"

**Interfaces:**
- Produces: hai tệp tài liệu mà mọi task sau ghi kết quả vào.

- [ ] **Step 1: Kiểm hai thư mục không bị gitignore**

Run (gốc repo):
```bash
git check-ignore -v docs/AI_EDGE_FEATURE.md docs/superpowers/backend/CAN-LAM/x.md; echo "rc=$?"
```
Expected: `rc=1` (không bị chặn). Nếu bị chặn: dừng, chọn chỗ khác và báo.

- [ ] **Step 2: Viết khung `docs/AI_EDGE_FEATURE.md`**

Nội dung tối thiểu (mỗi mục là một `##`, task sau điền tiếp):

```markdown
# AI Edge-SLM trên Client-app — tài liệu tính năng

**Trạng thái:** P2 đang làm (2026-09-19). Spec: `docs/superpowers/specs/2026-09-19-ai-edge-slm-design.md`.
Bản đánh giá gốc: `docs/superpowers/backend/AI_EDGE_SLM_DANH_GIA_AP_DUNG.md` (có banner đính chính).

## 1. Tính năng này là gì, và KHÔNG phải là gì
"Máy tính số, mô hình kể chuyện về số." Tầng Edge (P2): gói số typed từ hàm domain đã có → câu
nhận xét (mẫu câu) + thẻ số liệu; Tầng 2: thâm hụt → nguồn bù → kế hoạch chờ duyệt. Tầng SLM (P3):
cùng gói số, mô hình chỉ diễn giải, có bộ kiểm số. Không học thống kê (chưa có dữ liệu).

## 2. Quyết định kèm lý do
(điền theo từng task: chọn ngân sách nào để nhận xét, vì sao essentiality = 0,5, vì sao bỏ D5, vì sao
vuốt tắt sheet không ghi phản hồi, vì sao một thông báo/tuần…)

## 3. Vị trí mã
(cây thư mục `lib/features/ai_edge/` — chép từ spec mục 2.1, cập nhật khi lệch)

## 4. Bẫy — đọc trước khi sửa
(điền khi vấp; mỗi bẫy: hiện tượng, vì sao im lặng, ca test canh)

## 5. Màn Stitch
(bảng: màn · id · ngày · người nghiệm thu)

## 6. Schema v24
(cột `categories.ai_co_dinh`, bảng `AiRebalancingFeedbacks`; test quét canh không lọt đồng bộ)

## 7. Kiểm thử
(danh sách tệp test, ba test quét mới, con số đếm bằng máy kèm ngày)

## 8. Bảng đo P1 / P3
(để trống ở P2)
```

- [ ] **Step 3: Viết `CAN-LAM/AI_EDGE_SLM_SUA_TAI_LIEU.md`**

Khuôn theo `DA-XONG/WALLET_STATUS_COLUMN_WIDTH.md` (tự đủ, không hỏi lại). Bắt buộc có:

1. Đầu tệp: ngày, nhánh `TranQuangDat`, mã commit, **"chỉ xin sửa chữ, không xin đổi mã, không xin
   schema"**, và câu dẫn tới spec.
2. Mục "Năm chỗ sai" — chép **nguyên bảng** mục 4 của `AI_EDGE_SLM_DANH_GIA_AP_DUNG.md` (F1 dòng
   367, D1 dòng 343, bảng đặc trưng dòng 406–421, dòng 83 và 402 "v21" → nay **v24** sau Task 6,
   mục 3.4 dòng 274 iOS 26), mỗi chỗ kèm **câu thay thế đề nghị** viết sẵn.
3. Mục "Đính chính mô hình" — mục 3.4 của tài liệu gốc khuyên MediaPipe + Gemma 2B: ghi rõ gói
   `flutter_gemma` không chạy Gemma 3 4B; bậc thang **Gemma 4 E4B / E2B / mẫu câu**; nguồn:
   pub.dev `flutter_gemma` 1.8.3 (2026-09-15), kiểm ngày 2026-09-19.
4. Mục "39 luật sau khi điều chỉnh" — chép **nguyên bảng** mục 11 của bản đánh giá (22 giữ / 13 sửa /
   4 hoãn), và với mỗi luật ở cột "Sửa" ghi **một câu** nói đổi thành gì (lấy từ mục 10.1 bản đánh
   giá và spec mục 3.1).
5. Mục "Kiểm lại bằng gì": `grep -n "v21\|PCI-DSS\|iOS 18\|Gemma 2B\|3 \* avg_spend" docs/AI/AI_Edge-SLM.md/Client-app.md`
   phải ra **0** dòng sau khi sửa.

⚠️ **Không** sửa `docs/AI/AI_Edge-SLM.md/Client-app.md` — tệp do backend quản (memory
`tai-lieu-backend-chi-viet-huong-dan`). **Không** chèn dòng vào `CAN-LAM/README.md` (backend viết
lại toàn bộ tệp ấy — `CLAUDE.md`).

- [ ] **Step 4: Thêm hàng vào bảng "Rồi tuỳ việc" của `CLAUDE.md`**

Chèn ngay sau hàng `| Đụng vào thông báo | ... |`:

```markdown
| Đụng vào **AI Edge-SLM** (`lib/features/ai_edge/`, `ai_chat/`) | `docs/AI_EDGE_FEATURE.md` — trạng thái, quyết định kèm lý do, bẫy. Spec đã duyệt `docs/superpowers/specs/2026-09-19-ai-edge-slm-design.md`. **Luật cốt lõi**: lớp AI **không tính** — mọi số từ hàm domain đã có (test quét thứ 14 cấm so chiều tiền trong `ai_edge/`); hai thứ của schema v24 (`categories.ai_co_dinh`, bảng `AiRebalancingFeedbacks`) là **cục bộ**, không vào `SyncEntityType` (test quét thứ 15); mô hình (P3) chỉ nhận gói số và mọi con số trong câu phải có trong gói, sai thì rơi về mẫu câu. Bậc thang mô hình: Gemma 4 E4B ≥ 8 GB → E2B 4–8 GB → mẫu câu; `.litertlm` chỉ arm64 nên **máy ảo luôn đi nhánh mẫu** |
```

- [ ] **Step 5: Ghi A6/A11 vào `CLIENT_APP_KNOWN_GAPS.md`**

Tìm mục A6 ("Insight AI") và A11 (handler rỗng `ai_chat_page`): thêm câu *"Đang đóng ở P2 (A6 — khối
Nhận xét thay thẻ) và P3 (A11 — màn Trợ lý AI) của Edge-SLM, spec 2026-09-19."* Nếu hai mục ấy chưa
có trong tệp (chúng ở danh sách UX gitignore): thêm hai dòng ngắn vào bảng tóm tắt và thân, cùng
khuôn các G khác.

- [ ] **Step 6: Commit**

```bash
git add docs/AI_EDGE_FEATURE.md docs/superpowers/backend/CAN-LAM/AI_EDGE_SLM_SUA_TAI_LIEU.md CLAUDE.md docs/CLIENT_APP_KNOWN_GAPS.md
git commit -F - <<'EOF'
docs(ai-edge): mở P2 — khung AI_EDGE_FEATURE.md, tài liệu CAN-LAM xin sửa đặc tả, hàng mới CLAUDE.md

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 1: Ba màn Stitch — vẽ, chờ người dùng nghiệm thu

**Files:**
- Modify: `docs/AI_EDGE_FEATURE.md` mục 5 (id màn)

**Interfaces:**
- Produces: ba id màn Stitch đã được người dùng xác nhận; ảnh chụp tải về scratchpad để Task 12–14 đối chiếu.

- [ ] **Step 1: Đọc lại hai màn liên quan có sẵn**

Gọi `mcp__stitch__get_screen` cho `dcd3a745…` (Ngân sách với nút cấu hình) và `fa15f342…` (Thêm danh
mục — Thiết lập từ khóa AI); tải `htmlCode.downloadUrl` về scratchpad, trích chữ bằng
`sed -e 's/<[^>]*>/|/g'` và mở `screenshot.downloadUrl` bằng Read. Ghi lại: khối thẻ ngân sách trông
thế nào (để khối Nhận xét và thẻ kế hoạch đứng cạnh nó không lạc tông), màn danh mục có mục nào để đặt
công tắc.

- [ ] **Step 2: Gọi `generate_screen_from_text` ba lần, `projectId: 5106367939423432838`, `deviceType: MOBILE`**

Prompt 1 — khối Nhận xét (một màn ghép bốn biến thể):
```
Màn "Khối Nhận xét AI — bốn biến thể" cho FlowMoney (design system Kinetic Finance: nền #FAF9F5,
thẻ trắng bo 8px, Inter, chữ chính #1A1A19, xanh thu #006E1C, đỏ chi #BA1A1A). Vẽ BỐN thẻ xếp dọc,
mỗi thẻ là cùng một component "Nhận xét" ở một màn khác nhau: (1) Ngân sách: tiêu đề nhỏ chữ hoa
"NHẬN XÉT", câu "Bạn đã dùng 2.100.000 đ / 3.000.000 đ (70%), còn 9 ngày — nên chi tối đa 100.000 đ
mỗi ngày.", bên dưới hàng chip số liệu nhỏ (Đã chi 2.100.000 đ · Hạn mức 3.000.000 đ · Còn 9 ngày ·
Mỗi ngày 100.000 đ). (2) Phân tích: câu "Kỳ này chi 8.200.000 đ, tăng 12,5% so với kỳ trước; để dành
35,0% thu nhập.", chip số liệu tương ứng, viền trái màu đỏ nhạt vì có cảnh báo. (3) Trang chủ: thẻ nền
tối #1C1C1B chữ trắng, biểu tượng bóng đèn, câu "Tháng này thu 15.000.000 đ, chi 8.200.000 đ, còn
lại 6.800.000 đ.", chip số liệu nền trắng mờ. (4) Mục tiêu: câu "Mua xe: 45,0%, còn 27.500.000 đ; chậm
kế hoạch." với chip số liệu và viền trái cam. Ở thẻ (2) thêm nhãn nhỏ "AI" cạnh tiêu đề (biến thể khi
câu do mô hình sinh); các thẻ khác không có nhãn. Thêm thẻ thứ NĂM ở cuối: trạng thái thiếu dữ liệu —
câu "Chưa đủ dữ liệu tháng này để nhận xét." chữ xám, không chip. Không thanh điều hướng, không
header app.
```

Prompt 2 — thẻ + sheet kế hoạch tái phân bổ:
```
Màn "Kế hoạch tái phân bổ ngân sách" cho FlowMoney (Kinetic Finance). Trên cùng: thẻ tóm tắt trong
trang Ngân sách — tiêu đề "ĐỀ XUẤT CÂN ĐỐI", câu "Ăn uống dự kiến vượt 600.000 đ. Bớt từ 2 ngân sách
khác?", nút "Xem kế hoạch". Bên dưới vẽ bottom sheet mở ra, bo góc trên 16px: tiêu đề "Kế hoạch cân
đối ngân sách", dòng phụ "Ăn uống · thâm hụt dự kiến 600.000 đ"; danh sách hai dòng, mỗi dòng có
checkbox bên trái đã tick, tên nguồn bù ("Giải trí", "Mua sắm"), dòng phụ "dư địa 1.200.000 đ", và ô
số tiền bên phải chỉnh sửa được ("400.000 đ", "200.000 đ"); dưới danh sách: dòng tổng "Tổng bù
600.000 đ / 600.000 đ" màu xanh; hai nút: "Áp dụng" (đen, đầy) và "Bỏ qua" (ghost). Vẽ thêm biến
thể thứ hai của thẻ tóm tắt ở dưới cùng: trạng thái thiếu nguồn bù — viền đỏ, câu "Ăn uống dự kiến
vượt 900.000 đ, nhưng không ngân sách nào còn dư địa để bù (thiếu 300.000 đ)." Không thanh điều hướng.
```

Prompt 3 — công tắc Cố định trong màn Thêm/Sửa danh mục:
```
Màn "Sửa danh mục — công tắc Cố định" cho FlowMoney (Kinetic Finance), dựa trên màn Thêm danh mục
hiện có (tên, loại Chi/Thu, danh mục cha, biểu tượng, màu, từ khoá). Thêm MỘT thẻ mới ngay dưới khối
màu và trước khối từ khoá: tiêu đề "Cố định — AI không đề xuất cắt", dòng phụ "Bật cho tiền nhà, học
phí, điện nước, bảo hiểm. Trợ lý sẽ không bao giờ chọn danh mục này làm nguồn bù.", công tắc bên
phải đang BẬT (xanh #006E1C), và một chip nhỏ "Chỉ lưu trên máy này" màu xám dưới dòng phụ. Giữ nút
Lưu đen đầy ở cuối.
```

Nếu lượt gọi trả `timeout`: **không gọi lại** — chờ, làm Task 2–3 rồi quay lại `list_screens` sau
15–60 phút (memory `stitch-edit-screens-co-do-tre`).

- [ ] **Step 3: Nghiệm thu bằng người dùng**

Gọi `list_screens`, lấy ba id mới, tải ảnh về, mở xem. Rồi **hỏi người dùng** bằng AskUserQuestion:
*"Ba màn Stitch mới đã hiện chưa và có đúng ý không?"* — API không nghiệm thu được (memory). Điểm
cần họ xác nhận: chip số liệu có đủ đọc ở 390px; sheet có ô sửa số; công tắc đúng vị trí.

- [ ] **Step 4: Ghi mục 5 `AI_EDGE_FEATURE.md` và commit**

Bảng: `Khối Nhận xét · <id> · 2026-09-xx · người dùng OK`, tương tự cho hai màn kia. Ghi cả điểm lệch
mà người dùng bảo bỏ qua (nếu có).

```bash
git add docs/AI_EDGE_FEATURE.md
git commit -m "docs(ai-edge): ba màn Stitch P2 đã nghiệm thu"
```

---

### Task 2: Kiểu lõi của tầng domain — `SoLieu`, `GoiSo`, `NhanXet`, `BoDienGiai`, dấu vân

**Files:**
- Create: `lib/features/ai_edge/domain/goi_so.dart`
- Create: `lib/features/ai_edge/domain/nhan_xet.dart`
- Create: `lib/features/ai_edge/domain/bo_dien_giai.dart`
- Create: `lib/features/ai_edge/domain/dau_van.dart`
- Create: `lib/features/ai_edge/domain/mau_cau.dart`
- Test: `test/features/ai_edge/domain/goi_so_test.dart`, `test/features/ai_edge/domain/dau_van_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum LoaiSo { tien, phanTram, soNgay, soDem }
  class SoLieu { final String nhan; final double soTho; final String chuoi; final LoaiSo loai; }
  SoLieu soTien(String nhan, double v);      // chuoi = CurrencyFormatter.format(v)
  SoLieu soPhanTram(String nhan, double phanTram0den100); // chuoi = '12,5%' (1 chữ số thập phân, G2)
  SoLieu soNgay(String nhan, int ngay);     // chuoi = '9 ngày'
  SoLieu soDem(String nhan, int n);         // chuoi = '3'
  abstract class GoiSo { String get man; List<SoLieu> get soLieu; bool get thieuDuLieu; NhanXet mauCau(); String get dauVan; }
  enum MucNhanXet { binhThuong, canhBao, thieuDuLieu }
  class NhanXet { final String cau; final List<SoLieu> theSoLieu; final MucNhanXet muc; final bool tuMoHinh; }
  abstract class BoDienGiai { Future<NhanXet> dienGiai(GoiSo goi); }
  class MauCau implements BoDienGiai { Future<NhanXet> dienGiai(GoiSo g) async => g.mauCau(); }
  String dauVanCua(GoiSo g);  // md5 của 'man|nhan=soTho|...' sắp theo nhãn
  ```

- [ ] **Step 1: Viết test đỏ cho định dạng số liệu và dấu vân**

`test/features/ai_edge/domain/goi_so_test.dart`:
```dart
import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('soTien dùng CurrencyFormatter: chấm nghìn, có cách, ký hiệu đ', () {
    expect(soTien('Đã chi', 2100000).chuoi, '2.100.000 đ');
  });
  test('soPhanTram in ĐÚNG một chữ số thập phân, phẩy thập phân (G2)', () {
    expect(soPhanTram('Tăng', 12.5).chuoi, '12,5%');
    expect(soPhanTram('Tăng', 35).chuoi, '35,0%');
    expect(soPhanTram('Tăng', 12.55).chuoi, '12,6%', reason: 'làm tròn, không cắt');
  });
  test('soNgay và soDem', () {
    expect(soNgay('Còn', 9).chuoi, '9 ngày');
    expect(soDem('Số cam kết', 3).chuoi, '3');
  });
}
```

`test/features/ai_edge/domain/dau_van_test.dart` — dùng một `GoiSo` giả:
```dart
import 'package:flowmoney/features/ai_edge/domain/dau_van.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gia extends GoiSo {
  @override final String man;
  @override final List<SoLieu> soLieu;
  _Gia(this.man, this.soLieu);
  @override bool get thieuDuLieu => soLieu.isEmpty;
  @override NhanXet mauCau() => NhanXet(cau: '', theSoLieu: soLieu, muc: MucNhanXet.binhThuong);
}

void main() {
  test('đổi một số là đổi dấu vân', () {
    final a = _Gia('ngan_sach', [soTien('Đã chi', 1), soTien('Hạn mức', 2)]);
    final b = _Gia('ngan_sach', [soTien('Đã chi', 1), soTien('Hạn mức', 3)]);
    expect(dauVanCua(a), isNot(dauVanCua(b)));
  });
  test('đổi THỨ TỰ số liệu không đổi dấu vân', () {
    final a = _Gia('ngan_sach', [soTien('Đã chi', 1), soTien('Hạn mức', 2)]);
    final b = _Gia('ngan_sach', [soTien('Hạn mức', 2), soTien('Đã chi', 1)]);
    expect(dauVanCua(a), dauVanCua(b));
  });
  test('cùng số nhưng khác màn là hai dấu vân', () {
    final a = _Gia('ngan_sach', [soTien('X', 1)]);
    final b = _Gia('trang_chu', [soTien('X', 1)]);
    expect(dauVanCua(a), isNot(dauVanCua(b)));
  });
}
```

- [ ] **Step 2: Chạy, xác nhận đỏ**

Run: `flutter test test/features/ai_edge/domain/`
Expected: lỗi biên dịch (chưa có tệp).

- [ ] **Step 3: Viết mã tối thiểu**

`goi_so.dart`:
```dart
/// Gói số — đầu vào DUY NHẤT của mọi bộ diễn giải (mẫu câu ở P2, SLM ở P3).
///
/// Lớp này **không tính**: mọi con số đến từ hàm domain đã có của từng màn.
/// Test quét `ai_edge_khong_tinh_test.dart` cấm ở đây phép so chiều tiền.
library;

import '../../../core/utils/currency_formatter.dart';
import 'dau_van.dart';
import 'nhan_xet.dart';

enum LoaiSo { tien, phanTram, soNgay, soDem }

class SoLieu {
  final String nhan;
  final double soTho;
  /// Chuỗi đã định dạng — thẻ số liệu, tập cho phép của bộ kiểm số, và phần
  /// đưa vào prompt để mô hình chép nguyên.
  final String chuoi;
  final LoaiSo loai;
  const SoLieu({required this.nhan, required this.soTho, required this.chuoi, required this.loai});
}

SoLieu soTien(String nhan, double v) =>
    SoLieu(nhan: nhan, soTho: v, chuoi: CurrencyFormatter.format(v), loai: LoaiSo.tien);

/// G2: một chữ số thập phân, phẩy thập phân. [phanTram] ở thang 0–100.
SoLieu soPhanTram(String nhan, double phanTram) => SoLieu(
      nhan: nhan,
      soTho: phanTram,
      chuoi: '${phanTram.toStringAsFixed(1).replaceAll('.', ',')}%',
      loai: LoaiSo.phanTram,
    );

SoLieu soNgay(String nhan, int ngay) =>
    SoLieu(nhan: nhan, soTho: ngay.toDouble(), chuoi: '$ngay ngày', loai: LoaiSo.soNgay);

SoLieu soDem(String nhan, int n) =>
    SoLieu(nhan: nhan, soTho: n.toDouble(), chuoi: '$n', loai: LoaiSo.soDem);

abstract class GoiSo {
  /// Tên màn: `ngan_sach` | `phan_tich` | `trang_chu` | `muc_tieu`.
  String get man;
  List<SoLieu> get soLieu;
  bool get thieuDuLieu;
  /// Bản mẫu câu — luôn có, là thứ SLM rơi về.
  NhanXet mauCau();
  String get dauVan => dauVanCua(this);
}
```
`nhan_xet.dart`:
```dart
import 'goi_so.dart';
enum MucNhanXet { binhThuong, canhBao, thieuDuLieu }
class NhanXet {
  final String cau;
  final List<SoLieu> theSoLieu;
  final MucNhanXet muc;
  /// `true` khi câu do mô hình sinh (P3) — giao diện gắn nhãn "AI".
  final bool tuMoHinh;
  const NhanXet({required this.cau, required this.theSoLieu, required this.muc, this.tuMoHinh = false});
}
```
`bo_dien_giai.dart`:
```dart
import 'goi_so.dart';
import 'nhan_xet.dart';
abstract class BoDienGiai { Future<NhanXet> dienGiai(GoiSo goi); }
```
`mau_cau.dart`:
```dart
import 'bo_dien_giai.dart';
import 'goi_so.dart';
import 'nhan_xet.dart';
/// Bản thi công KHÔNG mô hình — chạy tức thì, offline, test được trọn vẹn.
class MauCau implements BoDienGiai {
  const MauCau();
  @override
  Future<NhanXet> dienGiai(GoiSo goi) async => goi.mauCau();
}
```
`dau_van.dart`:
```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'goi_so.dart';
/// Khoá cache của một gói số: md5 của tên màn + cặp (nhãn, số thô) sắp theo nhãn.
/// Sắp xếp để thứ tự dựng danh sách không đổi khoá; nhãn vào khoá để hai gói
/// cùng số nhưng khác nghĩa không dùng chung câu.
String dauVanCua(GoiSo g) {
  final cap = [for (final s in g.soLieu) '${s.nhan}=${s.soTho}']..sort();
  return md5.convert(utf8.encode('${g.man}|${cap.join('|')}')).toString();
}
```

- [ ] **Step 4: Chạy, xác nhận xanh**

Run: `flutter test test/features/ai_edge/domain/` — Expected: 7 pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/ai_edge/domain/goi_so.dart lib/features/ai_edge/domain/nhan_xet.dart lib/features/ai_edge/domain/bo_dien_giai.dart lib/features/ai_edge/domain/mau_cau.dart lib/features/ai_edge/domain/dau_van.dart
git add -f test/features/ai_edge/domain/goi_so_test.dart test/features/ai_edge/domain/dau_van_test.dart
git commit -m "feat(ai-edge): kiểu lõi tầng domain — SoLieu, GoiSo, NhanXet, BoDienGiai, dấu vân"
```

---

### Task 3: Test quét `lib/` thứ 14 — lớp `ai_edge` không tính, không đọc bảng giao dịch

**Files:**
- Test: `test/features/ai_edge/ai_edge_khong_tinh_test.dart`
- Modify: `docs/AI_EDGE_FEATURE.md` mục 7

**Interfaces:**
- Produces: lưới quét mà mọi task sau phải giữ xanh.

- [ ] **Step 1: Viết test**

```dart
/// Test quét `lib/` thứ MƯỜI BỐN: `lib/features/ai_edge/` KHÔNG được tự tính.
///
/// Mọi con số của tầng Edge phải đến từ hàm domain đã có (`budgetPaceOf`,
/// `thuNhapCua`, `tyLeTietKiem`…). Một phép so chiều tiền viết lại ở đây là
/// bản định nghĩa thứ hai — và bản thứ hai là thứ đã sinh ra bẫy A8 #8 (thu
/// nhập gồm cả tiền đi vay), im lặng.
library;
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cam = ["'thu'", "'chi'", "'transfer'", 'walletId', 'transactionDao',
      'db.transactions', '.type ==', 'amount <', 'amount >'];
  test('ai_edge/ không chứa phép so chiều tiền hay truy cập bảng giao dịch', () {
    final loi = <String>[];
    for (final f in Directory('lib/features/ai_edge').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final dongs = f.readAsLinesSync();
      for (var i = 0; i < dongs.length; i++) {
        final d = dongs[i].trim();
        if (d.startsWith('//') || d.startsWith('///')) continue;
        for (final c in cam) {
          if (d.contains(c)) loi.add('${f.path}:${i + 1}: $c');
        }
      }
    }
    expect(loi, isEmpty, reason: 'Lớp AI chỉ được NHẬN số, không được tính:\n${loi.join('\n')}');
  });
}
```

- [ ] **Step 2: Chạy — xanh ngay (thư mục mới sạch). Dựng bản sai có chủ ý**

Thêm tạm vào `goi_so.dart` một dòng `final _x = 'thu';` → chạy test → **phải đỏ** với đúng
`goi_so.dart:<dòng>: 'thu'`. Gỡ dòng ấy, chạy lại → xanh. Ghi vào `AI_EDGE_FEATURE.md` mục 7: "Test
quét 14, bản sai có chủ ý làm đỏ ngày …".

- [ ] **Step 3: Commit**

```bash
git add -f test/features/ai_edge/ai_edge_khong_tinh_test.dart; git add docs/AI_EDGE_FEATURE.md
git commit -m "test(ai-edge): test quét lib/ thứ 14 — lớp AI không tính"
```

---

### Task 4: Bộ kiểm số — `kiem_so.dart`

**Files:**
- Create: `lib/features/ai_edge/domain/kiem_so.dart`
- Test: `test/features/ai_edge/domain/kiem_so_test.dart`

**Interfaces:**
- Produces:
  ```dart
  /// Mọi chuỗi số trong [cau] (kể cả `3.200.000 đ`, `35,0%`, `9 ngày`, `3`), đã chuẩn hoá.
  List<SoTrich> trichSo(String cau);           // SoTrich { double giaTri; bool laPhanTram; }
  /// `true` khi MỌI số trong câu khớp một SoLieu của gói (tiền: ±0,5 đ; %: ±0,05; khác: bằng).
  bool kiemSo(String cau, GoiSo goi);
  ```

- [ ] **Step 1: Test đỏ**

```dart
import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gia extends GoiSo {
  @override final String man = 'ngan_sach';
  @override final List<SoLieu> soLieu;
  _Gia(this.soLieu);
  @override bool get thieuDuLieu => false;
  @override NhanXet mauCau() => NhanXet(cau: '', theSoLieu: soLieu, muc: MucNhanXet.binhThuong);
}

void main() {
  final goi = _Gia([soTien('Đã chi', 2100000), soPhanTram('Tỉ lệ', 70), soNgay('Còn', 9)]);

  test('trichSo đọc được tiền có chấm nghìn, phần trăm có phẩy, số trần', () {
    final s = trichSo('Bạn đã dùng 2.100.000 đ (70,0%), còn 9 ngày.');
    expect(s.map((x) => x.giaTri), [2100000, 70, 9]);
    expect(s[1].laPhanTram, isTrue);
  });
  test('câu đúng số lọt', () {
    expect(kiemSo('Bạn đã dùng 2.100.000 đ (70,0%), còn 9 ngày.', goi), isTrue);
  });
  test('câu BỊA một số bị chặn', () {
    expect(kiemSo('Bạn đã dùng 2.150.000 đ, còn 9 ngày.', goi), isFalse,
        reason: '2.150.000 không có trong gói — đây là ca hội đồng sẽ hỏi');
  });
  test('câu không có số nào thì lọt', () {
    expect(kiemSo('Bạn đang chi tiêu đúng nhịp.', goi), isTrue);
  });
  test('phần trăm làm tròn khác 0,05 bị chặn, trong 0,05 lọt', () {
    expect(kiemSo('Bạn đã dùng 70,04%.', goi), isTrue);
    expect(kiemSo('Bạn đã dùng 70,2%.', goi), isFalse);
  });
  test('số tiền lệch 1 đồng bị chặn (ngưỡng nửa đồng)', () {
    expect(kiemSo('Bạn đã dùng 2.100.001 đ.', goi), isFalse);
  });
}
```

- [ ] **Step 2: Chạy đỏ** — `flutter test test/features/ai_edge/domain/kiem_so_test.dart`

- [ ] **Step 3: Viết `kiem_so.dart`**

```dart
/// Bộ kiểm số — điều kiện 10 của mục 13 bản đánh giá: mọi con số trong câu
/// phải có trong gói số; sai thì người gọi rơi về mẫu câu.
library;
import 'goi_so.dart';

class SoTrich {
  final double giaTri;
  final bool laPhanTram;
  const SoTrich(this.giaTri, {required this.laPhanTram});
}

// Nhóm 1: phần nguyên có/không chấm nghìn; nhóm 2: phần thập phân sau PHẨY;
// nhóm 3: hậu tố %. Không bắt `đ` — có hay không đều là một con số.
final _mau = RegExp(r'(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d+))?\s*(%)?');

List<SoTrich> trichSo(String cau) => [
      for (final m in _mau.allMatches(cau))
        SoTrich(
          double.parse('${m.group(1)!.replaceAll('.', '')}.${m.group(2) ?? '0'}'),
          laPhanTram: m.group(3) != null,
        ),
    ];

bool _khop(SoTrich x, SoLieu s) {
  final lech = (x.giaTri - s.soTho).abs();
  return switch (s.loai) {
    LoaiSo.tien => !x.laPhanTram && lech <= 0.5,
    LoaiSo.phanTram => x.laPhanTram && lech <= 0.05,
    LoaiSo.soNgay || LoaiSo.soDem => !x.laPhanTram && lech == 0,
  };
}

bool kiemSo(String cau, GoiSo goi) =>
    trichSo(cau).every((x) => goi.soLieu.any((s) => _khop(x, s)));
```

- [ ] **Step 4: Chạy xanh** — 6 pass. Chạy cả test quét Task 3 — vẫn xanh.

- [ ] **Step 5: Commit**

```bash
git add lib/features/ai_edge/domain/kiem_so.dart; git add -f test/features/ai_edge/domain/kiem_so_test.dart
git commit -m "feat(ai-edge): bộ kiểm số — mọi số trong câu phải có trong gói"
```

---

### Task 5: Gói số + mẫu câu **Ngân sách**

**Files:**
- Create: `lib/features/ai_edge/domain/goi_so_ngan_sach.dart`
- Test: `test/features/ai_edge/domain/goi_so_ngan_sach_test.dart`

**Interfaces:**
- Consumes: `BudgetView`, `budgetPaceOf(BudgetEntity, DateTime)`, `pickHomeBudget(List<BudgetView>, DateTime)` (từ `features/home/presentation/widgets/home_budget_card.dart`), `KeHoachTaiPhanBo` (Task 9 — ở task này tham số để `null`).
- Produces:
  ```dart
  class GoiSoNganSach extends GoiSo {
    factory GoiSoNganSach.tu(List<BudgetView> dangChay, {required DateTime now, KeHoachTaiPhanBo? keHoach});
    final String? ten; final double hanMuc, daChi, nenChiMoiNgay; final int ngayConLai; final double phanTram; final bool vuot;
  }
  ```
  Ngân sách được nhận xét = `pickHomeBudget` (căng nhất). Thiếu dữ liệu khi danh sách rỗng.

- [ ] **Step 1: Test đỏ** (dựng `BudgetEntity` như các test ngân sách khác — xem `test/features/budget/domain/budget_pace_test.dart` để lấy hàm dựng; chép hàm `_ns(amount, spent)` sang)

Các ca:
1. rỗng → `thieuDuLieu`, `mauCau().muc == MucNhanXet.thieuDuLieu`, câu là `'Chưa có ngân sách nào đang chạy để nhận xét.'`, `theSoLieu` rỗng.
2. một ngân sách 3.000.000 đã chi 2.100.000, now giữa kỳ 30 ngày ở ngày 21 → câu chứa `'2.100.000 đ / 3.000.000 đ (70,0%)'`, `'còn 9 ngày'` hoặc đúng số `budgetPaceOf` trả (tính bằng chính hàm ấy trong test, **không** ghi cứng 9 nếu mốc khác), muc `binhThuong`, `soLieu` có 4 phần tử nhãn `Đã chi`, `Hạn mức`, `Còn`, `Mỗi ngày`.
3. vượt hạn mức → muc `canhBao`, câu chứa `'đã vượt'`.
4. `kiemSo(mauCau().cau, goi)` **luôn true** cho ca 2 và 3 (mẫu câu phải tự qua được bộ kiểm — nếu không, P3 sẽ rơi về một câu mà bộ kiểm cũng chặn).

- [ ] **Step 2: Chạy đỏ.**

- [ ] **Step 3: Viết mã**

```dart
import '../../budget/data/models/budget_entity.dart';
import '../../budget/domain/budget_pace.dart';
import '../../home/presentation/widgets/home_budget_card.dart' show pickHomeBudget;
import 'goi_so.dart';
import 'nhan_xet.dart';
import 'tai_phan_bo.dart';

class GoiSoNganSach extends GoiSo {
  @override String get man => 'ngan_sach';
  final String? ten;
  final double hanMuc, daChi, nenChiMoiNgay, phanTram;
  final int ngayConLai;
  final bool vuot;
  final KeHoachTaiPhanBo? keHoach;
  @override final List<SoLieu> soLieu;

  GoiSoNganSach._({required this.ten, required this.hanMuc, required this.daChi,
      required this.nenChiMoiNgay, required this.phanTram, required this.ngayConLai,
      required this.vuot, required this.keHoach, required this.soLieu});

  factory GoiSoNganSach.tu(List<BudgetView> dangChay, {required DateTime now, KeHoachTaiPhanBo? keHoach}) {
    final v = pickHomeBudget(dangChay, now);
    if (v == null) {
      return GoiSoNganSach._(ten: null, hanMuc: 0, daChi: 0, nenChiMoiNgay: 0, phanTram: 0,
          ngayConLai: 0, vuot: false, keHoach: keHoach, soLieu: const []);
    }
    final b = v.budget;
    final nhip = budgetPaceOf(b, now);
    final pt = b.rawPercentSpent * 100;
    return GoiSoNganSach._(
      ten: v.displayName, hanMuc: b.amount, daChi: b.spent, nenChiMoiNgay: nhip.suggestedPerDay,
      phanTram: pt, ngayConLai: nhip.daysLeft, vuot: b.isOverBudget, keHoach: keHoach,
      soLieu: [soTien('Đã chi', b.spent), soTien('Hạn mức', b.amount),
               soPhanTram('Tỉ lệ', pt), soNgay('Còn', nhip.daysLeft),
               if (!b.isOverBudget) soTien('Mỗi ngày', nhip.suggestedPerDay)],
    );
  }

  @override bool get thieuDuLieu => ten == null;

  @override
  NhanXet mauCau() {
    if (thieuDuLieu) {
      return const NhanXet(cau: 'Chưa có ngân sách nào đang chạy để nhận xét.',
          theSoLieu: [], muc: MucNhanXet.thieuDuLieu);
    }
    final s = {for (final x in soLieu) x.nhan: x.chuoi};
    final cau = vuot
        ? '$ten đã vượt hạn mức: ${s['Đã chi']} / ${s['Hạn mức']} (${s['Tỉ lệ']}), còn ${s['Còn']}.'
        : '$ten: đã dùng ${s['Đã chi']} / ${s['Hạn mức']} (${s['Tỉ lệ']}), còn ${s['Còn']} — nên chi tối đa ${s['Mỗi ngày']} mỗi ngày.';
    final kh = keHoach;
    final duoi = kh == null ? '' : ' ${kh.cauTomTat}';
    return NhanXet(cau: cau + duoi, theSoLieu: soLieu,
        muc: vuot ? MucNhanXet.canhBao : MucNhanXet.binhThuong);
  }
}
```
Ở task này `tai_phan_bo.dart` chưa có → tạo **tạm** tệp với `class KeHoachTaiPhanBo { String get cauTomTat => ''; }` rỗng; Task 9 thay bằng bản thật (ghi chú `// Task 9 thay`).

- [ ] **Step 4: Chạy xanh; chạy test quét Task 3** (nếu đỏ vì `soLieu` chứa `'chi'`? — không: chuỗi `'Đã chi'` khác `'chi'` có nháy đơn; nhưng cụm `'Mỗi ngày'`… kiểm lại danh sách cấm bắt **`'chi'` có nháy đơn hai đầu**, `'Đã chi'` không khớp).

- [ ] **Step 5: Commit** `feat(ai-edge): gói số + mẫu câu Ngân sách`.

---

### Task 6: Gói số + mẫu câu **Phân tích**

**Files:**
- Create: `lib/features/ai_edge/domain/goi_so_phan_tich.dart`
- Test: `test/features/ai_edge/domain/goi_so_phan_tich_test.dart`

**Interfaces:**
- Consumes: `ThongKeKy` (`tong`, `tongTruoc`, `chuoiVayNo`, `duBao`, `topChi`, `ky`), `phanTramSoVoi(nay, truoc)` (`null` khi nền 0), `thuNhapCua(tong:, vayNo:)`, `tyLeTietKiem(thuNhap:, chi:)`.
- Produces: `GoiSoPhanTich.tu(ThongKeKy tk)`; số liệu: `Tổng chi`, `Tổng thu`, `So kỳ trước` (%, chỉ khi `phanTramSoVoi != null`), `Để dành` (%, chỉ khi `tyLe != null`), `Cam kết 30 ngày` (tiền, chỉ khi `duBao != null && camKet.isNotEmpty`), `Khoản lớn nhất` (tiền, khi `topChi.isNotEmpty`).

- [ ] **Step 1: Test đỏ** — dựng `ThongKeKy` bằng cách gọi đúng constructor với các trường rỗng (xem `test/features/analytics/analytics_page_test.dart` helper `_tk`; **chép** helper ấy sang, không import test khác). Ca:
1. `tong = 0/0` → thiếu dữ liệu, câu `'Kỳ này chưa có giao dịch để nhận xét.'`.
2. chi 8.200.000, kỳ trước 7.288.889 → câu chứa `'tăng 12,5%'` (dùng đúng `phanTramSoVoi` để lấy số rồi định dạng — không ghi cứng nếu lệch).
3. kỳ trước = 0 → câu **không** chứa `%` ở vế so sánh (nền bằng 0 không in phần trăm).
4. `chuoiVayNo` rỗng → không có vế "để dành".
5. thu nhập > 0 → vế `'để dành 35,0% thu nhập'` (số từ `tyLeTietKiem`×100).
6. `kiemSo(mauCau().cau, goi)` true ở ca 2 và 5.
7. muc `canhBao` khi `tong.chi > tong.thu` (chi vượt thu trong kỳ).

- [ ] **Step 2: Chạy đỏ.** — **Step 3: Viết mã** theo khuôn Task 5: tính `pt = phanTramSoVoi(tk.tong.chi, tk.tongTruoc.chi)`, `tyLe = tk.chuoiVayNo.isEmpty ? null : tyLeTietKiem(thuNhap: thuNhapCua(tong: tk.tong, vayNo: tk.chuoiVayNo.last), chi: tk.tong.chi)` (**đúng** biểu thức `_TheConLai` của `analytics_page.dart:591`), câu:
`'${tk.ky.nhanRong}: chi ${Tổng chi}' + (pt != null ? ', ${pt >= 0 ? 'tăng' : 'giảm'} ${|pt|%} so với kỳ trước' : '') + (tyLe != null ? '; để dành ${tyLe×100}% thu nhập' : '') + '.'` + vế dự báo `' 30 ngày tới có ${Cam kết 30 ngày} cam kết phải trả.'` khi có.
Kiểm `Ky` có `nhanRong`/`nhan` — dùng đúng getter đang có ở `pham_vi_ky.dart` (`nhan`).

- [ ] **Step 4: Chạy xanh + test quét.** — **Step 5: Commit** `feat(ai-edge): gói số + mẫu câu Phân tích`.

---

### Task 7: Gói số + mẫu câu **Mục tiêu**

**Files:**
- Create: `lib/features/ai_edge/domain/goi_so_muc_tieu.dart`
- Test: `test/features/ai_edge/domain/goi_so_muc_tieu_test.dart`

**Interfaces:**
- Consumes: `List<GoalEntity>` (thứ tự như trang Mục tiêu đang hiện — đã sắp theo ưu tiên ở cubit), `chiaMucTieu(goals).dangTheoDuoi`, `GoalEntity.progress`, `remainingAmount`, `daysLeft(now)`, `isBehindSchedule(now)`.
- Produces: `GoiSoMucTieu.tu(List<GoalEntity> goals, {required DateTime now})` — mục tiêu = **phần tử đầu** của `dangTheoDuoi`; số liệu `Tiến độ` (%), `Còn thiếu` (tiền), `Còn` (ngày, chỉ khi `daysLeft >= 0`).

- [ ] **Step 1: Test đỏ** (dựng `GoalEntity` như `test/features/goal/...` — chép helper): rỗng → `'Chưa có mục tiêu nào đang theo đuổi.'`; đúng nhịp → `'{tên}: {tiến độ}, còn thiếu {tiền}, còn {ngày}; đúng kế hoạch.'` muc `binhThuong`; `isBehindSchedule` → `'…; chậm kế hoạch.'` muc `canhBao`; quá hạn (`daysLeft < 0`) → không in vế "còn … ngày", câu `'…; đã quá hạn.'`; `kiemSo` true.

- [ ] **Step 2–5:** đỏ → mã → xanh (+ test quét) → commit `feat(ai-edge): gói số + mẫu câu Mục tiêu`.

---

### Task 8: Gói số + mẫu câu **Trang chủ**

**Files:**
- Create: `lib/features/ai_edge/domain/goi_so_trang_chu.dart`
- Test: `test/features/ai_edge/domain/goi_so_trang_chu_test.dart`

**Interfaces:**
- Consumes: **số đã hiện trên Trang chủ** — `thu`, `chi` (đúng hai số `TheSoLieuThang` nhận), `tongSoDu` (số `_buildAssetCard` nhận), `List<BudgetView>` (để `pickHomeBudget`). Gói **không** tự cộng giao dịch — nhận số từ trang, để "số trên thẻ = số trong gói" (điều kiện 12).
- Produces: `GoiSoTrangChu.tu({required double thu, required double chi, required double tongSoDu, required List<BudgetView> nganSach, required DateTime now})`; số liệu `Thu`, `Chi`, `Còn lại` (= thu − chi; **có dấu** qua `CurrencyFormatter.formatCoDau`? — không: `soTien` dùng `format`, còn câu in `'còn lại −x'` khi âm bằng `formatCoDau(x, thu: false)`), `Tổng số dư`, và `Ngân sách căng nhất` (%) khi có.

- [ ] **Step 1: Test đỏ**: thu = chi = 0 → thiếu dữ liệu `'Tháng này chưa có giao dịch.'`; thu 15tr chi 8,2tr → `'Tháng này thu 15.000.000 đ, chi 8.200.000 đ, còn lại 6.800.000 đ.'`; chi > thu → muc `canhBao`, câu `'…, chi vượt thu 1.200.000 đ.'`; có ngân sách căng 70% → thêm `' Ngân sách Ăn uống đã dùng 70,0%.'`; `kiemSo` true; **số 0 không mang dấu**.

- [ ] **Step 2–5:** đỏ → mã → xanh → commit `feat(ai-edge): gói số + mẫu câu Trang chủ`.

---

### Task 9: Tầng 2 — `tai_phan_bo.dart` (thâm hụt, nguồn bù, kế hoạch)

**Files:**
- Replace: `lib/features/ai_edge/domain/tai_phan_bo.dart` (bản tạm của Task 5)
- Test: `test/features/ai_edge/domain/tai_phan_bo_test.dart`

**Interfaces:**
- Consumes: `BudgetView`, `budgetPaceOf`, `recentPeriods` (`budget_history.dart`).
- Produces:
  ```dart
  const kNguongThamHutTiLe = 0.10, kNguongThamHutTuyetDoi = 50000.0, kDuDiaToiThieu = 100000.0,
        kTranCat = 0.25, kTranCatDaBiCat = 0.15, kBuocLamTron = 10000, kNgayKhoaDuPhong = 5;
  double? duPhongCua(BudgetView v, {required DateTime now, required double? tb3Thang});
  double lamTron10k(double x);
  double nguongCoNghia(double thuNhap3Thang);           // max(1% thu nhập, 50.000)
  class DongTaiPhanBo { final BudgetView nguon; final double soTien; }
  enum TrangThaiKeHoach { duNguonBu, thieuNguonBu }
  class KeHoachTaiPhanBo {
    final BudgetView thieu; final double thamHut; final List<DongTaiPhanBo> dong;
    final TrangThaiKeHoach trangThai; final double soThieu;
    double get tongCat; String get cauTomTat;  // "Ăn uống dự kiến vượt 600.000 đ. Bớt từ 2 ngân sách khác?" / bản thiếu
  }
  class PhanHoiCu { final String donorBudgetId; final String action; final DateTime periodFrom; }
  bool daBiCatHaiKyLienTruoc(BudgetEntity nguon, List<PhanHoiCu> phanHoi, DateTime now);
  KeHoachTaiPhanBo? taiPhanBoCua({
    required List<BudgetView> dangChay, required DateTime now, required Set<String> coDinh,
    required double thuNhap3Thang, required Map<String, double?> tb3ThangTheoNganSach,
    required List<PhanHoiCu> phanHoi,
  });
  ```
  `coDinh` là tập **categoryId**. Nhiều ngân sách thâm hụt → chọn **thâm hụt lớn nhất**. Nguồn bù sắp
  theo dư địa giảm dần (essentiality = 0,5 cho mọi danh mục — ghi chú trong mã và tài liệu).

- [ ] **Step 1: Test đỏ** — helper `_v(id, cat, amount, spent, {from})` dựng `BudgetView` kỳ tháng; `now` cố định `DateTime(2026, 9, 21)`; kỳ `1/9–1/10`.
Ca (mỗi ca một `test`):
1. `duPhongCua`: 20 ngày trôi, chi 2tr → 3tr (2tr×30/20); dưới 5 ngày với tb3Thang 3tr → `spent + 3tr × conLai/30`; dưới 5 ngày không tb → `null`.
2. Thâm hụt phải qua **cả hai** ngưỡng: hạn mức 3tr, dự phóng 3,25tr (8,3 %) → không kế hoạch; dự phóng 3,4tr nhưng hạn mức 300k (thâm hụt 40k < 50k) → không.
3. Có nguồn bù: Ăn uống thâm hụt 600k; Giải trí hạn 2tr dự phóng 800k (dư 1,2tr → cắt tối đa 300k); Mua sắm dư 2tr (cắt tối đa 500k) → `dong` = [Mua sắm 500k, Giải trí 100k] (theo dư địa giảm dần, cắt tới đủ), `trangThai duNguonBu`, `tongCat == 600000`.
4. Cờ Cố định thắng dư địa lớn: Mua sắm trong `coDinh` → không được chọn dù dư 2tr.
5. Dư địa dưới 100k không được chọn.
6. Trần 15 % khi `daBiCatHaiKyLienTruoc` — `phanHoi` có hai dòng `accepted` với `periodFrom` = 1/8 và 1/7 → cắt tối đa 0,15 × dư địa.
7. Làm tròn 10k: dư địa 1.234.567 → cắt 25 % = 308.641 → **310.000**.
8. Ngưỡng có nghĩa: thu nhập 3 tháng 20tr → ngưỡng 200k; dòng 100k bị bỏ.
9. Cạn nguồn: tổng cắt 300k < 600k → `thieuNguonBu`, `soThieu == 300000`, `cauTomTat` chứa `'thiếu 300.000 đ'`.
10. Không ngân sách nào thâm hụt → `null`.
11. Hai ngân sách thâm hụt → kế hoạch cho cái thâm hụt **lớn hơn**.
12. `categoryId == null` bị bỏ qua cả hai vai.

- [ ] **Step 2: Chạy đỏ.** — **Step 3: Viết mã** đúng công thức spec mục 3.1; `daBiCatHaiKyLienTruoc` dùng `recentPeriods(b, count: 3, now: now)` lấy hai kỳ trước kỳ hiện tại và kiểm mỗi kỳ có ≥ 1 dòng `accepted`/`modified` cùng `donorBudgetId` với `periodFrom` trong `[from, to)`.

- [ ] **Step 4: Chạy xanh (12 ca) + test quét + Task 5 vẫn xanh.** — **Step 5: Commit** `feat(ai-edge): Tầng 2 — thâm hụt, nguồn bù, kế hoạch tái phân bổ`. Ghi mục 2 `AI_EDGE_FEATURE.md`: vì sao xếp theo dư địa, vì sao bỏ D5, vì sao một kế hoạch/lượt.

---

### Task 10: Schema v24 — cột `ai_co_dinh`, bảng `AiRebalancingFeedbacks`, DAO, test quét thứ 15

**Files:**
- Modify: `lib/core/database/tables/categories_table.dart` (thêm cột sau `isLocalOnly`)
- Create: `lib/core/database/tables/ai_feedback_table.dart`
- Create: `lib/core/database/daos/ai_feedback_dao.dart`
- Modify: `lib/core/database/app_database.dart` — `tables:`, `daos:`, `schemaVersion => 24`, `onUpgrade` khối `from < 24`, `purgeDataForOtherAccounts` (+ hàm xoá theo tài khoản ngay dưới nó, đọc docstring để giữ "chín bảng" → mười)
- Test: `test/core/database/schema_v24_test.dart`, `test/features/ai_edge/ai_edge_cuc_bo_khong_dong_bo_test.dart`
- Modify: `docs/AI_EDGE_FEATURE.md` mục 6; `CLAUDE.md` dòng `# Sau khi sửa Drift tables/DAOs (schema hiện tại: v23)` → v24

**Interfaces:**
- Produces: `Category.aiCoDinh` (bool), bảng:
  ```dart
  class AiRebalancingFeedbacks extends Table {
    TextColumn get id => text()();
    IntColumn get idaccount => integer()();
    DateTimeColumn get createdAt => dateTime()();
    TextColumn get deficitBudgetId => text()();
    TextColumn get donorBudgetId => text()();
    TextColumn get donorCategoryId => text()();
    RealColumn get suggestedAmount => real()();
    RealColumn get actualAmount => real()();
    TextColumn get action => text()();          // accepted | rejected | modified
    DateTimeColumn get periodFrom => dateTime()();
    DateTimeColumn get periodTo => dateTime()();
    @override Set<Column> get primaryKey => {id};
  }
  ```
  DAO: `Future<void> ghi(AiRebalancingFeedbacksCompanion)`, `Future<List<AiRebalancingFeedback>> getAll(int idaccount)`.

- [ ] **Step 1: Test đỏ — `schema_v24_test.dart`**

```dart
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schema là v24', () => expect(db.schemaVersion, 24));
  test('categories có cột ai_co_dinh mặc định false', () async {
    final cols = await db.customSelect("PRAGMA table_info('categories')").get();
    final c = cols.firstWhere((r) => r.read<String>('name') == 'ai_co_dinh');
    expect(c.read<String>('type').toUpperCase(), contains('INT'));
  });
  test('bảng ai_rebalancing_feedbacks tồn tại và KHÔNG có cột đồng bộ', () async {
    final cols = await db.customSelect("PRAGMA table_info('ai_rebalancing_feedbacks')").get();
    final ten = cols.map((r) => r.read<String>('name')).toSet();
    expect(ten, containsAll(['id', 'idaccount', 'donor_budget_id', 'action', 'period_from']));
    expect(ten.intersection({'sync_status', 'sync_error', 'updated_at', 'is_deleted'}), isEmpty,
        reason: 'bảng cục bộ — vắng cột đồng bộ chính là tài liệu sống (quy tắc 9)');
  });
  test('purgeDataForOtherAccounts xoá cả phản hồi của tài khoản khác', () async {
    await db.aiFeedbackDao.ghi(_dong(idaccount: 7));
    await db.aiFeedbackDao.ghi(_dong(idaccount: 8));
    await db.purgeDataForOtherAccounts(7);
    expect((await db.aiFeedbackDao.getAll(8)), isEmpty);
    expect((await db.aiFeedbackDao.getAll(7)), hasLength(1));
  });
}
```
(`_dong` dựng `AiRebalancingFeedbacksCompanion.insert(...)` đủ trường.)

Test quét 15 — `ai_edge_cuc_bo_khong_dong_bo_test.dart`: đọc `lib/core/sync/sync_engine.dart`,
`lib/core/sync/sync_payload_normalizer.dart`, `lib/core/sync/sync_entity_type.dart` (tìm tệp định
nghĩa `SyncEntityType` bằng `grep -rl "enum SyncEntityType" lib/`) và khẳng định **không** chứa
`aiCoDinh`, `ai_co_dinh`, `AiRebalancingFeedback`, `ai_rebalancing_feedbacks`. Cộng một ca đọc
`sync_payload_contract_test.dart` (tệp test!) khẳng định không chứa `ai_co_dinh`.

- [ ] **Step 2: Chạy đỏ** (chưa có cột/bảng).

- [ ] **Step 3: Thêm cột, bảng, DAO, migration**

`categories_table.dart` sau `isLocalOnly`:
```dart
  /// **Cục bộ, KHÔNG đi qua đồng bộ.** Cờ "Cố định — AI không đề xuất cắt" (luật
  /// C2 đặc tả Edge-SLM). Cùng khuôn `wallets.allow_negative` (v23): không cột
  /// server nào tương ứng, `categoryForPush` không đọc nó, nhánh kéo về không
  /// chạm nó. Thêm ở v24 (2026-09-19). Test quét thứ 15 canh nó không lọt vào
  /// đường đồng bộ.
  BoolColumn get aiCoDinh => boolean().withDefault(const Constant(false))();
```
`ai_feedback_table.dart` (docstring theo khuôn `notification_table.dart`: vì sao không có cột đồng
bộ). `ai_feedback_dao.dart`:
```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/ai_feedback_table.dart';
part 'ai_feedback_dao.g.dart';

@DriftAccessor(tables: [AiRebalancingFeedbacks])
class AiFeedbackDao extends DatabaseAccessor<AppDatabase> with _$AiFeedbackDaoMixin {
  AiFeedbackDao(super.db);
  Future<void> ghi(AiRebalancingFeedbacksCompanion e) => into(aiRebalancingFeedbacks).insert(e);
  Future<List<AiRebalancingFeedback>> getAll(int idaccount) =>
      (select(aiRebalancingFeedbacks)..where((t) => t.idaccount.equals(idaccount))).get();
}
```
`app_database.dart`: thêm bảng vào `tables`, DAO vào `daos`, `schemaVersion => 24`, và:
```dart
        if (from < 24) {
          // Edge-SLM P2 (spec 2026-09-19): cờ "Cố định" trên danh mục và bảng
          // phản hồi tái phân bổ — CẢ HAI cục bộ, không đi qua đồng bộ. Không
          // điền dữ liệu hàng cũ: mặc định false = hành vi trước bản này.
          await m.addColumn(categories, categories.aiCoDinh);
          await m.createTable(aiRebalancingFeedbacks);
        }
```
`purgeDataForOtherAccounts`: thêm sau `appNotifications` một khối xoá `aiRebalancingFeedbacks`
theo `idaccount`; sửa hàm xoá theo tài khoản ngay dưới cùng khuôn và docstring "chín bảng" → "mười".

Run: `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Chạy xanh** — `flutter test test/core/database/schema_v24_test.dart test/features/ai_edge/`. Rồi **bản sai có chủ ý** cho test quét 15: thêm tạm `// ai_co_dinh` vào `sync_engine.dart` → test không đỏ (vì bỏ chú thích)? Test quét 15 **không** bỏ dòng chú thích (khác Task 3) — vì một chú thích nhắc tên cột trong sync_engine là dấu hiệu ai đó định đưa nó vào. Thêm tạm dòng `final x = 'ai_co_dinh';` → đỏ → gỡ.

Chạy cả `flutter test test/core/sync/` để chắc hợp đồng payload không đổi.

- [ ] **Step 5: Tài liệu + commit**

`AI_EDGE_FEATURE.md` mục 6; `CLAUDE.md` dòng schema → v24; mục 6 `docs/PROJECT_CONTEXT.md` (bảng
Drift nếu có liệt kê) → kiểm bằng `grep -n "v23" docs/PROJECT_CONTEXT.md CLAUDE.md` và sửa mọi chỗ nói
"schema hiện tại v23".
```bash
git add lib/core/database/ docs/AI_EDGE_FEATURE.md CLAUDE.md docs/PROJECT_CONTEXT.md
git add -f test/core/database/schema_v24_test.dart test/features/ai_edge/ai_edge_cuc_bo_khong_dong_bo_test.dart
git commit -m "feat(db): schema v24 — cột categories.ai_co_dinh và bảng AiRebalancingFeedbacks, cả hai cục bộ"
```

---

### Task 11: Cờ **Cố định** ở màn Thêm/Sửa danh mục

**Files:**
- Modify: `lib/features/category/data/models/category_tree.dart` — `CategoryChildDraft` thêm `final bool aiCoDinh` (mặc định `false`)
- Modify: `lib/features/category/data/repositories/category_management_repository.dart` — `saveChild`: nhánh thêm ghi `aiCoDinh: Value(draft.aiCoDinh)`; nhánh sửa ghi cùng cột (tìm `update`/`write` của nhánh sửa trong hàm ấy)
- Modify: `lib/features/category/presentation/pages/category_add_page.dart` — state `_aiCoDinh`, nạp từ `current.aiCoDinh` trong `_load`, công tắc theo Stitch Task 1 (Prompt 3), `_save` truyền `aiCoDinh: _aiCoDinh`
- Test: `test/features/category/category_ai_co_dinh_test.dart`

**Interfaces:**
- Produces: hàng `categories` mang `aiCoDinh` đúng như công tắc.

- [ ] **Step 1: Test đỏ** — hai ca: (a) DAO/repository: `saveChild(draft aiCoDinh: true)` rồi
`db.categoryDao.getAll(id)` → hàng có `aiCoDinh == true`; sửa lại `false` → `false`. (b) widget:
mở `CategoryAddPage` (dựng như `test/features/category/*_test.dart` hiện có — chép cách tiêm
repository giả), tìm `find.byKey(const ValueKey('cong-tac-ai-co-dinh'))`, tap, bấm Lưu → repository giả
nhận draft `aiCoDinh == true`.

- [ ] **Step 2: Chạy đỏ.** — **Step 3: Viết mã** — công tắc dùng `SwitchListTile` với `key:
const ValueKey('cong-tac-ai-co-dinh')`, tiêu đề `'Cố định — AI không đề xuất cắt'`, phụ đề theo Stitch,
chip `'Chỉ lưu trên máy này'`. Đặt **giữa** khối màu và khối từ khoá đúng Stitch. Ẩn khi
`_isKeywordOnly` (danh mục mặc định chỉ sửa được từ khoá).

- [ ] **Step 4: Chạy xanh; `flutter analyze`.** — **Step 5: Commit** `feat(category): cờ Cố định (cục bộ) — AI không chọn danh mục này làm nguồn bù`.

---

### Task 12: Khối **Nhận xét** + thẻ số liệu (widget dùng chung)

**Files:**
- Create: `lib/features/ai_edge/presentation/widgets/the_so_lieu.dart`
- Create: `lib/features/ai_edge/presentation/widgets/khoi_nhan_xet.dart`
- Test: `test/features/ai_edge/presentation/khoi_nhan_xet_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class TheSoLieu extends StatelessWidget { const TheSoLieu({required List<SoLieu> ds, bool nenToi = false}); }
  /// Nhận GÓI SỐ, tự gọi bộ diễn giải; hiện mẫu câu ngay, thay bằng câu bộ diễn giải khi xong.
  class KhoiNhanXet extends StatefulWidget {
    const KhoiNhanXet({required GoiSo goi, BoDienGiai? boDienGiai, bool nenToi = false, Key? key});
  }
  ```
  `boDienGiai` mặc định `sl<BoDienGiai>()` nếu đã đăng ký, không thì `const MauCau()` (P3 đăng ký bản SLM
  vào GetIt). Nhãn "AI" chỉ khi `NhanXet.tuMoHinh`. Viền trái màu `AppColors.error` khi `canhBao`. Mức
  `thieuDuLieu`: chữ xám, không chip.

- [ ] **Step 1: Test đỏ** (dựng trong `MaterialApp(theme: AppTheme.lightTheme)`, `SizedBox(width: 411)`):
1. Gói giả bình thường → tìm thấy câu và **từng** `chuoi` của số liệu; **không** thấy `'AI'`.
2. `boDienGiai` giả trả `tuMoHinh: true` sau `Future.delayed` → sau `pump` đầu thấy câu mẫu, sau
   `pumpAndSettle` thấy câu mô hình và nhãn `'AI'`.
3. `thieuDuLieu` → thấy câu, `find.byType(TheSoLieu)` **findsNothing**.
4. Câu dài nhất (200 ký tự) ở 411dp → `tester.takeException()` **null** (không tràn).
5. Bộ diễn giải ném lỗi → vẫn hiện câu mẫu (nuốt lỗi, `debugPrint`).

- [ ] **Step 2–4:** đỏ → mã (theo màn Stitch Task 1; `Wrap` chip cho thẻ số liệu, mỗi chip
`'$nhan $chuoi'`) → xanh. Chạy `flutter analyze`.

- [ ] **Step 5: Commit** `feat(ai-edge): khối Nhận xét + thẻ số liệu dùng chung`.

---

### Task 13: Nguồn dữ liệu Tầng 2 + `BudgetCubit` sinh kế hoạch

**Files:**
- Create: `lib/features/budget/data/tai_phan_bo_nguon.dart` — ⚠️ đặt ở **budget**, không ở `ai_edge/`: nó đọc bảng giao dịch để tính thu nhập 3 tháng, mà test quét 14 cấm `ai_edge/` chạm `transactionDao`. Nó là *nguồn dữ liệu của ngân sách*; lớp AI chỉ nhận `DuLieuTaiPhanBo`
- Modify: `lib/features/budget/presentation/bloc/budget_state.dart` — `BudgetLoaded` thêm `final KeHoachTaiPhanBo? keHoach` (mặc định `null`, vào `props`)
- Modify: `lib/features/budget/presentation/bloc/budget_cubit.dart` — nhận `TaiPhanBoNguon? taiPhanBoNguon`; `_loadedFrom` thành `Future`, có bộ đếm lượt chống emit lỗi thứ tự
- Modify: `lib/core/di/injection_container.dart` — đăng ký `TaiPhanBoNguon` và truyền vào `BudgetCubit`
- Test: `test/features/ai_edge/data/tai_phan_bo_nguon_test.dart`, `test/features/budget/budget_cubit_ke_hoach_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class DuLieuTaiPhanBo { final Set<String> coDinh; final double thuNhap3Thang; final Map<String, double?> tb3ThangTheoNganSach; final List<PhanHoiCu> phanHoi; }
  abstract class TaiPhanBoNguon { Future<DuLieuTaiPhanBo> nap(int idaccount, List<BudgetView> dangChay, DateTime now); }
  class TaiPhanBoNguonImpl implements TaiPhanBoNguon { TaiPhanBoNguonImpl({required AppDatabase db, required BudgetRepository budgets}); }
  ```
  - `coDinh` = `{c.id for c in db.categoryDao.getAll(idaccount) if c.aiCoDinh}`.
  - `tb3ThangTheoNganSach[b.id]` = `budgets.suggestAmount(idaccount, b.categoryId!, now: now)` (đã là
    TB 3 tháng làm tròn lên 10k — ghi chú: dùng lại một định nghĩa, chấp nhận làm tròn).
  - `thuNhap3Thang`: dựng `List<KhoanThuChi>` từ `db.transactionDao.getAll` + `db.categoryDao.getBangTraTen`
    **đúng khối** `khoan = [...]` của `analytics_repository_impl.dart:183–200` (chép nguyên, ghi chú
    nguồn), rồi `chuoiVayNo(khoan, ky: Ky.thang(now.year, now.month), soKy: 4)` lấy 3 phần tử đầu
    (ba tháng liền trước) và `thuNhapCua(tong: tongThuChi(khoan, from: k.ky.from, to: k.ky.to), vayNo: k)`
    trung bình (tiền đi vay / thu nợ **không** tính — đúng `thuNhapCua`).

- [ ] **Step 1: Test đỏ** — nguồn: CSDL trong bộ nhớ có 1 danh mục `aiCoDinh` → `coDinh` chứa id; 3 tháng
giao dịch thu 10tr mỗi tháng + 1 khoản đi vay 5tr → `thuNhap3Thang == 10_000_000` (vay **không** tính —
đúng bài học A8 #8). Cubit: nguồn giả trả dữ liệu có thâm hụt → `BudgetLoaded.keHoach != null`; nguồn
`null` → `keHoach == null` và mọi test cũ của cubit **không đổi**.

- [ ] **Step 2–4:** đỏ → mã → xanh; chạy **cả** `flutter test test/features/budget/` để chắc không vỡ ca cũ.

- [ ] **Step 5: Commit** `feat(budget): BudgetCubit sinh kế hoạch tái phân bổ từ nguồn dữ liệu Tầng 2`.

---

### Task 14: Gắn khối Nhận xét vào bốn màn; đóng A6

**Files:**
- Modify: `lib/features/budget/presentation/pages/budget_tabs_view.dart` — `_ActiveTab`: sau `_OverviewCard` chèn `KhoiNhanXet(goi: GoiSoNganSach.tu(state.active, now: now ?? DateTime.now(), keHoach: state.keHoach))` và thẻ kế hoạch (Task 15) 
- Modify: `lib/features/analytics/presentation/pages/analytics_page.dart` — trong widget chứa hai `_TheTong` (dòng ~437–465): sau `_TheConLai(tk: tk)` chèn `const SizedBox(height: 16), KhoiNhanXet(goi: GoiSoPhanTich.tu(tk))`
- Modify: `lib/features/goal/presentation/pages/goal_page.dart` — trong `_tabDangTheoDuoi` trên đầu danh sách: `KhoiNhanXet(goi: GoiSoMucTieu.tu(goals, now: DateTime.now()))`
- Modify: `lib/features/home/presentation/pages/home_page.dart` — **xoá** `_buildInsightCard`, thay chỗ gọi bằng `KhoiNhanXet(goi: GoiSoTrangChu.tu(thu: monthlyIncome, chi: monthlyExpense, tongSoDu: <biến tổng số dư đang truyền cho _buildAssetCard>, nganSach: <BudgetView của _buildBudgetSection>, now: now), nenToi: true)` — cần đưa khối vào **trong** `StreamBuilder` giao dịch để có `monthlyIncome`; ngân sách lấy bằng một `StreamBuilder<List<BudgetView>>` bọc thêm (cùng stream `_buildBudgetSection` đang dùng)
- Test: `test/features/budget/budget_khoi_nhan_xet_test.dart`, `test/features/analytics/analytics_khoi_nhan_xet_test.dart`, `test/features/goal/goal_khoi_nhan_xet_test.dart`, `test/features/home/home_khoi_nhan_xet_test.dart`; sửa `test/features/home/trang_chu_gon_test.dart` nếu nó tìm chuỗi "Insight AI"

**Interfaces:**
- Consumes: bốn `GoiSo*.tu(...)`, `KhoiNhanXet`.

- [ ] **Step 1: Test đỏ** — mỗi trang một ca: dựng trang như test hiện có của trang ấy (chép khuôn
`budget_page_cold_start_test.dart`, `analytics_page_test.dart` helper `_tk` + `initializeDateFormatting`,
goal/home test), khẳng định `find.byType(KhoiNhanXet)` **findsOneWidget** và câu mẫu đúng số của
state giả. Trang chủ: thêm ca `find.text('Insight AI')` **findsNothing** và không còn chuỗi `'Thêm thêm'`.

- [ ] **Step 2–4:** đỏ → sửa bốn trang → xanh. Chạy toàn bộ `flutter test test/features/{budget,analytics,goal,home}/`.

- [ ] **Step 5: Máy ảo** — build APK, cài, chụp bốn màn; đếm pixel vàng; mở ảnh xem câu dài có bị cắt.
Ghi tên ảnh vào `AI_EDGE_FEATURE.md` mục 7.

- [ ] **Step 6: Commit** `feat(ai-edge): khối Nhận xét ở Ngân sách, Phân tích, Mục tiêu, Trang chủ — đóng A6`.
Cập nhật `CLIENT_APP_KNOWN_GAPS.md` A6 → đóng.

---

### Task 15: Thẻ + sheet **kế hoạch tái phân bổ** — tick, sửa số, Áp dụng, ghi phản hồi

**Files:**
- Create: `lib/features/ai_edge/presentation/widgets/the_ke_hoach.dart`
- Create: `lib/features/ai_edge/presentation/pages/ke_hoach_tai_phan_bo_sheet.dart`
- Create: `lib/features/ai_edge/domain/ap_dung_ke_hoach.dart` — hàm thuần: `List<(BudgetEntity, double)> hanMucMoi(KeHoachTaiPhanBo kh, Map<String, double> soTienDaChon)` trả hạn mức mới của từng bên (donor: `amount − x`; thiếu: `amount + Σx`), và `List<AiRebalancingFeedbacksCompanion> phanHoiTu(kh, soTienDaChon, {required int idaccount, required DateTime now, required bool boQua})`
- Modify: `budget_tabs_view.dart` — `_ActiveTab` hiện `TheKeHoach` khi `state.keHoach != null`, chạm mở sheet
- Test: `test/features/ai_edge/domain/ap_dung_ke_hoach_test.dart`, `test/features/ai_edge/presentation/ke_hoach_sheet_test.dart`

**Interfaces:**
- Consumes: `KeHoachTaiPhanBo`, `BudgetRepository.updateBudget`, `AiFeedbackDao.ghi`.
- Produces: sheet `showModalBottomSheet` với `isScrollControlled: true`, chiều cao **cố định** 70 %
  (bài học sheet chọn phạm vi). Mỗi dòng: `CheckboxListTile` + `TextField` số tiền có
  `GioiHanSoChuSo(kSoChuSoToiDaSoTien)` và `formatSoThoi`; tổng bù cập nhật theo tick; nút **Áp dụng**
  (tắt khi không dòng nào tick) và **Bỏ qua**.

- [ ] **Step 1: Test đỏ**
Thuần: `hanMucMoi` — kế hoạch 2 dòng (500k, 100k), chọn cả hai → donor1 `amount−500k`, donor2
`amount−100k`, thiếu `amount+600k`; chọn một dòng sửa 300k → tương ứng; **tổng hạn mức không đổi**
(khẳng định Σ trước = Σ sau). `phanHoiTu`: tick giữ số → `accepted`; tick đổi số → `modified`
(`actualAmount` = số mới); không tick → `rejected`; `boQua: true` → mọi dòng `rejected`.
Widget: mở sheet với kế hoạch 2 dòng; bỏ tick dòng 2 → tổng đổi; sửa số dòng 1 thành `300000` → tổng;
bấm Áp dụng → repository giả nhận **hai** lượt `updateBudget` (donor1 và thiếu) với hạn mức đúng, DAO
giả nhận 2 hàng (`modified`, `rejected`); bấm Bỏ qua → 0 lượt `updateBudget`, 2 hàng `rejected`; kéo
sheet tắt (`tester.drag`) → 0 hàng. Ô tiền có `GioiHanSoChuSo` (test quét thứ tám bắt tên
controller — đặt tên `_amountControllers`, thêm tên ấy vào danh sách `tenOTien` của
`o_nhap_tien_co_tran_test.dart` nếu test không tự nhận).

- [ ] **Step 2–4:** đỏ → mã → xanh. `flutter analyze`.

- [ ] **Step 5: Máy ảo** — tạo dữ liệu thâm hụt thật trên máy ảo (ba ngân sách, một vượt nhịp), mở trang
Ngân sách: thẻ hiện, sheet mở, tick/sửa/Áp dụng → hạn mức đổi trên thẻ ngân sách, và **đồng bộ** đẩy
được (xem log `[SyncEngine]`, hoặc kiểm PostgreSQL bằng skill `chay-app` đọc bảng `budget`). Chụp ảnh.

- [ ] **Step 6: Commit** `feat(ai-edge): kế hoạch tái phân bổ chờ duyệt — tick từng dòng, áp dụng qua updateBudget, ghi phản hồi`.
Ghi bẫy vào `AI_EDGE_FEATURE.md` mục 4 (ví dụ: sheet cao cố định; vuốt tắt không ghi).

---

### Task 16: Thông báo `budgetRebalance` — một lần mỗi tuần

**Files:**
- Modify: `lib/core/notification/notification_rules.dart` — enum thêm `budgetRebalance`; `NotificationRuleInput` thêm `final KeHoachTaiPhanBo? keHoachTaiPhanBo` (mặc định `null`); luật `_rebalanceCandidates`; thêm vào `buildNotificationCandidates`
- Modify: `lib/core/notification/prefs/notification_prefs.dart` — hai `switch` không `default` (dòng ~15 và ~85): `budgetRebalance` vào nhóm `budget`, không phải "bỏ qua công tắc"
- Modify: `lib/core/notification/notification_scanner.dart` — hook `Future<KeHoachTaiPhanBo?> Function(int idaccount, DateTime now)? loadKeHoach` (cùng khuôn `loadChiLon`), truyền vào input
- Modify: `lib/core/di/injection_container.dart` — nối `loadKeHoach` bằng `TaiPhanBoNguon` + `taiPhanBoCua` trên `budgetRepository.getBudgets`
- Modify: `lib/core/database/tables/notification_table.dart` docstring `kind` (liệt kê loại mới), `docs/NOTIFICATION_FEATURE.md` (bảng mục 3 + mục **5g**)
- Test: `test/core/notification/notification_rules_rebalance_test.dart`

**Interfaces:**
- Produces: `NotificationCandidate(kind: budgetRebalance, dedupeKey: 'budgetRebalance:${khoaTuan(now)}', title: 'Đề xuất cân đối ngân sách', body: '<tên> dự kiến vượt hạn mức. Xem kế hoạch bớt từ ngân sách khác.' (không nêu số), severity: warning, subjectType: 'budget', subjectId: thieu.budget.id, deeplink: '/budget', createdAt: now)`.

- [ ] **Step 1: Test đỏ**: `keHoachTaiPhanBo == null` → không ứng viên; có → đúng một ứng viên với khoá
tuần ISO (`khoaTuan`); hai lượt quét cùng tuần khác ngày → **cùng** `dedupeKey`; sang tuần → khác;
`body` **không chứa chữ số**; `nhomCua(budgetRebalance) == NotificationGroup.budget`; `silenceBefore`
sau `now` → bị lọc.

- [ ] **Step 2–4:** đỏ → mã → xanh. Chạy `flutter test test/core/notification/` (toàn bộ, vì enum đổi).

- [ ] **Step 5: Tài liệu + commit** — `NOTIFICATION_FEATURE.md`: dòng mới ở bảng mục 3 (hàng thứ 18,
loại thứ 19 của enum — **đếm lại bằng máy** `grep -c` trên enum), mục **5g** ghi: một/tuần, không số,
khoá tuần ISO, nguồn là `TaiPhanBoNguon` dùng chung với trang Ngân sách (một định nghĩa).
```bash
git add lib/core/notification/ lib/core/di/injection_container.dart lib/core/database/tables/notification_table.dart docs/NOTIFICATION_FEATURE.md
git add -f test/core/notification/notification_rules_rebalance_test.dart
git commit -m "feat(notification): budgetRebalance — đề xuất cân đối ngân sách, tối đa một lần mỗi tuần"
```

---

### Task 17: Nghiệm thu toàn bộ, tài liệu bàn giao P2

**Files:**
- Modify: `docs/AI_EDGE_FEATURE.md` (mục 2, 4, 7 hoàn chỉnh; trạng thái "P2 xong")
- Modify: `docs/PROJECT_CONTEXT.md` mục 14 — khối `### 🤖 AI Edge-SLM — P2 tầng Edge + mẫu câu (2026-09-xx)`
- Modify: `CLAUDE.md` — mốc test/analyze mới, câu "schema v24", hàng "Đụng vào AI Edge-SLM" cập nhật nếu lệch
- Modify: `docs/CLIENT_APP_KNOWN_GAPS.md` — A6 đóng; bảng tóm tắt khớp thân

- [ ] **Step 1: `flutter analyze`** — mức nền (ghi con số). **Step 2: `flutter test` toàn bộ** nền, log,
`--timeout 60s` — tất cả pass; đếm bằng máy số ca mới (`grep -c "test(" test/features/ai_edge -r`).

- [ ] **Step 3: Máy ảo lần cuối** — bốn màn + sheet + màn sửa danh mục + trung tâm thông báo (có thẻ
`Đề xuất cân đối` sau khi tạo thâm hụt và chờ lượt quét, hoặc gọi quét bằng mở lại app). Đếm pixel
vàng = 0. Ảnh vào scratchpad, tên ghi vào tài liệu.

- [ ] **Step 4: Lượt soát tài liệu rộng** — `grep -rn "Insight AI\|v23\|ai_co_dinh\|budgetRebalance\|AiRebalancing" docs/ CLAUDE.md` và mở **từng** tệp có kết quả để chắc không tệp nào còn tả trạng thái cũ (memory `cap-nhat-tai-lieu-va-commit-sau-moi-hang-muc`).

- [ ] **Step 5: Commit** `docs(ai-edge): P2 xong — tường thuật, con số đếm lại bằng máy`. Không push.

Bước tiếp: **P1 spike** (khi cắm máy) → viết kế hoạch **P3**.

---

## Nhật ký thi công (điền khi làm)

**P2 XONG ngày 2026-09-20** — trọn 17 task. Tài liệu tính năng:
`docs/AI_EDGE_FEATURE.md`; tường thuật ở mục 14 `docs/PROJECT_CONTEXT.md`.

| Task | Commit | Ghi chú |
|---|---|---|
| 0 | `ee9256b` | khung `AI_EDGE_FEATURE.md` + tài liệu CAN-LAM xin sửa đặc tả |
| 1 | `762733e` | ba màn Stitch, người dùng nghiệm thu cùng ngày |
| 2 | `1636e62` | kiểu lõi: `SoLieu`, `GoiSo`, `NhanXet`, `BoDienGiai` |
| 3 | `00867ee` | **test quét `lib/` thứ 14** — lớp AI không tính |
| 4 | `32951c2` | bộ kiểm số |
| 5 | `9015d9f` | gói số + mẫu câu Ngân sách |
| 6 | `d59354f` | gói số Phân tích; bộ kiểm số bắt **dấu âm** |
| 7 | `0ffe31a` | gói số Mục tiêu |
| 8 | `2ca9c32` | gói số Trang chủ |
| 9 | `0dc0ba5` | Tầng 2 — thâm hụt, nguồn bù, kế hoạch |
| 10 | `cedd4f9`, `e9267b9` | schema **v24** (hai thứ cục bộ) + fixture sáu test migration |
| 11 | `88586da` | cờ **Cố định** ở màn Thêm/Sửa danh mục |
| 12 | `b8b2b45` | khối Nhận xét + thẻ số liệu dùng chung |
| 13 | `8cf4255` | `BudgetCubit` sinh kế hoạch từ `TaiPhanBoNguon` |
| 14 | `817ee2f` | khối Nhận xét gắn vào **bốn** màn — đóng **A6** |
| 15 | `30547d6` | thẻ + sheet kế hoạch chờ duyệt; nghiệm thu tới PostgreSQL |
| 16 | `e49c301` | thông báo `budgetRebalance` — loại thứ **19** của enum, mục **5g** `NOTIFICATION_FEATURE.md` |
| 17 | *(commit này)* | nghiệm thu tổng sáu màn + tài liệu bàn giao; mục **7.4** |

**Đo bằng máy 2026-09-20:** 20 commit kể từ P0 (`03fe03a`), **45** tệp `lib/` đổi
(+3615 / −106), `lib/features/ai_edge/` **16** tệp, `test/features/ai_edge/`
**14** tệp / **94** ca. Trọn bộ **3106/3106 pass, 1 skip**; `flutter analyze`
**26 issue, 0 error** (mức nền). Schema **v24**, **payload không đổi**.

**Không mở lỗ hổng G nào trong cả P2.**

**Bước tiếp:** P1 spike (khi người dùng cắm máy Snapdragon 8 Gen 3) → kế hoạch P3.
