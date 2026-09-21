# Dự báo dòng tiền 30 ngày tới — thiết kế

> Ngày 2026-09-16. Trạng thái: ✅ **ĐÃ THI CÔNG XONG** cùng ngày — 9 commit,
> nghiệm thu máy ảo. Mục **#4** của bảng khảo sát app thị trường lần hai (mục
> **3.25** `docs/ANALYTICS_FEATURE.md`); người dùng chốt làm nó trước Sankey
> (#11). Bàn giao ở mục **3.27** `docs/ANALYTICS_FEATURE.md`; kế hoạch thi công
> ở `plans/2026-09-16-du-bao-dong-tien.md`.
>
> ⚠️ **SÁU chỗ bản thi công LỆCH spec này** — spec là ảnh chụp *trước* khi gõ,
> đọc nó mà không đọc khối này là hiểu sai hệ thống đang chạy:
>
> 1. **§5.3 trục biểu đồ.** Spec để trục chạy **từ 0** (`san = coAm ? day*1.1 :
>    0`). Máy ảo cho thấy đường nằm **phẳng** khi cam kết chỉ bằng 2,8% số dư,
>    nên người dùng chốt **co trục theo dữ liệu**. Phép tính nay ở hàm thuần
>    **`daiTrucDuBao`** (không có trong spec), và bước phải **tròn** — bước lẻ
>    làm hai nhãn in đè. Xem bẫy **4.21** `ANALYTICS_FEATURE.md`.
> 2. **§5.3 chú giải hai đường.** Màn Stitch có, spec không — nét đứt không nhãn
>    thì người đọc không đoán được nó là gì. Đã thêm.
> 3. **§4.1 `CamKet.viNhanId`.** Thêm so với spec, để cảnh báo ví thiếu tính cả
>    tiền **vào** ví nhận của khoản trích tự động.
> 4. **§5.3 nhánh kỳ rỗng.** Khối hiện **cả khi kỳ đang xem rỗng** — dự báo
>    không nói về kỳ, nên ngày đầu tháng vẫn phải thấy 30 ngày tới.
> 5. **§4.5–4.6 `viTinhVaoTong`.** Spec ghi chữ ký hai tham số; hàm nay có vế
>    thứ ba **`isDeleted`** (mặc định `false`) — **G42**, mở và đóng cùng ngày.
> 6. **§4.5 `belowBarData`.** Chỉ cắt ở mốc 0 khi 0 **nằm trong** dải; trục co
>    thì thường không, và cắt ở mốc ngoài khung là tô đặc cả biểu đồ.
>
> Mọi phần khác — hai tầng, luật chuyển ví, mười một bẫy, giới hạn cố ý không
> vá — thi công **đúng nguyên văn**.
>
> ✅ **HẾT HIỆU LỰC 2026-09-21** — luật `docs/superpowers/specs/` đã bỏ khỏi
> `.gitignore` và tệp này nay đi theo repo. ⚠️ Câu cũ ở đây còn dặn *"đừng
> `git add -f` để sửa điều đó"* — hoá ra chính quy ước ấy mới là chỗ sai:
> **13/24 spec đã phải `add -f`**, và hai spec mà `CLAUDE.md` gọi là "đã duyệt"
> thì chỉ tồn tại trên một máy. Một luật mà người ta phải phá đều đặn là một
> luật sai.

---

## 1. Vấn đề

Trang Phân tích có 12 khối và **tất cả nhìn về quá khứ**: thu chi của kỳ, so
với kỳ trước, xu hướng sáu kỳ, thác nước, dòng tiền tự do, vay/nợ. Không khối
nào trả lời câu người dùng hỏi **trước khi tiêu**: *"tháng này còn tiêu được bao
nhiêu sau khi trừ những thứ chắc chắn phải trả?"*

PocketSmith trả lời câu ấy bằng đường số dư chiếu tới tương lai; Monarch bằng
"Forecast" trong Cash Flow. FlowMoney có nguyên liệu hiếm mà hai app Việt (Money
Lover, MISA) không có: **hoá đơn lặp** mang `anchorDay` + `timeRecurrence` +
ân hạn, **mục tiêu trích tự động** mang mốc neo + chu kỳ, **ngân sách** có kỳ
và số đã chi tính lại từ sổ. Mọi thứ cần chiếu tương lai đều đã có luật đang
chạy thật ở ba vùng ấy.

### 1.1 Điều **không** làm, và vì sao

Đo bằng mã 2026-09-16 (`CLAUDE.md` cũng ghi): **thu nhập không lưu ở đâu cả** —
không hoá đơn "thu", không lương định kỳ, và cột `payee` không có nên không tự
phát hiện lương từ lịch sử được (đúng lý do #8 của bảng khảo sát bị bỏ). Ba lối
đã cân nhắc:

| Lối | Chốt | Vì sao |
|---|---|---|
| Đường số dư tương lai, thu nhập **suy từ trung bình** các kỳ gần đây | ✗ | Là một con số **đoán** ngồi cạnh những con số thật; tháng nào vay tiền thì trung bình vọt lên, im lặng (cùng bẫy `tong.thu` ở 3.24) |
| Đường số dư tương lai, người dùng **tự khai** thu nhập định kỳ | ✗ | Cần bảng mới (cục bộ hoặc xin backend) và một màn nhập — phạm vi lớn hơn hẳn, chưa đáng |
| **Cam kết đã biết chắc + còn tiêu được** | ✅ | Chỉ chiếu thứ đã có luật chạy thật; không đoán; không đổi schema |

Người dùng chốt lối thứ ba ngày 2026-09-16. Hệ quả cố ý: dự báo **không có thu
nhập, không có chi tuỳ ý, không có kỳ ngân sách sau** — mọi câu chữ trên khối
phải nói rõ điều ấy.

## 2. Năm quyết định đã chốt

1. **Câu hỏi:** cam kết sắp tới + còn tiêu được (không phải đường số dư đầy đủ).
2. **Ngân sách là tầng thứ hai** — phần *còn lại* của kỳ hiện tại, tách khỏi
   tầng "chắc chắn". Hai con số, ghi rõ tầng nào là gì.
3. **Tầm nhìn 30 ngày cố định**, luôn tính **từ hôm nay**, độc lập với bộ chọn
   phạm vi của trang. Không chip 7/30/90: tầng ngân sách đếm theo kỳ của chính
   ngân sách (thường tháng), tầm nhìn lệch xa 30 ngày là hai tầng nói hai
   khoảng khác nhau — cùng bẫy P1 chỉ gắn ngân sách ở đơn vị Tháng.
4. **Tổng + cảnh báo ví thiếu**: con số chính trên tổng tài sản
   (`viTinhVaoTong`), cộng một dòng cảnh báo khi một ví không đủ trả cam kết
   của chính nó.
5. **Vị trí:** trang Phân tích, ngay sau thẻ tổng (`_KhoiTong`) — "còn tiêu
   được 30 ngày tới" đứng cạnh "số dư còn lại" của kỳ. **Trình bày:** ba con
   số + biểu đồ bậc thang 30 ngày + danh sách cam kết theo ngày.

## 3. Kiến trúc — lối A, mở rộng `ThongKeKy`

Đúng khuôn P1/P2 đã mở rộng trang này. Lối B (repository + cubit riêng) bị
loại vì đẻ khuôn mới trong trang vốn một cubit và hai mốc thời gian trên cùng
một màn.

```
billDao.watchAll ─┐
goalDao.watchAll ─┤
watchBudgets(now: at) ─┤  (nguồn thứ 7, RIÊNG cho dự báo — xem §5.1)
transactionDao.watchAll ─┼─► AnalyticsRepositoryImpl._dung ─► ThongKeKy.duBao
categoryDao.watchBangTraTen ─┤          │
watchBudgets(now: mocNganSach) ─┤       └─ duBaoCua(...)   ← analytics/domain/du_bao_dong_tien.dart
wallets.watch ─┘                            ├─ kyKeTiepCua(Bill)  ← bill/domain (MỚI, tách từ _nextPeriodOf)
                                            ├─ mocThuN / cacKyDenHan / quyetDinhTrich  ← goal/domain (đã có)
                                            ├─ budgetPaceOf  ← budget/domain (đã có)
                                            └─ viTinhVaoTong  ← wallet/domain (đã có)
```

**Không đổi schema, không thêm trường đồng bộ, không đụng repository hoá
đơn/mục tiêu** — ngoài việc tách phép tính ngày của `_nextPeriodOf` thành hàm
thuần và cho nó gọi lại.

## 4. Tầng thuần — `analytics/domain/du_bao_dong_tien.dart`

### 4.1 Kiểu dữ liệu

```dart
enum LoaiCamKet { hoaDon, trichTuDong }

class CamKet {
  final DateTime ngay;        // đầu ngày; cam kết quá hạn dồn về hôm nay
  final String ten;
  final LoaiCamKet loai;
  final String walletId;      // ví BỊ TRỪ (hoá đơn: walletId; trích: ví nguồn)
  final String? tenVi;
  final double soTien;        // luôn dương
  final String? categoryId;   // hoá đơn: để tầng 2 khử đếm đôi; trích: null
  final bool quaHan;          // hạn đã qua, chưa trả
  final bool laKyChieu;       // kỳ TƯƠNG LAI suy ra, chưa là hàng thật
  final double tacDongTong;   // ảnh hưởng lên TỔNG tài sản, có dấu — xem 4.4
}

class ViThieu {
  final String walletId;
  final String ten;
  final double thieu;         // số dương: còn thiếu bao nhiêu
  final DateTime ngay;        // ngày đầu tiên số dư ví xuống dưới 0
}

class DiemDuBao {
  final DateTime ngay;
  final double chacChan;      // tầng 1 tích luỹ tới ngày này
  final double theoNganSach;  // chacChan − nganSachConLai × i/30
}

class DuBaoDongTien {
  final DateTime tu;                  // hôm nay, đầu ngày
  static const int soNgay = 30;
  final double soDuHienTai;
  final List<CamKet> camKet;          // sắp theo ngày, rồi theo tên
  final double tongCamKet;            // Σ (−tacDongTong)  ⇒ dương khi tiền ra
  final double nganSachConLai;        // tầng 2, ≥ 0
  final List<ViThieu> viThieu;
  final List<DiemDuBao> chuoi;        // ĐÚNG 31 điểm

  double get conTieuDuoc => soDuHienTai - tongCamKet;
  double get conTieuDuocTheoNganSach => conTieuDuoc - nganSachConLai;
  bool get coNganSach => nganSachConLai > 0;
}
```

### 4.2 Chữ ký

```dart
DuBaoDongTien? duBaoCua({
  required DateTime now,
  required List<Bill> hoaDon,          // hàng Drift, đã lọc deletedAt ở DAO
  required List<GoalEntity> mucTieu,
  required List<BudgetView> nganSach,  // từ watchBudgets(now: now) — KHÔNG phải mocNganSach
  required List<Wallet> vi,            // kể cả lưu trữ / xoá mềm — để tra tên
});
```

Trả `null` khi **không có ví nào** (không có thang đo — cùng chốt
`dongTien == null` của thác nước). Mọi ca khác trả một `DuBaoDongTien`, kể cả
khi không có cam kết nào.

### 4.3 Hoá đơn → cam kết

Với mỗi hàng `b` trong `hoaDon`:

1. Bỏ nếu `!conPhaiTra(b)` (định nghĩa duy nhất ở `bill_pay_status.dart` — đã
   trả, đã bỏ qua đều không phải nợ).
2. Bỏ nếu `b.walletId == null` (bộ tự trả cũng từ chối hàng ấy).
3. Bỏ **kỳ chiếu** nếu `b.id` xuất hiện trong `generatedFromBillId` của hàng
   khác — hàng đã sinh kỳ sau thì kỳ sau tự có mặt trong danh sách; chỉ chiếu từ
   **hàng cuối chuỗi**. Hàng thật vẫn thành cam kết.
4. Cam kết thứ nhất: `ngay = max(dauNgay(b.dueDate), homNay)`,
   `quaHan = dueDate < homNay`, `laKyChieu = false`.
5. Nếu `b.isRecurrence` và không bị loại ở bước 3: lặp `kyKeTiepCua` từ `b`
   (rồi từ kỳ vừa chiếu) tới khi `hanTra > homNay + 30 ngày` hoặc đủ **12**
   vòng; mỗi kỳ là một cam kết `laKyChieu = true`, `soTien = b.amount` (chưa
   biết số sẽ trả, lấy số kỳ hiện tại — đúng tinh thần "kỳ sau bắt đầu từ số
   vừa trả" của `_nextPeriodOf`). Trần 12 là dư cho chu kỳ tuần (≤ 5 kỳ trong
   30 ngày); vượt trần thì dừng im lặng, cùng lối `_tranDoMoc`.

**`kyKeTiepCua(Bill) → ({DateTime batDau, DateTime ketThuc, DateTime hanTra, int anchorDay})`**
là hàm thuần **mới** ở `features/bill/domain/bill_ky_ke_tiep.dart`, tách nguyên
văn phép tính ngày của `BillRepositoryImpl._nextPeriodOf`:

```
batDau  = b.periodEnd ?? b.dueDate            // nối từ KẾT THÚC KỲ, không phải hạn trả
goc     = b.anchorDay ?? batDau.day
ketThuc = nextBillDueDate(batDau, b.timeRecurrence, anchorDay: goc)
hanTra  = hanTraTu(ketThuc, anHanCua(b))
```

`_nextPeriodOf` **gọi lại** hàm này để dựng `BillsCompanion`. Có ca test canh
hai bên không lệch. Khi chiếu kỳ thứ hai trở đi, đầu vào là một `Bill` giả dựng
từ kỳ vừa chiếu (`periodEnd = ketThuc`, `dueDate = hanTra`, `anchorDay = goc`)
để `anchorDay` **đi theo chuỗi** — cộng dồn từ kỳ trước là "ngày 31" tụt về 28
vĩnh viễn ngay từ kỳ chiếu thứ hai.

### 4.4 Mục tiêu → cam kết

Với mỗi `g` trong `mucTieu`: bỏ nếu `!g.autoDepositEnabled`, `g.daHoanThanh`,
`g.remainingAmount <= 0`; bỏ nếu ví nguồn không tồn tại, không hoạt động
(`WalletStatus.laHoatDong`), hoặc trùng ví đích — đúng ba chốt của
`GoalAutoDepositRunner._chayMotMucTieu`.

Các mốc kỳ:
- **đã tới hạn chưa trích** — `cacKyDenHan(mocNeo, lanChayGanNhat, chuKy, now)`
  → mỗi mốc một cam kết đặt **hôm nay** (lượt quét kế sẽ trừ), `quaHan = true`;
- **tương lai** — từ `kyKeTiep(...)` rồi bước tiếp bằng `mocThuN(goc, chuKy, n)`
  (neo mốc gốc, không cộng dồn) tới khi vượt `homNay + 30 ngày`, trần 12 vòng.

Số tiền mỗi kỳ = `quyetDinhTrich(soTienCai: g.autoDepositAmount, conThieu:
conThieu, soDuViNguon: double.infinity).soTien` với `conThieu` **giảm dần** qua
từng kỳ chiếu; về 0 thì dừng. Truyền vô cực cho ví nguồn vì dự báo không đoán
ví có đủ hay không — đó là việc của `viThieu`.

### 4.5 Luật chuyển ví — `tacDongTong`

| Cam kết | `tacDongTong` |
|---|---|
| Hoá đơn, ví trả tính vào tổng | `−soTien` |
| Hoá đơn, ví trả không tính vào tổng (loại khỏi tổng, lưu trữ) | `0` |
| Trích tự động | `(nguồn tính vào tổng ? −soTien : 0) + (đích tính vào tổng ? +soTien : 0)` |

"Tính vào tổng" là **`viTinhVaoTong(includeInTotal:, status:)`** — một định
nghĩa, cùng Trang chủ. Hệ quả: trích vào ví Tiết kiệm **đã loại khỏi tổng** trừ
thật; ví đích `null` (mục tiêu chưa gán ví) coi như "không tính vào tổng" → trừ
thật ở nguồn. `tongCamKet = Σ(−tacDongTong)`.

`soDuHienTai = Σ balance` của ví qua cùng `viTinhVaoTong`. **Đọc `balance`**,
không gọi `tongTheoVi` — số dư ví là cache của một công thức (G37) nhưng mọi
màn khác đều đọc cache ấy, hai đường tính là hai con số trên cùng màn hình. Ví
`banking` **có** tính: số dư do server ghi vẫn là số dư thật.

### 4.6 Ví thiếu — `viThieu`

Với mỗi ví **hoạt động** (bỏ ví lưu trữ: người dùng đã cất nó đi, báo thiếu là
ồn), gom cam kết có `walletId` là nó, sắp theo ngày, chạy
`conLai = balance − Σ soTien` cộng dồn; ngày đầu tiên `conLai < −0.5` (ngưỡng
nửa đồng, cùng luật đối soát số dư) là `ngay`, `thieu = −min(conLai)`. Ở đây
trừ **`soTien` đủ**, không phải `tacDongTong` — theo ví thì tiền rời ví là
thật dù tổng không đổi.

### 4.7 Ngân sách → tầng 2

Chỉ `BudgetView` có `!budget.isExpired(now)` và `currentPeriod(now)` chứa `now`
(`from ≤ now < to`). Nếu có ít nhất một ngân sách **tổng** (`categoryId == null`)
đạt điều kiện → tầng 2 chỉ gồm các ngân sách tổng; không có → Σ ngân sách danh
mục. Đóng góp của một ngân sách:

```
pace    = budgetPaceOf(b, now)
duKien  = pace.suggestedPerDay × min(pace.daysLeft, 30)   // = remaining × min(1, 30/daysLeft)
truHoaDon = Σ soTien của cam kết hoá đơn có ngay < min(kỳ.to, homNay+30)
            và (ngân sách tổng ? mọi hoá đơn : categoryId == b.categoryId)
dongGop = max(0, duKien − truHoaDon)
```

Ngân sách quý còn 60 ngày chỉ tính nửa phần còn lại — giả định tiêu đều, mượn
đúng `suggestedPerDay`. Trích tự động là `transfer`, không chạm ngân sách.

### 4.8 Chuỗi 31 điểm

`ngay_i = homNay + i`, `i = 0..30`.
`chacChan_i = soDuHienTai + Σ tacDongTong` của cam kết có `ngay ≤ ngay_i`
(`!ngay.isAfter(ngay_i)` — cam kết hôm nay **phải** nằm ở điểm 0).
`theoNganSach_i = chacChan_i − nganSachConLai × i / 30`.
Được phép âm ở mọi điểm, không kẹp.

### 4.9 Ba chốt cố ý

- **Số âm được phép** ở mọi con số và mọi điểm — kẹp về 0 là giấu đúng cảnh báo.
- **Không đoán**: không thu nhập, không chi tuỳ ý, không kỳ ngân sách sau.
- **So theo NGÀY** (`_dauNgay`), không theo thời điểm — cùng `denLuotTuTra`.

## 5. Luồng dữ liệu

### 5.1 Repository

`AnalyticsRepositoryImpl.watchKy` thêm **ba** đăng ký, cùng khuôn bốn nguồn
hiện có (`push()` chỉ chạy khi **cả bảy** đã có dữ liệu; `onCancel` huỷ đủ bảy):

- `db.billDao.watchAll(idaccount)`
- `db.goalDao.watchAll(idaccount)` → `GoalEntity.fromDrift`
- `budgetRepository.watchBudgets(idaccount, now: at)` — **riêng cho dự báo**

⚠️ Vì sao nguồn ngân sách thứ hai: nguồn đang có dùng `mocNganSach`, mốc ấy
**lùi về giây cuối kỳ** khi người dùng xem kỳ đã qua, nên `spent` là của kỳ
ngân sách chứa cuối tháng 6 khi họ xem tháng 6. Dùng chung thì dự báo **đúng khi
xem tháng này, sai khi xem tháng khác** — không lỗi nào báo. `_dung` gọi
`duBaoCua(now: at, ...)` với `at` là mốc `now` sẵn có, không phải `mocNganSach`.

### 5.2 State

`ThongKeKy` thêm `final DuBaoDongTien? duBao` với mặc định `null` — 12 tệp test
đang dựng `ThongKeKy` không đổi. `AnalyticsLoaded` **không** thêm gì: dự báo
không có lựa chọn nào của người dùng cần sống sót qua lần phát lại; "Xem thêm" là
state cục bộ của widget.

### 5.3 Widget `_KhoiDuBao`

Trong `analytics_page.dart`, chèn ngay sau `_KhoiTong`. `StatefulWidget` (chỉ
để giữ cờ "đã mở hết"). Từ trên xuống:

1. Tiêu đề **"Dự báo 30 ngày tới"**; dòng phụ *"Từ hôm nay, không theo kỳ đang
   xem — chỉ tính hoá đơn và trích tự động đã đặt"*.
2. Ba con số: *Số dư hiện tại* · **Còn tiêu được** (to, `formatCoDau`, màu theo
   dấu) · *Nếu tiêu đúng ngân sách* (chỉ khi `coNganSach`).
3. Cảnh báo ví thiếu — mỗi ví một dòng: *"Ví Tiền mặt thiếu 1.500.000 đ để trả
   cam kết ngày 25/09"*.
4. `LineChart`: `chacChan` **bậc thang** (`isStepLineChart: true`),
   `theoNganSach` **nét đứt** (chỉ khi `coNganSach`); `minY` nhận âm,
   `FlClipData.all()`, `cutOffY: 0` ở **cả hai** vế tô, vạch 0 nét đứt — đúng
   bộ bẫy của 3.24. Trục hoành 4 nhãn `dd/MM`, trục tung qua `rutGon`.
5. Danh sách cam kết: tối đa **5** dòng — icon theo loại · tên · `dd/MM · ví` ·
   số tiền đỏ; huy hiệu **"Quá hạn"** / **"Dự kiến"**. Nút *"Xem thêm (n)"* mở
   hết.
6. Rỗng (`camKet.isEmpty`): thay 4–5 bằng câu *"Không có hoá đơn hay trích tự
   động nào trong 30 ngày tới"*; ba con số vẫn hiện.
7. `duBao == null` → **ẩn cả khối**, chốt ở **hai lớp** (trang không dựng khối,
   khối tự trả `SizedBox.shrink`) — cùng cách thác nước.

Widget **không nuốt lỗi** của tầng domain.

### 5.4 Stitch — lên trước khi gõ widget

Gọi `generate_screen_from_text` một màn **"Thống kê - Dự báo 30 ngày tới"**
(mobile 390px, Kinetic Finance, khuôn thẻ trắng của các màn Thống kê), mô tả
đủ bảy phần ở 5.3. Rồi **làm việc khác**, kiểm bằng `list_screens` sau —
timeout **không** phải thất bại, **không gọi lại**, và hỏi người dùng nhìn giúp
trước khi chốt.

## 6. Bẫy — mười một, tất cả hỏng im lặng

1. **Mốc ngân sách sai kỳ** — §5.1. Nguồn thứ bảy là bắt buộc.
2. **Nối kỳ chiếu từ `dueDate`** — hở đúng số ngày ân hạn, mỗi kỳ trôi thêm.
   `kyKeTiepCua` là định nghĩa duy nhất, `_nextPeriodOf` gọi lại nó.
3. **`anchorDay` không đi theo chuỗi chiếu** — "ngày 31" tụt về 28 vĩnh viễn
   từ kỳ chiếu thứ hai. Neo gốc, không cộng dồn.
4. **Đếm đôi ngân sách × hoá đơn** — tiền điện 800k ở tầng 1 **và** trong "còn
   lại" của ngân sách Điện nước. Tầng 2 trừ hoá đơn cùng danh mục, kẹp ≥ 0.
5. **Ví đích của trích tự động không tính vào tổng** — quên là mọi khoản trích
   ra 0 ròng, người tích vào ví Tiết kiệm loại khỏi tổng thấy "còn tiêu được"
   cao hơn thật đúng bằng số trích.
6. **So theo thời điểm** — cam kết hôm nay rơi vào hay không tuỳ giờ mở app.
7. **Lệch một ô ở điểm 0** — cam kết quá hạn dồn về hôm nay phải nằm ở điểm
   đầu; mỗi cam kết trừ đúng một lần.
8. **Tự tính lại số dư ví** — đọc `balance` như trang chủ, đừng gọi `tongTheoVi`.
9. **Hoá đơn trỏ ví lưu trữ** — cam kết vẫn tạo, tác động lên tổng tự thành 0
   qua `viTinhVaoTong`; `viThieu` bỏ qua ví ấy.
10. **`isStepLineChart` chưa dùng ở đâu trong `lib/`** (đo: 0 dòng) — tầng vẽ
    không test được (bẫy 4.9); bậc thang, nét đứt, `minY` âm, `cutOffY` hai vế
    chỉ máy ảo 411dp mới nói được.
11. ⚠️ **Giới hạn đã biết, cố ý không vá**: khử trùng kỳ chiếu bằng
    `generatedFromBillId` không bắt được hàng người dùng **tự tạo tay** cho kỳ
    sau → đếm đôi. Vá bằng so tên + ngày là đi lại lối so bằng tên mà cột
    `goalId` sinh ra để thay thế, và hỏng theo chiều tệ hơn — một hoá đơn thật
    biến mất khỏi dự báo. Ghi ra `ANALYTICS_FEATURE.md`, không đoán.

## 7. Xử lý lỗi

`duBaoCua` **không ném**: không ví → `null`; thiếu dữ liệu ở một hoá đơn/mục
tiêu → bỏ hàng ấy, các hàng khác vẫn tính; vượt trần 12 vòng → dừng im lặng.
Widget không nuốt lỗi — bài học helper `_tk` ở `analytics_page_test.dart`.

## 8. Kiểm thử

| Tệp | Canh gì |
|---|---|
| `test/features/analytics/domain/du_bao_dong_tien_test.dart` (**mới**) | Bẫy 1–9; luật chuyển ví (ba hàng của bảng 4.5); tầng 2 gồm ngân sách tổng đè danh mục, khử đếm đôi, ngân sách quý tính nửa; `viThieu` ngày đầu tiên âm, bỏ ví lưu trữ; chuỗi đúng 31 điểm, cam kết hôm nay ở điểm 0; `null` khi không ví; trần 12 vòng; mục tiêu `conThieu` giảm dần và dừng ở 0 |
| `test/features/bill/domain/bill_ky_ke_tiep_test.dart` (**mới**) | Ân hạn nối từ `periodEnd`; `anchorDay` giữ qua tháng ngắn và **năm nhuận**; hàng cũ `periodEnd` NULL ra y hệt trước v21; ca chứng minh `_nextPeriodOf` cho cùng ba mốc |
| `analytics_repository_impl_test.dart` | Nguồn thứ bảy; **xem tháng cũ** → dự báo vẫn tính từ `now` (bẫy 1); `push()` chờ đủ bảy nguồn |
| `analytics_page_test.dart` | Ẩn khi `duBao == null` (bản sai phải phá cả hai lớp); ba con số; dòng ví thiếu; "Xem thêm (n)" mở hết; câu rỗng |

TDD, đỏ đúng lý do; ca xanh ngay từ đầu thì làm **bản sai có chủ ý**. Nghiệm thu
máy ảo 411dp trước khi báo xong: bậc thang, nét đứt, nhãn trục không `-0`, không
tràn (đếm pixel vàng).

## 9. Phạm vi — không làm

- Không thu nhập, không chi tuỳ ý, không chip tầm nhìn, không bộ chọn ví.
- Không đổi schema, không thêm trường đồng bộ.
- Không đụng `SoDuViService`, `BillRepositoryImpl.payBill`,
  `GoalAutoDepositRunner`.
- Không sửa bẫy 11.

## 10. Tài liệu phải sửa khi thi công xong

`docs/ANALYTICS_FEATURE.md` mục mới **3.27** + bảng Kiểm thử mục 6 + bảng A8
7.1 không đổi (đây không phải mục A8); `CLAUDE.md` hàng "Đụng vào trang Phân
tích" và "Đụng vào biểu đồ" (khối fl_chart thứ **tám**, `isStepLineChart` lần
đầu); `docs/bill/BILL_DOCUMENTATION.md` ghi `kyKeTiepCua` là định nghĩa duy
nhất của kỳ kế tiếp; mục 14 `PROJECT_CONTEXT.md`. Đếm lại bằng máy mọi con số.
