# B2 — Khoản chi lặp → gợi ý tạo hoá đơn — thiết kế

**Ngày:** 2026-09-28 (tối). **Người dùng duyệt** bản thiết kế trong chat cùng ngày, với các lựa chọn: ngưỡng **3 lần** ·
thẻ **chỉ ở trang Hoá đơn** · **không** phát thông báo · *Bỏ qua* **mở lại sau 3 lần mới** (cùng luật B1) · chu kỳ
**tháng + tuần** · khoản **không ghi chú thì bỏ qua**. Vị trí trong lộ trình 28/09: B1 → B5a → **B2** → B3 → B4 → B5b.
Schema **v27**, sau v26 của B5a.

## 1. Vì sao

Người dùng ghi tay cùng một khoản chi mỗi tháng (tiền nhà, Netflix, điện) mà không biết app có tính năng hoá đơn, hoặc
biết nhưng ngại tạo. Hoá đơn cho họ lời nhắc, tự trả, dự báo 30 ngày và thẻ số liệu — những thứ một khoản chi rời không
có. **Hôm nay không có hàm nhận diện khoản lặp nào** (quét `lib/` 2026-09-28).

Đối chiếu thị trường (2026-09-28): Monarch tự quét giao dịch mỗi lần đồng bộ để phát hiện *luồng lặp*; Copilot chỉ tạo
khoản lặp **từ một giao dịch có sẵn** rồi để người dùng chỉnh bộ lọc. Trang trợ giúp của cả hai đều không công bố ngưỡng
số lần. B2 đứng giữa: máy phát hiện, **người dùng bấm xác nhận** mới tạo hoá đơn. AI không tự ghi (bất biến ④).

## 2. Nhận diện — hàm thuần `lib/features/transaction/domain/khoan_lap.dart`

**Đầu vào:** giao dịch của **một** tài khoản, cửa sổ 120 ngày tính tới `now`. **Loại** các khoản:

- đã xoá mềm; `type != 'chi'`; không qua `khoanVaoThongKe` (khoản chuyển, điều chỉnh số dư, mở sổ);
- có `billId` (đã là hoá đơn) hoặc `goalId` (trích mục tiêu);
- ghi chú rỗng **sau** chuẩn hoá (người dùng chốt: không gộp theo danh mục);
- ngày ở **tương lai** (`date > now`; CSDL có khoản trích ghi lùi ngày tới).

**Khoá nhóm** = `(chuẩn hoá ghi chú, categoryId)`, trong đó *chuẩn hoá ghi chú* là: `removeVietnameseTones` → chữ
thường → tách từ → **bỏ mọi từ có chữ số**, và bỏ chữ *thang* / *t* đứng ngay trước một từ vừa bị bỏ → nối lại bằng một
dấu cách. Ví dụ *"Tiền nhà T9"*, *"tiền nhà tháng 10"*, *"Tien nha 11/2026"* đều thành `tien nha`. Được phép bỏ dấu vì
đây là **gợi ý**: quy tắc 7 cấm bỏ dấu cho **luật trùng tên**, còn gợi ý đoán sai thì chỉ tốn một cú *Bỏ qua*.

**Một nhóm là khoản lặp** khi có một **chuỗi ≥ 3 lần liên tiếp, tính từ lần gần nhất lùi về**, thoả cả ba điều:

1. Mọi khoảng cách giữa hai lần liền nhau thuộc **cùng một** chu kỳ: tháng `25 ≤ d ≤ 34` ngày, hoặc tuần `6 ≤ d ≤ 8`
   ngày. Hai lần **cùng ngày** thì gộp làm một lần (cộng tiền), vì một khoản ghi làm hai dòng không phải hai kỳ.
2. Mọi số tiền trong chuỗi lệch ≤ 10 % so với **trung vị** của chuỗi.
3. Lần gần nhất cách `now` **không quá 1,5 chu kỳ** (tháng ≤ 45 ngày, tuần ≤ 10 ngày). Quá thì coi là đã ngừng.

Chuỗi lấy **dài nhất có thể** tính từ lần gần nhất: đi lùi tới khi gặp khoảng cách hoặc số tiền phá luật. Chu kỳ tháng
xét trước tuần; một nhóm chỉ ra **một** kết quả.

**Kết quả** `KhoanLap`:

| Trường | Giá trị |
|---|---|
| `khoaNhom` | chuỗi `'<ghi chú chuẩn hoá>|<categoryId>'` |
| `ten` | ghi chú của lần **gần nhất**, giữ dấu và chữ hoa, **bỏ** các từ có chữ số (cùng luật khoá), gom khoảng trắng |
| `soTien` | số tiền lần gần nhất |
| `chuKy` | `kBillCycleMonth` \| `kBillCycleWeek` |
| `ngayGoc` | tháng: xem dưới; tuần: `null` |
| `ngayGanNhat` | ngày lần gần nhất |
| `categoryId` | của nhóm |
| `walletId` | ví xuất hiện **nhiều nhất** trong chuỗi; hoà thì ví của lần gần nhất |
| `soLan` | độ dài chuỗi |

