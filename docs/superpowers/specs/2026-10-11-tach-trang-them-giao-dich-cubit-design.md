# Tách trang Thêm giao dịch ra Cubit + lớp nguồn — thiết kế

**Ngày:** 2026-10-11 · **Trạng thái:** thiết kế duyệt trong chat (ba phần, từng phần một), bản viết chờ người dùng đọc;
chưa có kế hoạch, chưa có mã ·
**Trả nợ:** G88 gạch 1 (`docs/CLIENT_APP_KNOWN_GAPS.md`) · **Luật:** mục 4 và 8 `docs/KIEN_TRUC_CLIENT_APP.md`, test quét 22–25 ·
**Tiền nhiệm:** spec bịt điểm rò `2026-10-10-bit-diem-ro-kien-truc-client-design.md` (đợt ấy tách bảy khối giao diện sang
`widgets/them_giao_dich/`, để lại trạng thái và logic ở trang — "hướng B" của nó chính là đợt này) ·
**Kế tiếp:** C4 giọng nói chạm đúng màn này, nên đợt này đi **trước** C4 (người dùng chốt 2026-10-11).

Đợt này **không đổi hành vi**: không đổi màn hình, chữ, `Key`, schema, payload đồng bộ, `pubspec`. Người dùng app không
thấy gì khác. Mọi số đếm trong tệp đo ngày 2026-10-11 trên `HEAD` = `f59c4769`.

## 0. Bốn quyết định của người dùng (2026-10-11)

1. **Đích:** trang xuống **dưới 1.200 dòng** (rút khỏi danh sách miễn trừ của test quét 23) **và** phần logic dời ra có
   test riêng không cần dựng widget.
2. **Test cũ giữ nguyên, chỉ đổi import.** Trang giữ đúng các tham số khởi tạo hiện có; ca cũ phải xanh mà không sửa kỳ
   vọng nào. Ca nào đỏ là lỗi của bản tách — sửa mã, không sửa test. Ngoại lệ duy nhất: ba test quét đọc **mã nguồn** theo
   đường dẫn tệp (mục 6) đổi đường dẫn, không đổi kỳ vọng.
3. **Một Cubit cho form + một lớp nguồn dữ liệu** (đã loại: nhiều Cubit theo cụm — các cụm dính chặt, cần chỗ điều phối, dễ
   lỗi thứ tự; chỉ rút hàm thuần — logic còn ~1.600 dòng, không đạt quyết định 1).
4. **Thứ tự sáu bước, mỗi bước một commit**, sau mỗi bước bộ test cũ xanh (mục 7).

## 1. Mục tiêu / không mục tiêu

**Mục tiêu**
- `add_transaction_page.dart` < 1.200 dòng (đếm như quét 23), rút khỏi `mienTru`.
- Trạng thái và quyết định của form nằm trong `ThemGiaoDichCubit`, test được bằng `test` thường.
- Mọi lần đọc / ghi dữ liệu của form đi qua `ThemGiaoDichNguon` ở `data/`.
- Một cửa công khai để **điền form từ một kết quả đọc** (`dienKetQua`) — chỗ C4 sẽ gọi, như C2 (Nhập nhanh) và D1 (biến
  động) đang gọi bản riêng tư hôm nay.

**Không mục tiêu**
- Không đổi kiểu dữ liệu sang Entity — `Wallet`, `Category` của Drift giữ nguyên; đó là G88 gạch 3, đã xếp lịch sau. Gom
  chúng vào một Cubit làm đợt ấy dễ hơn.
- Không tách bốn trang lớn còn lại (G88 gạch 2 — đợt riêng sau C4).
- Không đổi `TransactionBloc` (luồng ghi giữ nguyên: trang gửi event, Bloc ghi qua repository).
- Không thêm gói (`bloc_test` không có trong `pubspec` — không thêm).
- Không sửa lỗi nào tiện đường. Thấy lỗi thì ghi lại, làm ở lượt riêng.

## 2. Hiện trạng (đo 2026-10-11)

- Trang **2.006** dòng theo `wc -l` (quét 23 đếm **2.007**), State giữ **61** trường (G88), ~90 hàm.
- Sáu cụm logic, dòng ước theo bản đồ thành viên:

