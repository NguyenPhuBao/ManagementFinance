# AI — việc tiếp theo, chi tiết đủ để bắt tay làm

> **Cho người thi công:** tệp này gom **toàn bộ** việc AI còn mở, sắp theo thứ tự, và ghi
> đủ tên tệp / tên hàm / chữ ký để không phải khảo sát lại. Chặng 1 chi tiết nhất vì nó
> làm được ngay; các chặng sau phác thảo dần.
>
> **Nguồn:** `docs/AI_EDGE_FEATURE.md` mục **10** (bản chất mảng AI, mười tiêu chí, bốn
> tầng chiều ghi) và mục **11** (bản đồ khảo sát). Đọc hai mục ấy **trước** khi bắt đầu.

**Viết:** 2026-09-21. **Trạng thái:** chưa bắt đầu việc nào.

---

## Luật chung cho mọi việc dưới đây

Trích từ mục 10.4 và 10.5 `AI_EDGE_FEATURE.md` — áp cho **tất cả**, không nhắc lại ở
từng việc:

1. **Lớp `ai_edge/` không tính.** Mọi số từ hàm domain đã có. Test quét thứ 14 cấm
   `'thu'`/`'chi'`/`'transfer'`/`walletId`/`transactionDao`/`.type ==` trong thư mục ấy.
2. **Chạy được khi không có mô hình.** Mẫu câu là bản *chính*, mô hình là bản *nâng cấp*.
3. **Rơi về bản thấp hơn im lặng** — không toast, không dialog.
4. **Mỗi luật học có ngưỡng mẫu tối thiểu; dưới ngưỡng thì im**, rồi tự bật khi đủ.
5. **Chiều ghi luôn xác nhận**, và form xác nhận dựng từ **tham số**, không từ câu mô
   hình viết. 🛑 Không hàm nào bật `auto_pay` / trích tự động / **xoá** bất cứ gì.
6. **TDD**: test đỏ trước; ca xanh ngay từ đầu **phải thử bản sai có chủ ý**.
7. Trước khi báo xong: `flutter test` **trọn bộ** (mức nền **3106/3106, 1 skip**) và
   `flutter analyze` (**26 issue, 0 error**). Đụng giao diện → **nghiệm thu máy ảo 411dp**.
8. Tệp test mới phải `git add -f` (`.gitignore` có `test/`).

---

# CHẶNG 1 — Năm việc làm được ngay

Không cần brainstorm, không cần spec, không chờ dữ liệu. Mỗi việc một commit.

## 1.1 Neo ba ngưỡng tái phân bổ theo thu nhập

**Vấn đề:** luật tái phân bổ có sáu ngưỡng, chỉ **một** cái neo theo người dùng. Người
thu nhập 5 triệu và người 50 triệu dùng chung ngưỡng thâm hụt **50.000 đ** — với người
thứ hai, app dựng cả một kế hoạch cắt giảm cho tiền lẻ.

**Tệp:** `lib/features/ai_edge/domain/tai_phan_bo.dart`
**Test:** `test/features/ai_edge/domain/tai_phan_bo_test.dart` (đã có, thêm ca)

**Hiện trạng:**

```dart
const double kNguongThamHutTiLe    = 0.10;      // tỉ lệ  → GIỮ NGUYÊN
const double kNguongThamHutTuyetDoi = 50000;    // tuyệt đối → NEO
const double kDuDiaToiThieu        = 100000;    // tuyệt đối → NEO
const double kTranCat              = 0.25;      // tỉ lệ  → GIỮ NGUYÊN
const double kTranCatDaBiCat       = 0.15;      // tỉ lệ  → GIỮ NGUYÊN
const int    kBuocLamTron          = 10000;     // tuyệt đối → NEO

double nguongCoNghia(double thuNhap3Thang) {    // ← mẫu đã đúng
  final motPhanTram = thuNhap3Thang * 0.01;
  return motPhanTram > 50000 ? motPhanTram : 50000;
}
```