**Ngày gốc (tháng):** ngày-trong-tháng của lần gần nhất. **Ngoại lệ:** nếu lần gần nhất rơi đúng **ngày cuối** của
tháng ấy thì lấy **ngày lớn nhất** trong chuỗi. Nhờ vậy *31/1 → 28/2 → 31/3* ra 31, và *30/9 → 31/10 → 30/11* ra 31.
Luật `anchorDay` của hoá đơn (v18) sẽ tự kẹp theo từng tháng. Phải có test **tháng 2 năm thường, tháng 2 năm nhuận**,
và **tháng 30 ngày**.

**Không gợi ý** nhóm có một **hoá đơn đang sống** trùng tên: hoá đơn chưa xoá mềm, và `conPhaiTra(b) || b.isRecurrence`,
so `chuẩn hoá ghi chú(b.name)` với phần ghi chú của `khoaNhom`. Nghĩa là người dùng đã có hoá đơn *"Tiền nhà"* thì khoản
ghi tay *"tiền nhà T10"* không bị gợi ý lại.

## 3. Phản hồi — bảng `GoiYHoaDonPhanHois`, schema v27, cục bộ

Tệp `core/database/tables/goi_y_hoa_don_phan_hoi_table.dart`, theo khuôn `ai_feedback_table.dart`: **không** có
`syncStatus` / `syncError` / `updatedAt` / `isDeleted`.

| Cột | Ý nghĩa |
|---|---|
| `id` | UUID |
| `idaccount` | từ phiên (quy tắc 2) |
| `khoaNhom` | như `KhoanLap.khoaNhom` |
| `ketQua` | `bo_qua` \| `da_tao` |
| `createdAt` | lúc bấm |

- **`bo_qua`:** ẩn nhóm. **Mở lại** khi có **≥ 3 khoản mới** của nhóm với `date` **sau** hàng `bo_qua` cuối của nhóm
  (cùng luật B1: bằng chứng mới thắng lời từ chối cũ). Không có luật này thì một lần *Bỏ qua* lúc mới dùng app khoá nhóm
  ấy vĩnh viễn.
- **`da_tao`:** ẩn nhóm **vĩnh viễn**. Hàng này cần thiết vì người dùng có thể **đổi tên** trong form: *"tiền nhà"* thành
  *"Thuê phòng"*, và khi ấy phép so tên ở mục 2 không bắt được nữa.
- Migration `from < 27` → `createTable`. Purge theo tài khoản ở `purgeDataForOtherAccounts` / `purgeDataForAccount`. Test
  quét 15 thêm tên bảng / lớp / cột vào danh sách cấm.

## 4. Chọn và hiện — trang Hoá đơn

- **Hàm thuần `chonDeXuatHoaDon({required List<KhoanLap> ds, required List<Bill> hoaDon, required
  List<GoiYHoaDonPhanHoi> phanHoi, required List<Transaction> giaoDich})`** (ở `bill/domain/de_xuat_hoa_don.dart`): loại
  nhóm trùng tên hoá đơn đang sống (mục 2) và nhóm bị phản hồi ẩn (mục 3), xếp theo `soLan` giảm dần rồi `ngayGanNhat`
  mới nhất, lấy tối đa **3**. Phép đếm *"3 khoản mới sau `bo_qua`"* dùng **`khoaNhomCua(Transaction)`**, hàm công khai
  của `khoan_lap.dart` và cũng là hàm `timKhoanLap` dùng để gom nhóm. Chép luật chuẩn hoá ra chỗ thứ hai là hai định
  nghĩa khoá. Không còn ứng viên thì trả **`null`**, và trang **không dựng** thẻ. Luật ẩn nằm ở hàm, không ở widget
  (cùng bài học thẻ *Chưa đặt ngân sách*).
- **Nguồn `DeXuatHoaDonNguon`** (`bill/data/de_xuat_hoa_don_nguon.dart`, đăng ký DI): đọc giao dịch 120 ngày, hoá đơn
  của tài khoản và phản hồi, rồi gọi hai hàm thuần. Không có repository mới.
- **Widget `TheKhoanLap`** (`bill/presentation/widgets/the_khoan_lap.dart`): tự nạp qua một loader tiêm vào
  (`Future<List<KhoanLap>?> Function()`), và nạp lại sau *Tạo* / *Bỏ qua*. `BillBloc` **không** đổi. Đặt ở `BillPage`
  **dưới khối Nhận xét, trên hàng tab**.
- **Dòng:** tên · *"khoảng 150.000 đ mỗi tháng · 4 lần"* (hoặc *mỗi tuần*) · nút **Tạo** · nút **Bỏ qua**. Tiêu đề
  thẻ *"Có vẻ là khoản lặp"*, kèm chip *"N khoản"*. Tiền đi qua `CurrencyFormatter.format`.