| Cụm | Hàm tiêu biểu | ~dòng |
|---|---|---|
| Số tiền, bàn phím | `_onKeyPress`, `_getFormattedAmount`, `_chamSoTien`, `_dienSoTienChon`, `_soTienDangCo` | 90 |
| Ví | `_loadWallets`, `_apDungViChonSan`, `_apDungViDangSua`, `_apDungViHayDung`, `_moChonVi` | 110 |
| Gợi ý danh mục | `_loadViHayDung` (học hai mô hình), `_napTatCap`, `_onNoteChanged`, `_henGoiYTheoForm`, `_goiYSoTien`, `_loadSuggestion`, `_tinhDeXuat`, `_chapNhanDeXuat`, `_boQuaDeXuat`, `_ghiPhanHoi` | 420 |
| Nhập nhanh, điền sẵn | `_dienTuCau`, `_huyDocAi`, `_docCau`, `_dienKetQua`, `_napDanhMucVaTuKhoa` | 170 |
| Biến động / biên lai / ảnh quét | `_dienTuBienDong`, `_tinhGoiYChuyen`, `_apGoiYChuyen`, `_dongBienDong`, `_dongChuyenKhoan`, `_boQuaBienDong` | 200 |
| Lưu, tách, ngân sách | `_saveTransaction`, `_luuTach`, `_themPhan`, `_budgetImpactFor`, `_ghiPhanHoiKhiLuu`, hai hộp thoại | 270 |

- **24** tệp test với **215** ca (đếm `test(` / `testWidgets(`; cộng tệp giả `category_test_fakes.dart`) dựng trang qua hàm khởi tạo (tiêm `idaccount`, `wallets`, `viHayDung`, `boPhanLoai`,
  `boSoTien`, `phanHoiGoiY`, `docAi`, `bienDong`, `viTheoNguon`, `xoaBienDong`, `khoanTrongSo`, `hangBienDongCho`,
  `khoBienLai`, `khoAnhQuet`, `budgetLookup`, `laPremium`…). Đó là lưới an toàn của đợt.
- **Ba test quét đọc mã nguồn trang theo đường dẫn:** `test/core/utils/o_nhap_tien_co_tran_test.dart` (đòi chuỗi
  `themPhimSoTien`), `test/features/wallet/wallet_picker_sources_test.dart` (trang nằm trong `laBoChonVi`),
  `test/core/ui/tep_presentation_khong_qua_dai_test.dart` (trần 2.007). `khong_co_nut_chet_test.dart` cũng nêu trang —
  nút ⋮ *"Thêm tuỳ chọn"* ở lại trang nên mục ấy không đổi.

## 3. Bốn tệp

| Tệp | Việc | Ước |
|---|---|---|
| `features/transaction/presentation/bloc/them_giao_dich_state.dart` | `ThemGiaoDichState` bất biến (mục 4.1) | ~200 |
| `features/transaction/presentation/bloc/them_giao_dich_cubit.dart` | `ThemGiaoDichCubit` — mỗi hành động người dùng một hàm (mục 4.2) | ~800 |
| `features/transaction/data/them_giao_dich_nguon.dart` | `ThemGiaoDichNguon` — mọi đọc / ghi dữ liệu (mục 4.3) | ~250 |
| `features/transaction/presentation/pages/add_transaction_page.dart` (giữ tên, giữ `EditTransactionArgs`, `BudgetLookup`) | Ô nhập chữ, focus, khoá thẻ gợi ý, hộp thoại, mở trang chọn danh mục, toast, `pop`, nghe `TransactionBloc`, đọc phiên và gói | ~700 |

Vị trí theo luật mục 8: Cubit và state ở `presentation/bloc/`; lớp đọc nhiều repository ở `data/` theo nếp các lớp
`…Nguon` đã có (`category/data/gan_danh_muc_nguon.dart`, `budget/data/tai_phan_bo_nguon.dart`,
`bill/data/de_xuat_hoa_don_nguon.dart`). Quét 22 giữ: không tệp `presentation/` nào cầm `AppDatabase` hay DAO. Quét 23: Cubit
~800 dòng dưới trần 1.200.

## 4. Thiết kế từng đơn vị

### 4.1 `ThemGiaoDichState`