**Làm:** ba hàm mới cùng khuôn `nguongCoNghia`, nhận `thuNhap3Thang`, trả về `max(tỉ lệ ×
thu nhập, hằng cũ)` — **hằng cũ thành sàn**, nên tài khoản chưa có thu nhập giữ nguyên
hành vi hôm nay. `taiPhanBoCua` đã nhận `thuNhap3Thang`, không đổi chữ ký.

⚠️ **Giữ nguyên hai hằng tỉ lệ.** Chúng vốn không phụ thuộc quy mô thu nhập — neo chúng
là làm hỏng một thứ đang đúng.

⚠️ `kBuocLamTron` dùng ở **hai** chỗ: `lamTron10k()` và phép "làm tròn LÊN" trong vòng
chọn nguồn bù. Đổi một chỗ mà quên chỗ kia thì tổng cắt lệch vài nghìn — im lặng.

**Ca test bắt buộc:** cùng một trạng thái ngân sách, hai mức `thuNhap3Thang` (5 triệu và
50 triệu) → hai kết quả khác nhau; `thuNhap3Thang = 0` → **y hệt hành vi hôm nay** (sàn).

**Xong khi:** `flutter test test/features/ai_edge/` xanh, ca mới đỏ với bản sai (bỏ phép
neo). **Tài liệu:** mục 11.5 (1) — đổi ⭐ thành ✅ kèm ngày.

## 1.2 Ví chọn sẵn theo danh mục

**Vấn đề:** `chonViChonSan` chọn **ví mặc định**, giống nhau mọi lúc — không theo danh
mục, không theo giờ. Thói quen thật có mẫu (ăn uống → tiền mặt, mua sắm → ví ngân hàng).

**Tệp:**
- `lib/features/transaction/domain/vi_chon_san.dart` — thêm tham số tuỳ chọn
- chỗ gọi ở `add_transaction_page.dart`
- **Test:** `test/features/transaction/vi_chon_san_test.dart` (đã có)

**Chữ ký hiện tại:**

```dart
ViChonSan<T> chonViChonSan<T>(
  List<T> danhSach, {
  required bool Function(T) laMacDinh,
})
```

**Làm:** thêm `T? Function(String danhMucId)? viHayDung` (mặc định `null` → hành vi cũ
nguyên vẹn). Phép tra là **đếm tần suất** trên lịch sử giao dịch của danh mục ấy, đặt ở
`transaction/data/` (không ở `ai_edge/` — nó đọc bảng giao dịch, test quét 14 cấm).

⚠️ **Ngưỡng mẫu tối thiểu** (đề nghị **5** giao dịch cùng danh mục) và **tỉ lệ áp đảo**
(đề nghị ≥ 60 %). Dưới ngưỡng → trả `null` → rơi về ví mặc định. Không có ngưỡng thì một
giao dịch lẻ cũng đổi ví chọn sẵn, và người dùng thấy ví nhảy lung tung.

**Ca test bắt buộc:** 9/10 giao dịch Ăn uống dùng ví Tiền mặt → chọn Tiền mặt; 3 giao
dịch → dưới ngưỡng, giữ ví mặc định; 5 giao dịch chia 3–2 → dưới tỉ lệ áp đảo, giữ mặc
định; `viHayDung == null` → **y hệt hành vi hôm nay**.

## 1.3 Gói số cho HOÁ ĐƠN ⭐ (tệp mẫu cho 1.4 và 1.5)

**Vấn đề:** `bill` có **27 tệp, 10 hàm domain** mà AI **chưa chạm gì** — không một gói số
nào cho hoá đơn.

**Tệp mới:** `lib/features/ai_edge/domain/goi_so_hoa_don.dart`
**Test mới:** `test/features/ai_edge/domain/goi_so_hoa_don_test.dart`
**Mẫu chép theo:** `goi_so_ngan_sach.dart` (`class GoiSoNganSach extends GoiSo`)

**`GoiSo` đòi bốn thứ:** `String get man` · `List<SoLieu> get soLieu` ·
`bool get thieuDuLieu` · `NhanXet mauCau()`.