- ⚠️ Khối thêm vào sẽ chiếm bớt chiều cao của `Expanded` (bẫy chặng 1.3: trạng thái rỗng từng tràn 73 px), nên phải có
  ca test ở khổ màn thấp.
- ⚠️ **Thiết kế trên Stitch trước** (khối mới trên màn đã có), theo khuôn màn *Chưa đặt ngân sách* `eb872aa9…`. Timeout
  của Stitch không phải thất bại; hỏi người dùng nhìn giúp.

## 5. Tạo hoá đơn điền sẵn

- Route `/bills/add` đọc query `name`, `amount`, `cycle`, `anchor`, `start`, `category`, `wallet` và truyền vào
  `BillAddPage({DienSanHoaDon? dienSan})`. `DienSanHoaDon` là record Dart thuần. Query hỏng thì bỏ trường ấy, không ném.
- Giá trị điền sẵn **chỉ** ở đường tạo mới (form Sửa không nhận). **Ngày bắt đầu = `ngayGanNhat`** (query `start`,
  thêm vào danh sách trên). Hạn kỳ đầu `BillSchedule.ketThucKy = nextBillDueDate(startDate, chuKy, anchorDay:)` khi ấy
  rơi đúng vào **lần lặp kế tiếp**. Đừng cộng thêm một chu kỳ: làm vậy là hạn kỳ đầu trễ một kỳ, và người dùng bỏ lỡ
  đúng lần nhắc đầu tiên.
- `BillAddPage` hôm nay `pop()` ngay sau khi gửi `AddBillEvent`. Đổi thành `pop(true)` khi đã gửi. `TheKhoanLap`
  `await context.push<bool>(…)`; nhận `true` thì ghi `da_tao`. Lệnh ghi là SQLite cục bộ nên *đã gửi* ≈ *đã lưu*; nếu
  nó hỏng thì `BillBloc` báo lỗi như hôm nay, và nhóm bị ẩn nhầm là cái giá chấp nhận được.
- Ví / danh mục điền sẵn đã bị xoá thì form rơi về lựa chọn mặc định như khi không điền sẵn.

## 6. Giới hạn nói trước

- Tài khoản thật (giao dịch đầu 02/09/2026) sẽ **im** với khoản lặp theo tháng tới khoảng **tháng 11/2026**. Theo tuần
  thì sớm hơn nếu có. Đó là hành vi đúng.
- Người **không ghi chú** không bao giờ được gợi ý (người dùng chốt).
- Hai khoản lặp khác nhau **cùng ghi chú, cùng danh mục** (vd. hai phòng trọ cùng ghi *"tiền nhà"*) gộp làm một và
  thường phá luật số tiền, nên **im**.
- Không phát thông báo (người dùng chốt), không có trên Trang chủ.

## 7. Kiểm thử

- **`khoan_lap` (hàm thuần):** ba lần theo tháng → một kết quả; hai lần → không; khoảng cách lệch → chuỗi cắt đúng chỗ;
  tuần; số tiền lệch 11 % → không; lần gần nhất quá 45 ngày → không; loại `billId` / `goalId` / `transfer` / điều chỉnh /
  không ghi chú / tương lai; *"Tiền nhà T9"* + *"tiền nhà tháng 10"* + *"Tien nha 11/2026"* → một nhóm, tên *"Tiền nhà"*;
  hai khoản cùng ngày gộp; ngày gốc 31 qua **tháng 2 năm 2027 (thường)**, **tháng 2 năm 2028 (nhuận)**, và tháng 30
  ngày; ví hay dùng nhất.
- **`chonDeXuatHoaDon`:** trùng tên hoá đơn đang sống → loại; hoá đơn đã xoá hoặc đã trả hết mà không lặp → không loại;
  `bo_qua` → ẩn; thêm 2 khoản sau `bo_qua` → vẫn ẩn; thêm 3 → hiện lại; `da_tao` → ẩn dù thêm bao nhiêu; trần 3; rỗng →
  `null`.
- **Schema:** v26 → v27; purge; test quét 15 đỏ với bản sai.
- **Route + form:** query đủ → form điền đúng sáu ô; query hỏng → form trống, không ném; `pop(true)`.
- **Widget `TheKhoanLap`:** không ứng viên → không dựng gì; ba dòng; *Bỏ qua* → dòng biến mất và có hàng `bo_qua`;
  *Tạo* → push đúng URL, nhận `true` → có hàng `da_tao`; khổ màn thấp không tràn.
- **Máy ảo:** ghi lùi ngày ba khoản *"Tiền nhà"* cách nhau một tháng, thẻ hiện, *Tạo*, hoá đơn có đúng ngày gốc, thẻ biến
  mất. Đối chiếu màn Stitch.

## 8. Tài liệu đi kèm

`docs/bill/BILL_DOCUMENTATION.md` thêm một mục *Gợi ý tạo hoá đơn từ khoản lặp*. `CLAUDE.md`: hàng *"Đụng vào hoá
đơn"*, schema v27, mốc test. `PROJECT_CONTEXT.md` mục 14. Bản đồ nhóm B: B2 ✅.