Trường **được vẽ** hoặc **được Cubit so** sau một lần chờ: `huong` (`'chi'|'thu'|'transfer'`), `chuoiSoTien`,
`hienBanPhimSo`, `vi` (danh sách đang dùng), `dangNapVi`, `viNguon`, `viDich`, `danhMuc`, `chieuNo`, `ngay`, `ghiChu`,
`goiY` (thẻ gợi ý đang hiện), `deXuat`, `daThemTuKhoa`, `ketQuaDien`, `dangDocAi`, `trungTrongSo`, `goiYChuyen`, `viGoiY`,
`phanTach`, `monQuet`, `dmTheoId`, `duongDanAnh`, `soLanCuonGoiY`.

Phép suy (getter, không lưu): `laChuyen`, `loaiGhi` (thay `_resolvedType` — chiều ghi suy từ danh mục, luật 2026-09-05),
`choTach`, `soTienDangCo`.

`copyWith` phải xoá được về `null` các trường nullable (`viNguon`, `danhMuc`, `goiY`…): dùng cờ xoá tường minh hoặc hàm bọc
giá trị — chọn ở kế hoạch, nhưng **một** cách cho cả lớp. Không kế thừa `Equatable` (nếp `BudgetDetailState`).

Trường **nội bộ của Cubit**, không vào state vì không ai vẽ chúng: hai mô hình gợi ý, ba tập tắt (`tatCap`, `tatCapSoTien`,
`tatCapTuKhoa`), hai tập *bỏ qua lượt này*, bảng ví hay dùng, mẫu đề xuất của đường sửa, `choPhanXu`, `nguoiDungDaChonVi`,
`viNguonDaNho`, `goiYDaApDung`, `luotDien`, `dangDien`, lời nhắn ngân sách chờ, số giao dịch vừa lưu, ba bộ hẹn giờ.

### 4.2 `ThemGiaoDichCubit`

Nhận qua hàm khởi tạo: `ThemGiaoDichNguon`, hàm đọc mã tài khoản `int? Function()`, giao dịch đang sửa
(`EditTransactionArgs?`), `huongBanDau`, hàng biến động (`DienSanBienDong?`), `choTickMon`, `CategorySuggestionEngine`.

Hàm công khai — mỗi hàm thay đúng một lối của trang hôm nay:

| Hàm | Thay cho |
|---|---|
| `moTrang()` | phần nạp của `initState` (ví, học mô hình, tập tắt, đề xuất từ khoá, điền biến động, ảnh) |
| `goPhim(k)`, `chamSoTien({required bool banPhimHeThongMo})`, `chonSoTien(v)` | `_onKeyPress`, `_chamSoTien`, `_dienSoTienChon` |
| `chonHuong(h)`, `chonDanhMuc(c)`, `chonChieuNo(d)`, `chonVi(w)`, `chonViDich(w)`, `chonNgay(d)` | các lối chọn cùng tên |
| `ghiChuDoi(chu)` | `_onNoteChanged` + `_henDeXuat` |
| `chonGoiY()`, `boQuaGoiY()`, `chapNhanDeXuat()`, `boQuaDeXuat()` | callback thẻ gợi ý và dòng đề xuất từ khoá |
| `chuanBiAi()`, `dienTuCau(cau)`, `huyDocAi()` | ô Nhập nhanh |
| **`dienKetQua(kq, chonDuoc:)`** | `_dienKetQua` — **cửa công khai cho C4** |
| `apGoiYChuyen()` | `_apGoiYChuyen` |
| `danhMucChoTach()`, `luuPhan(p, thay:)`, `boPhan(p)` | `_themPhan`, nút bỏ phần |
| `chuanBiLuu()`, `daGuiLuu(...)`, `cauSauLuu()`, `dongSauLuu()`, `boQuaBienDong()` | `_saveTransaction`, `_luuTach`, `_ghiPhanHoiKhiLuu`, nhánh `actionSuccess`, `_boQuaBienDong` |
| `close()` | phần huỷ hẹn giờ và xoá ảnh quét của `dispose` |

**Bất biến phải giữ nguyên** — hôm nay chỉ sống trong chú thích, đợt này ghim thành test (mục 8):

1. Ví đoán từ lịch sử (ví hay dùng, chặng 1.2) **không bao giờ** đè ví người dùng vừa chọn, và không chen vào đường sửa;
   tra không thấy thì giữ nguyên ví đang có.
2. Chọn chiều Chi / Thu bỏ danh mục thuộc chiều kia; với danh mục vay / nợ, đoạn Chi / Thu chính là chiều tiền. Chọn danh
   mục thì đoạn nhảy theo danh mục.