**Số lấy từ (đã tính sẵn, đừng tính lại):**

| Hàm | Chữ ký | Cho gì |
|---|---|---|
| `summarizeBills` | `BillSummary summarizeBills(List<Bill> bills, DateTime now)` | số liệu thẻ tổng |
| `billDisplayStatusOf` | → `BillDisplayStatus` (**năm** trạng thái) | đếm quá hạn / sắp tới hạn |
| `kyKeTiepCua` | `KyKeTiep kyKeTiepCua(Bill current)` | kỳ kế tiếp |
| `bill_an_han.dart` | — | ân hạn |

⚠️ **Đọc `docs/bill/BILL_DOCUMENTATION.md` mục 6.7 trước**: câu "đã trả chưa" **tách làm
hai** (*còn phải trả* vs *đã có khoản chi*) và có **một** định nghĩa duy nhất ở
`bill_pay_status.dart`. Đừng viết vị từ thứ hai.

⚠️ **Nhánh thiếu dữ liệu là một câu THẬT**, không ẩn khối (mục 1 `AI_EDGE_FEATURE.md`).

**Ca test bắt buộc:** *"mẫu câu tự qua bộ kiểm số ở mọi nhánh"* — **mọi** gói số đều phải
có ca này (bẫy 4.1); thiếu nó thì P3 sẽ rơi về một câu mà `kiemSo` cũng chặn.

## 1.4 Gói số cho MỤC TIÊU (mở rộng)

⭐ **Ba dòng riêng trong bảng mục 11 — *"vì sao trễ"*, *"ví thiếu tiền trích"*, *"dự báo
ngày đạt"* — là MỘT việc.** `goal` có 14 hàm domain mà gói số hiện tại mới dùng 1.

**Tệp:** `lib/features/ai_edge/domain/goi_so_muc_tieu.dart` (**đã có**, mở rộng)

**Ba hàm đã tính sẵn và đang im lặng:**

```dart
DateTime? duBaoHoanThanh(GoalEntity goal, DateTime now)  // goal_forecast.dart
                                  // dự báo theo NHỊP TÍCH LUỸ THẬT, không phải kế hoạch
String? canhBaoViKhongDu(...)     // goal_wallet_shortfall.dart
                                  // ví tích luỹ không đủ cho các mục tiêu trỏ vào nó
ThongKeMucTieu? thongKeMucTieu(...) // goal_stats.dart — số lần nạp, TB mỗi lần
String tenDonViKy(String? chuKy)    // goal_stats.dart — nhãn đơn vị kỳ
```

⚠️ `duBaoHoanThanh` và `canhBaoViKhongDu` trả **nullable** — `null` nghĩa là *chưa đủ căn
cứ*, và khi ấy câu **không được nhắc tới** nó. Đừng `?? 0` hay `?? DateTime.now()`: đó
đúng là lỗi mà mục 3.30 `ANALYTICS_FEATURE.md` đã chặn (`thayDoiTaiSan` trả `null` thay
vì in một khoản tăng bịa).

## 1.5 Gói số cho VÍ

**Việc:** *"giải thích vì sao số dư lệch"*.
**Tệp mới:** `lib/features/ai_edge/domain/goi_so_vi.dart`

**Số lấy từ:** `wallet/domain/dieu_chinh_so_du.dart` — **nơi duy nhất** định nghĩa phép
tính khoản bù, khuôn ghi chú, và phép nhận dạng ngược; và `vi_tinh_vao_tong.dart`.

⚠️ Phép nhận dạng khoản điều chỉnh đòi **cặp** điều kiện (không danh mục **và** tiền tố
`Điều chỉnh số dư`) — riêng chân danh mục **không đủ**: 17 hàng trên server đang trống
danh mục thật.

⚠️ **G37**: `wallets.balance` là *cache của một công thức* (`TransactionDao.tongTheoVi`),
không phải dữ liệu gốc. Gói số đọc `balance` thì đọc qua `viTinhVaoTong` như mọi chỗ khác.

---

# CHẶNG 2 — Function calling, bắt đầu từ việc AN TOÀN NHẤT

## 2.1 ⭐ Tìm kiếm bằng câu — *"tháng trước tôi tiêu gì trên 500k"*

**Vì sao đây là việc đầu của hạ tầng C, không phải nhập bằng câu:**

- Chiều **đọc** — sai thì kết quả trống, người dùng thấy ngay; **không ghi gì**.
- Đầu ra mô hình là một **bộ lọc**, kiểm được bằng schema chứ không cần `kiemSo`.
- Nó cho **phép đo tỉ lệ chọn đúng hàm** mà 2.2 và 2.3 cần trước khi mở chiều ghi.

**Nó lấp một lỗ hổng thật.** `TransactionFilter` hiện chỉ có:

```dart
TransactionTypeFilter type;  String? walletId;  String? categoryId;  String query;
```

→ **không lọc được theo khoảng tiền, cũng không theo khoảng ngày.** Phần mở rộng bộ lọc
là việc có ích **kể cả khi không có AI**.

**Tệp:** `transaction/domain/transaction_filter.dart` (thêm trường + `applyTransactionFilter`) ·
`transaction/presentation/widgets/transaction_filter_bar.dart` · một hàm khai `Tool` cho
function calling.

**Phép đo phải ghi lại:** 20 câu lệnh mẫu → đếm bao nhiêu lần **chọn đúng hàm** và
**đúng tham số**. Con số ấy quyết định có mở 2.2/2.3 hay không, và là một bảng cho báo cáo.

## 2.2 Nhập giao dịch bằng câu *(ghi tầng 3)*

Bản **luật** chạy trước (regex số tiền + ngày + `CategorySuggestionEngine`) — tức thì,
**không cần mô hình**; mô hình chỉ để hiểu câu lạ (*"làm tô phở hết bốn chục"*).

⚠️ `kiemSo` **không dùng được** ở chiều ghi (không có gói số để đối chiếu).
⚠️ Xác nhận **từng cái**, hiện rõ số đã hiểu — `40k` là 40.000 hay 40.000.000?
⚠️ **Chốt bảng quy đổi `k` / `củ` / `chai` với người dùng trước khi viết mã.**
**Cần brainstorm + spec.**

## 2.3 Tạo hoá đơn · mục tiêu · ngân sách bằng lệnh *(ghi tầng 2)*

⭐ Ba dòng trong bảng mục 11, nhưng là **một việc**: thêm ba hàm tầng 2 vào bộ hàm của
2.1–2.2. Sai thì nhiễu chứ không mất tiền → xác nhận **một hộp thoại có số cụ thể**.

⚠️ **Form hiện LỆNH, không hiện LỜI** — mô hình có thể viết *"tạo hoá đơn 500 nghìn"*
trong khi tham số thật là `5000000`.
⚠️ **Một lệnh, một bước** — không cho chạy chuỗi *"tạo ngân sách rồi chuyển tiền vào"*.
🛑 Không hàm bật `auto_pay`, trích tự động, hay xoá.

---

# CHẶNG 3 — Phân loại tự động

## 3.1 Gắn danh mục hàng loạt

Vá **38 %** dữ liệu mù (15/39 giao dịch, đo 2026-09-20). Chiều ghi **tầng 1** → duyệt
**cả lô**, một màn. App đã có `CategorySuggestionEngine` làm **bản đối chứng** — so hai
bên là phép đo sạch cho báo cáo. **Cần brainstorm + spec.**

## 3.2 Học từ khoá cho danh mục

AI quan sát *ghi chú → danh mục đã chọn* rồi tự thêm `keyword`. **AI cải thiện chính hệ
luật** thay vì thay nó.

## 3.3 Essentiality học từ phản hồi

Việc **duy nhất** trong bốn việc mục 11.4 dùng được **dữ liệu đã có**
(`AiRebalancingFeedbacks`). Thay `essentiality = 0,5` cứng. ⚠️ Giữ 0,5 tới khi đủ mẫu.