3. `dienKetQua` đi đúng đường người dùng vẫn đi, theo thứ tự: chiều qua `chonHuong` → số tiền qua `themPhimSoTien` từng
   chữ số (trần 13 chữ số) → ví đọc từ câu đặt cờ *người dùng đã chọn ví* → danh mục qua `chonDanhMuc` → ghi chú **sau**
   danh mục. Câu chỉ nêu ví đích trùng ví nguồn đang chọn thì ví nguồn trống (§2.9 C2).
4. Kết quả AI về sau khi bấm Huỷ bị bỏ (`luotDien`). Mọi kết quả về sau một lần chờ chỉ áp khi chiều, ghi chú, số tiền,
   ví, ngày, danh mục chưa đổi trong lúc chờ (phép so của `_loadSuggestion`, `_tinhDeXuat` hôm nay).
5. Thẻ gợi ý theo số tiền chỉ khi ghi chú **trống**, không ở đường sửa, không ở form biến động; chữ đầu vào ô ghi chú gỡ thẻ
   ấy ngay; bậc tiền đổi thì gợi ý đang chờ phân xử bị bỏ, không ghi phản hồi.
6. Phản hồi gợi ý ghi `unawaited` + bắt lỗi — hỏng không chặn chọn hay lưu.
7. D1: lần đầu một cặp nguồn + đuôi tài khoản thì ví **trống**; Lưu ở chuyển khoản đã áp gợi ý nhớ ví **theo phía** của mỗi
   nguồn; ảnh quét (A5) không đọc bảng nguồn → ví, không gợi ý chuyển khoản, không nhắc trùng.
8. Không có mã tài khoản thì không đọc ví, không gợi ý, không lưu — không bao giờ rơi về tài khoản 1 (G38).
9. Lưu: số tiền rút gọn từ biểu thức, không `replaceAll('.', '')` (A12); thứ tự chốt lỗi giữ nguyên; tách chỉ cho khoản chi
   tạo mới; một hộp *Vượt ngân sách* cho cả lô tách; tra ngân sách hỏng không chặn lưu.
10. Ảnh quét xoá ở **một** chỗ cho mọi đường thoát — nay là `close()` của Cubit, gọi từ `dispose` của trang.

### 4.3 `ThemGiaoDichNguon`

Lớp trừu tượng + bản thật trong cùng tệp (nếp `GanDanhMucNguon`), dựng từ các tham số khởi tạo của trang: tham số tiêm có
thì dùng, không thì `sl<…>()` như hôm nay. Hàm:

- `napViDangDung(id)` — `WalletRepository.getActiveRows` (viết **trên một dòng**, vì quét lối đọc ví nhận diện theo chuỗi).
- `napLichSu(id, {dangSua})` → bảng ví hay dùng, `BoPhanLoaiGhiChu?`, `BoPhanLoaiSoTien?`, mẫu đề xuất đường sửa — **một**
  lần đọc sổ như `_loadViHayDung` hôm nay; học lỗi trả `null` cho mô hình ấy.
- `docPhanHoi(id)`, `ghiPhanHoi(...)`.
- `napDanhMucVaTuKhoa(id)` (lỗi → rỗng), `luuTuKhoa(id, categoryId, ds)`.
- `viTheoNguon(id, nguon, duoi)`, `viTheoNguonChung(id, nguon)`, `nhoViTheoNguon(...)`.
- `hangBienDongCho(id)`, `khoanTrongSo(id)`, `xoaHangBienDong(id, khoa)`.
- `duongDanAnh(...)`, `docMonQuet(anh)`, `xoaAnhBienLai(anh)`, `xoaAnhQuet(anh)`.
- `traNganSach(id, categoryId)`.

Mỗi hàm giữ đúng cách nuốt lỗi của chỗ gọi hôm nay (`debugPrint` cùng tiền tố `[BienDong]`, `[GoiYDanhMuc]`, `[NhapNhanh]`…).

## 5. Luồng giữa trang và Cubit

Trang gọi hàm Cubit → Cubit phát state → trang vẽ lại bằng `BlocBuilder`. Cubit **không** biết `BuildContext`, không mở hộp
thoại, không gửi event cho `TransactionBloc`.