---

# CHẶNG 4 — P3

⚠️ **Chốt lối A hay B trước khi bắt đầu Task 7** (Task 1–6 giống nhau ở cả hai lối):

- **A** (kế hoạch đang viết theo): mô hình viết câu ở **cả bốn khối Nhận xét** + Trợ lý AI.
- **B** (khuyến nghị): giữ mẫu câu ở bốn khối, mô hình **chỉ** phục vụ Trợ lý AI. Đổi sang
  B = **không đăng ký `BoDienGiai` vào DI**; không sửa màn nào.

Task 0 cần người dùng nghiệm thu màn Stitch.
**Kế hoạch:** `2026-09-20-ai-edge-p3-cam-slm.md`, 10 task.

---

# CHẶNG 5 — Phần còn lại

| Việc | Điều kiện | Ghi chú |
|---|---|---|
| **Dư nợ theo người** | không | ⭐ **mở lại A8 #9 đã bỏ** vì thiếu mô hình khoản vay — tên người nằm trong **ghi chú**, thứ hệ luật không đọc nổi. Chiều đọc, rủi ro thấp |
| **Giải thích 9 biểu đồ** | không | 9 khối × một hàm gói số. ⚠️ **đừng dùng vision** (11.1); gói phải **tính sẵn** kỳ cao/thấp nhất, % thay đổi, xu hướng — nếu không mô hình tự tính và `kiemSo` chặn |
| **Đề xuất tạo ngân sách** | không | `suggestAmount` đã có sẵn con số |
| **Nhịp chi theo ngày** + **ngưỡng 70/90 %** | 3 kỳ | ⭐ **làm chung** — một phép học, hai chỗ dùng (`budget_visuals.dart`: `_cautionAt`, `_criticalAt`) |
| **Tự đề xuất cờ Cố định** | vài lượt từ chối | dùng chung dữ liệu với 3.3 |
| **Phát hiện hoá đơn định kỳ** | ~3 kỳ lặp | ⚠️ tuyệt đối **không tự bật `auto_pay`** |
| **Dự đoán số tiền hoá đơn kỳ tới** | 3 kỳ | hồi quy nhỏ, không cần LLM |
| **Bất thường theo danh mục** | 20–30 giao dịch/danh mục | xa nhất; danh mục đông nhất hiện có **6** |
| **Chọn khối Phân tích đáng xem** | không (mức rẻ) | soát khối nào chưa tự ẩn khi rỗng |
| **Tần suất thông báo theo phản ứng** | dữ liệu phản ứng | ⚠️ **không đụng `dedupeKey`**; giữ nguyên `luonBao` |
| **Đo NPU** · **vision/audio** | cắm máy thật | ~15 phút mỗi cái; spike còn ở `D:/flowmoney-spike`, mô hình ở `D:/flowmoney-models` |
| **Tám việc UX hoãn** | **E6** chờ chốt | `2026-09-19-ux-ui-danh-sach-viec.md` |

---

# Hai thứ người dùng phải quyết

1. **Ưu tiên nào?** Thứ tự trên tối ưu **giá trị người dùng trên mỗi giờ công**. Nếu ưu
   tiên là **phần demo cho hội đồng**: đưa **P3 lên trước chặng 2–3**, và **giải thích
   biểu đồ lên chặng 2**.
2. **Lối A hay B cho P3** — chặn ở đầu chặng 4, hỏi sớm được.

# Hai chỗ cố ý KHÔNG có trong danh sách

- **Tóm tắt đầu báo cáo PDF** — PDF **đi ra ngoài** và font nhúng **thiếu glyph**
  (`→ ▲ ▼` bị bỏ im lặng từ 2026-09-09). Nếu làm thì bắt buộc chạy câu qua bộ quét glyph
  ở `xuat_tep_test.dart`. Mục 11.2.
- **AI viết câu thông báo** — cần ngắn, đoán được, `dedupeKey` ổn định. Mục 11.2.