1. **Ô ghi chú.** Chữ ở `TextEditingController` của trang; listener gọi `cubit.ghiChuDoi(chu)`. Cubit tự đặt ghi chú (Nhập
   nhanh, biến động, C4) bằng `state.ghiChu`; trang nghe state và **chỉ chép sang ô khi hai bên khác nhau** — không vòng lặp.
2. **Cuộn tới thẻ gợi ý theo số tiền.** `state.soLanCuonGoiY` tăng khi thẻ nguồn số tiền vừa hiện hoặc đổi danh mục; trang
   thấy tăng thì cuộn sau khung hình (`keepVisibleAtEnd`, như `_cuonToiTheGoiY`). Không thêm luồng sự kiện riêng.
3. **Lưu.** `chuanBiLuu()` kiểm hợp lệ, dựng giao dịch (hoặc các phần tách), tra ngân sách qua nguồn, trả **một trong hai**:
   câu lỗi (trang báo toast) hoặc giao dịch sẵn sàng + tác động ngân sách (trang hỏi hộp thoại nếu cần, gọi `daGuiLuu`,
   gửi event cho `TransactionBloc`). `actionSuccess` → trang lấy `cauSauLuu()` cho toast, gọi `dongSauLuu()` (xoá hàng biến
   động, nhớ ví theo nguồn), rồi `pop(true)`.
4. **Thứ chỉ trang có:** mã tài khoản (hàm đọc phiên đưa vào Cubit, đọc ở **mỗi** lần cần như `_accountId` hôm nay — không
   chụp một lần lúc mở); bàn phím hệ thống mở hay không (trang tính rồi truyền vào `chamSoTien`, tự `unfocus`); quyền Premium
   của ô Nhập nhanh (ở lại trang, chỉ để vẽ); `context.watch<GoiCubit>()`.
5. **Hộp thoại và trang con** ở lại trang: chọn ngày, chọn ví (sheet), *Thêm phần* (sheet), `/add/category`, *Vượt ngân
   sách*. Kết quả của chúng đi vào Cubit qua hàm tương ứng.
6. **Vòng đời.** Trang dựng Cubit trong `initState` (bọc `BlocProvider.value`), gọi `moTrang()`, đóng Cubit trong `dispose`.

## 6. Ba test quét đổi đường dẫn

| Test | Đổi |
|---|---|
| `o_nhap_tien_co_tran_test.dart` ca *"bàn phím tự vẽ…"* | đọc `them_giao_dich_cubit.dart` thay trang; hai kỳ vọng giữ nguyên |
| `wallet_picker_sources_test.dart` | `laBoChonVi`: thay trang bằng `features/transaction/data/them_giao_dich_nguon.dart` |
| `tep_presentation_khong_qua_dai_test.dart` | rút dòng trang khỏi `mienTru` (bước 6) |

## 7. Thứ tự — sáu bước, mỗi bước một commit

Sau **mỗi** bước: `flutter test` các tệp dựng trang (24 tệp) xanh; cuối bước 2, 4, 6 chạy toàn phần + `flutter analyze`.

1. **Lớp nguồn.** Dời mọi đọc / ghi sang `ThemGiaoDichNguon`; trang vẫn `setState` nhưng gọi qua nguồn. Đổi `laBoChonVi`.
   Test `them_giao_dich_nguon_test.dart`.
2. **State + Cubit cho lõi form:** số tiền, bàn phím, chiều, ví, danh mục, chiều nợ, ngày. Trang đọc phần ấy từ state.
3. **Cụm gợi ý danh mục** sang Cubit (học hai mô hình, tập tắt, thẻ gợi ý, đề xuất từ khoá, phản hồi, cuộn tới thẻ).
4. **Cụm điền sẵn:** Nhập nhanh (AI, Huỷ), điền từ biến động / biên lai / ảnh quét, gợi ý chuyển khoản, nhắc trùng;
   `dienKetQua` công khai.
5. **Lưu và tách:** `chuanBiLuu` và các hàm sau lưu, phần tách, ngân sách. Đổi đường dẫn quét ô nhập tiền.
6. **Đóng sổ:** rút trang khỏi `mienTru`; đo; tài liệu (mục 10).

## 8. Test mới

Viết bằng `test` thường trên `cubit.state` và nguồn giả (không `bloc_test`). Mỗi ca thử bằng **một bản sai có chủ ý** — ca
xanh ngay từ đầu chỉ đáng tin sau khi bản sai làm nó đỏ.

- `test/features/transaction/presentation/bloc/them_giao_dich_cubit_test.dart` — mười bất biến mục 4.2, mỗi bất biến ít
  nhất một ca; thêm ca cho `chuanBiLuu` (thứ tự câu lỗi, giao dịch dựng đúng ở đường sửa giữ id / `goalId` / ảnh) và cho
  `close()` xoá ảnh quét.
- `test/features/transaction/data/them_giao_dich_nguon_test.dart` — `napLichSu` đọc sổ một lần và học lỗi trả `null`;
  `napDanhMucVaTuKhoa` lỗi trả rỗng; ví theo nguồn chỉ nhận ví đang dùng.
- Đường dẫn test soi gương `lib/` (quét 25).

## 9. Nghiệm thu

- `flutter test` toàn phần xanh; ca cũ chỉ đổi import và ba đường dẫn mục 6.
- `flutter analyze` không vượt mức nền **20**.
- Trang < 1.200 dòng, đã rút khỏi `mienTru`; Cubit < 1.200.
- Máy ảo `FlowMoney_16G` (`-gpu swangle`), tài khoản 10: gõ số và phép tính `+ −`, chạm khối số tiền ẩn / hiện 16 phím, Nhập
  nhanh (luật; câu chuyển ví), thẻ gợi ý theo ghi chú và theo số tiền (cuộn tới thẻ ở khổ 360 dp), đề xuất thêm từ khoá, chọn
  ví nguồn / đích, chọn ngày, chiều vay nợ, lưu, tách khoản (thêm / sửa / bỏ phần), sửa giao dịch, chặn vượt ngân sách. So
  ảnh trước / sau theo nếp đợt bịt điểm rò (pixel vàng bằng 0).
- Lượt OnePlus 13R gộp vào việc 1 (nghiệm thu) khi người dùng cắm máy.

## 10. Tài liệu phải đổi khi xong

- `docs/CLIENT_APP_KNOWN_GAPS.md` G88 gạch 1 → ✅ đóng, số đo sau đợt.
- `docs/KIEN_TRUC_CLIENT_APP.md` mục 9 (nợ có tên) và câu đếm Cubit (*"3 Bloc, 7 Cubit"* → 8 Cubit).
- `docs/PROJECT_CONTEXT.md` mục 14 — khối mới; `CLAUDE.md` hàng *Đụng vào presentation* (năm tệp miễn trừ → bốn; nơi C4
  cắm vào là `ThemGiaoDichCubit.dienKetQua`).
- `docs/BIEN_DONG_SO_DU_FEATURE.md`, `docs/QUET_ANH_FEATURE.md`, `docs/CATEGORY_RATIONALE.md`, `docs/AI_EDGE_FEATURE.md`:
  `grep` tên hàm riêng tư cũ của trang (`_dienKetQua`, `_dienTuCau`, `_loadSuggestion`, `_saveTransaction`…) và trỏ sang tên
  mới. Chép lại luật vào tài liệu là không cần — chỉ sửa chỗ trỏ.

## 11. Rủi ro và hoàn tác

| Rủi ro | Ứng phó |
|---|---|
| `setState` vẽ lại ngay, Cubit phát qua stream trễ một vi tác vụ — ca cũ đọc màn ngay sau chạm có thể lệch | Widget test luôn `pump` sau chạm; ca nào đỏ thì sửa mã (quyết định 2), không thêm `pump` vào test |
| Thứ tự ghi chú ↔ danh mục đổi khi ô ghi chú đồng bộ qua state (bất biến 3) | ca Cubit riêng cho thứ tự; ca widget `nhap_nhanh_test` đã canh |
| Hẹn giờ 300 ms trong Cubit chạy ngoài vùng `FakeAsync` của test | Cubit dựng trong `initState` của trang, tức trong vùng test — như `Timer` của State hôm nay; kiểm ở bước 3 |
| `copyWith` không xoá được về `null` → thẻ gợi ý hay ví "dính" | một cách xoá cho cả lớp (mục 4.1) + ca test đòi xoá được từng trường nullable |
| Một bước làm đỏ nhiều ca không rõ vì sao | mỗi bước một commit; `git revert` bước ấy, chia nhỏ hơn |
