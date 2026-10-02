# Dự án B — mô hình nhỏ định tuyến câu hỏi → tool — thiết kế

**Ngày:** 2026-10-02. **Người dùng duyệt** thiết kế trong chat (brainstorm, năm lượt AskUserQuestion). Đây là dự án
thứ hai trong ba dự án huấn luyện A → B → C (mục 10.3 `docs/AI_EDGE_FEATURE.md`; lộ trình
`plans/2026-09-30-lo-trinh-con-lai.md` giai đoạn 3). Dự án A dừng ở spike tra cứu (mục 10.6); B không phụ thuộc A.

## 1. Vì sao

Màn Trợ lý AI trả lời bằng **bậc tool**: mô hình trên máy (Gemma 4 E2B) chọn tool, điền tham số, rồi viết câu từ kết
quả. Phiên có hai dạng:

- **Phiên sáu tool** — mô hình tự chọn một trong sáu tool. Realme (CPU), mốc 72 câu (mục 9.37): chờ trung bình
  **45,5 s**, lượt sinh đầu 37,3 s.
- **Phiên một tool** — tầng mã đã biết tool đích (`congCuTheoCauHoi`), phiên chỉ khai tool ấy
  (`BoCongCu.khaiBaoCho`). Cùng mốc: chờ **23,8 s**, lượt sinh đầu 14,3 s.

Ngoài thời gian chờ, phiên một tool còn hai lợi ích đã đo: prompt ngắn thì mô hình viết đúng chuỗi số (bẫy 4.51), và
đường đi **không phụ thuộc máy** — cùng một câu, GPU và CPU từng gọi hai tool khác nhau (mục 9.43).

`congCuTheoCauHoi` là chuỗi luật viết tay (`ai_edge/domain/chinh_tham_so.dart:623`). Trên bảng 72 câu
(`test/features/ai_edge/domain/dinh_tuyen_72_cau_test.dart`, đếm bằng máy 2026-10-02) nó định tuyến **31** câu và trả
`null` cho **41** câu. Đọc bảng mốc 72 câu thì 41 câu ấy gồm:

| Nhóm | Số câu | Mã câu |
|---|---|---|
| `truy_van_giao_dich` trả lời | 37 | A8 · A9 · DC2 · C1–C20 · DC3 · E2–E6 · E13 · E15–E17 · E19 · F1–F3 |
| Ngoài phạm vi | 4 | DC1 · E21 · E22 · F16 |

⚠️ Nhãn của 37 câu suy từ **câu trả lời** trong bảng mốc, chưa đối chiếu log tool gốc (`congF_tron_ketqua.txt`,
scratchpad phiên `de8f6403…`). Khi thi công: còn tệp ấy thì đối chiếu, không còn thì ghi rõ nhãn lấy theo câu trả lời.

Tức việc chính của dự án là **nhận ra câu giao dịch** — thứ luật không làm được, vì với luật câu giao dịch là "phần
còn lại sau khi mọi luật khác im" — mà **không kéo nhầm** câu ngoài phạm vi hay câu của tool khác vào tool giao dịch.

## 2. Năm quyết định người dùng chốt

| # | Câu hỏi | Chốt | Hệ quả |
|---|---|---|---|
| 1 | Bộ đo lấy từ đâu | **Tôi soạn cả hai bộ, khoá bộ đo trước** | Bộ đo viết và commit trước bộ huấn luyện, không sửa về sau. ⚠️ Hai bộ cùng một người soạn nên số đo **lạc quan hơn thực tế** — mọi chỗ trích số đo phải kèm câu này |
| 2 | Mô hình đứng đâu so với luật | **Luật trước, mô hình sau** | Luật giữ nguyên; mô hình chỉ xét câu luật trả `null`. 31 câu đã đo không đổi đường. Thêm một tầng, không bớt tầng nào |
| 3 | Bộ nhãn | **Chín tool + `khong_dinh_tuyen`** | Mười nhãn. Nhãn âm dẫn về phiên sáu tool như hôm nay; mô hình **không chặn** câu nào (chặn là việc của `chuDeBiChan`) |
| 4 | Loại mô hình | **Huấn luyện cả hai, chọn bằng số đo** | Naive Bayes và hồi quy logistic, cùng dữ liệu và đặc trưng; chỉ một mô hình vào app |
| 5 | Thiết kế tổng | **Duyệt** | Gồm việc trọng số là tệp Dart sinh ra, không phải asset (lệch chữ của lộ trình — mục 4.3) |

Hai điểm lấy theo nếp dự án, không hỏi riêng: ngưỡng tin cậy ưu tiên **không sai** hơn phủ nhiều; huấn luyện bằng
script Dart trong `test/tool/`, **không thêm gói**.

## 3. Luồng

```
câu hỏi ─► coVeLenhTao (C3) ─► chuDeBiChan ─► dinhTuyenCauHoi ─► hoiBangCongCu
                                                │
                              congCuTheoCauHoi ─┤ có tool ─► phiên một tool, nguồn = luật
                                   (luật, cũ)   │
                                                └ null ─► BoDinhTuyenHoc.doan
                                                            ├ nhãn tool ∧ p ≥ ngưỡng ─► phiên một tool, nguồn = moHinh
                                                            └ còn lại ─► phiên sáu tool (như hôm nay)
```

Hàm mới `dinhTuyenCauHoi(cauHoi)` — thuần, đồng bộ — trả `({String? ten, NguonDinhTuyen nguon, double? xacSuat})`.
`vong_lap_cong_cu.dart:61` gọi nó thay cho `congCuTheoCauHoi` và ghi một dòng log:
`[SLM][tool] định tuyến: luật → X` · `mô hình → X (p=0,93)` · `không (mô hình: Y p=0,41)`.

### 3.1 ⚠️ Định tuyến bằng mô hình là định tuyến MỀM

Với câu **luật** định tuyến, vòng lặp hiện có hai hành vi "ép" (`vong_lap_cong_cu.dart:137`, `:190`):

- mô hình không gọi tool nào → tự chạy tool đích với `{}` rồi hiện mẫu câu;
- mô hình gọi tool khác → đổi sang tool đích với `{}`.

Hai hành vi ấy **không áp** cho câu do mô hình nhỏ định tuyến. Ở nguồn `moHinh`, định tuyến chỉ làm **một** việc: thu
phiên về một tool. Mô hình không gọi tool thì đi bậc 1 (L1) như phiên sáu tool hôm nay; gọi tên tool không có thì nhận
lời báo lỗi như hôm nay.

Lý do: luật là thứ đã đo trên máy thật, mô hình nhỏ thì chưa. Một câu chào bị định tuyến nhầm sang tool giao dịch, nếu
ép chạy với `{}`, sẽ nhận *"chưa tra được số liệu: thiếu kỳ"* (`ky` là tham số bắt buộc, cố ý không mặc định tháng
này) — trong khi định tuyến mềm để Gemma tự từ chối gọi tool và trả lời bình thường. Trần thiệt hại của một lần định
tuyến sai vì thế là: Gemma chỉ thấy một tool và **vẫn gọi** nó cho câu không thuộc nó.

## 4. Mô hình

### 4.1 Đặc trưng

Câu → `removeVietnameseTones(normalizeCategoryName(...))` (cùng phép `_bo` của `chinh_tham_so.dart`) → tách ở mọi ký
tự không phải chữ / số → âm tiết nào **có chữ số** đổi thành một ký hiệu chung (`500k`, `1/9`, `5` cùng là "một con
số") → đặc trưng là **âm tiết đơn** và **cặp âm tiết liền nhau**, nhị phân (có / không). Từ vựng chỉ giữ đặc trưng xuất
hiện ≥ 2 lần trong bộ huấn luyện; đặc trưng lạ lúc đoán thì bỏ qua.

Hai hệ quả phải ghi:

- **Bỏ dấu trước khi học**, nên câu có dấu và câu không dấu là **một** mẫu. Bộ dữ liệu khử trùng trên dạng đã chuẩn
  hoá; viết hai dạng của cùng một câu không thêm thông tin. (Trong chat tôi nói *"nửa có dấu nửa không dấu"* — sai, bỏ.)
  Lỗi gõ Telex (`muaxxe`, `tesst`) thì vẫn là mẫu khác.
- **Tên riêng** (tên mục tiêu, ví, hoá đơn) không che được lúc đoán vì hàm thuần không đọc CSDL. Bộ huấn luyện dùng
  tên **đa dạng** để tên không thành tín hiệu của một nhãn.

### 4.2 Hai ứng viên

- **Naive Bayes đa thức nhị phân hoá**, làm trơn Laplace — khuôn B1 (`category/domain/phan_loai_ghi_chu.dart`).
- **Hồi quy logistic đa lớp** (softmax), phạt L2, hạ gradient toàn lô, số vòng cố định, **khởi tạo 0** — bài toán lồi
  nên không cần hạt giống ngẫu nhiên, chạy lại ra cùng trọng số.

So bằng **kiểm chéo 5 phần** trên bộ huấn luyện. Phần của mỗi câu gán tất định (theo mã băm của dạng chuẩn hoá), không
ngẫu nhiên. Ba con số cho mỗi mô hình, tính trên dự đoán ngoài-phần:

1. độ chính xác (mười nhãn);
2. **số câu định tuyến sai** ở ngưỡng của nó — câu được định tuyến (nhãn tool ∧ p ≥ ngưỡng) sang tool **khác** nhãn
   đúng, kể cả câu nhãn đúng là `khong_dinh_tuyen`;
3. **độ phủ** ở ngưỡng ấy — phần câu mang nhãn tool được định tuyến đúng.

**Ngưỡng** của mỗi mô hình: mức thấp nhất trên lưới 0,50 → 0,99 mà kiểm chéo có **0** câu định tuyến sai, cộng đệm
0,05, kẹp trong [0,60; 0,99]. Không mức nào cho 0 sai → mô hình ấy bị loại; cả hai bị loại → **dừng, báo người dùng**,
không đưa gì vào app.

**Chọn:** ít câu định tuyến sai hơn → phủ cao hơn → hoà thì Naive Bayes (đơn giản hơn, trọng số đọc được).

### 4.3 Trọng số

Script sinh `lib/features/ai_edge/domain/trong_so_dinh_tuyen.g.dart`: loại mô hình, ngưỡng, danh sách nhãn, từ vựng,
ma trận trọng số, và **mã băm của bộ huấn luyện** đã sinh ra nó.

- **Tệp Dart, không phải asset** (lộ trình ghi *"trọng số vào assets"*; người dùng duyệt đổi): hàm định tuyến giữ
  được tính đồng bộ và thuần, bảng 72 câu chạy không cần dựng gì, và không có ca *"nạp asset hỏng thì im lặng thôi
  định tuyến"*.
- ⚠️ Từ vựng lưu thành **một chuỗi tách lúc chạy** — test quét 14 (`ai_edge_khong_tinh_test.dart`) cấm chuỗi `'chi'`,
  `'thu'` đứng riêng trong `ai_edge/`, và hai âm tiết ấy chắc chắn có trong từ vựng. Cùng mẹo `_tuChi` đang dùng.
- Cỡ ước lượng: vài trăm đặc trưng × mười nhãn, vài chục KB mã nguồn. Đo lại khi sinh.

## 5. Dữ liệu

Cả hai bộ ở `test/tool/dinh_tuyen/`, dạng TSV `nhãn ⇥ câu`, **không vào bản app**.

| Bộ | Cỡ | Nguồn | Luật |
|---|---|---|---|
| `bo_do.tsv` | ~60 câu | tôi soạn | Viết và commit **trước** bộ huấn luyện, cùng commit với test so mã băm tệp. Mỗi tool ≥ 4 câu, giao dịch ~18, `khong_dinh_tuyen` ~12 |
| `bo_huan_luyen.tsv` | 72 câu đã đo + 350–450 câu soạn | bảng 72 + tôi soạn | Mỗi nhãn ≥ 30 câu sau khử trùng; có lỗi gõ Telex; có câu *suýt nhầm* lấy từ danh sách loại trừ của luật (*"ghi chú hoá đơn"*, *"ví tiền mặt chi những gì"*, *"lần cuối nạp tiền cho mục tiêu"*) |

Nhãn của một câu = tool **trả lời đúng** câu ấy. `khong_dinh_tuyen` gồm: ngoài phạm vi (thời tiết, giá vàng, kiến
thức chung), chào hỏi / cảm ơn, câu mơ hồ, và **câu cần hai tool** — phiên một tool không gọi được tool thứ hai.

Test vệ sinh dữ liệu: không câu nào của bộ đo trùng (sau chuẩn hoá) một câu của bộ huấn luyện; mỗi nhãn đủ số câu
tối thiểu; nhãn nào cũng thuộc mười nhãn.

## 6. Quy trình đo và cổng ra

Thứ tự bắt buộc: bộ đo (commit) → bộ huấn luyện → kiểm chéo, chọn mô hình và ngưỡng → sinh trọng số → **mở bộ đo
đúng một lần** → đo máy.

**Trên bộ đo** chấm **đường ghép** (luật trước, mô hình sau — đúng thứ chạy trong app) và ghi kèm số của mô hình đứng
riêng. Kết quả ghi nguyên. Mục tiêu là 0 câu định tuyến sai; nếu có, được sửa dữ liệu huấn luyện / ngưỡng rồi đo lại,
nhưng **mọi lần đo sau lần đầu ghi là "đã nhìn bộ đo"**. Câu mà chính **luật** định tuyến sai trên bộ đo thì ghi riêng
và báo người dùng — sửa luật nằm ngoài phạm vi dự án này.

**Cổng ra:**

1. 31 câu đang theo luật không đổi đường — `kBang72Cau` hiện có giữ nguyên và vẫn xanh.
2. 4 câu ngoài phạm vi của 72 (DC1 · E21 · E22 · F16) không bị định tuyến.
3. Không câu nào của 72 bị định tuyến sang tool khác tool đã trả lời đúng nó ở mốc 72 — bảng 72 thêm cột đường ghép.
4. Trên máy đang cắm: các câu của 72 **đổi đường** đo **trước và sau, cùng máy, cùng ngày, cùng dữ liệu** (bản trước
   = HEAD chưa có B). Chấm theo câu trả lời hiện ra: không câu nào tụt, **SAI 0**, ghi thời gian chờ hai bên. Máy hiện
   cắm là OnePlus (GPU); con số 45,5 → 23,8 s là của Realme (CPU) nên đo Realme khi máy ấy cắm, và ghi rõ máy trong
   bảng. Đáp án tính theo dữ liệu trên máy lúc đo — dữ liệu đã đổi so với 28/09.
5. Test canh trọng số không cũ hơn dữ liệu: mã băm trong tệp `.g.dart` bằng mã băm `bo_huan_luyen.tsv` hiện tại.

⚠️ 72 câu **nằm trong** bộ huấn luyện, nên cổng 1–3 là phép canh hồi quy chứ không đo khả năng tổng quát. Phép đo
tổng quát duy nhất là bộ đo khoá, và nó mang giới hạn ở quyết định 1.

⚠️ Rủi ro phải nhìn khi đo: ở phiên một tool, Gemma từng điền **thừa tham số** (F12, họ bẫy 4.44). 37 câu giao dịch
chuyển sang phiên một tool là 37 chỗ điều ấy có thể lặp lại; `chinhThamSoTimGiaoDich` là lưới hiện có. Câu tụt vì lý
do này thì ghi và hỏi người dùng — không tự mở rộng bộ chỉnh trong dự án này.

## 7. Vị trí mã

| Tệp | Việc |
|---|---|
| `lib/features/ai_edge/domain/dinh_tuyen_hoc.dart` | `dacTrungCua(cau)`; `BoDinhTuyenHoc` — phép **đoán** của cả hai loại mô hình từ một bộ trọng số (script huấn luyện gọi lại chính nó để dự đoán ngoài-phần — một phép đoán, không hai) |
| `lib/features/ai_edge/domain/trong_so_dinh_tuyen.g.dart` | sinh ra — không sửa tay |
| `lib/features/ai_edge/domain/dinh_tuyen.dart` | `dinhTuyenCauHoi`, `NguonDinhTuyen` |
| `lib/features/ai_edge/data/vong_lap_cong_cu.dart` | gọi `dinhTuyenCauHoi`; hai hành vi "ép" chỉ khi nguồn là luật; dòng log |
| `test/tool/dinh_tuyen/huan_luyen.dart` | phép **học** (đếm của Naive Bayes, hạ gradient của logistic), kiểm chéo, chọn ngưỡng — không vào `lib/` |
| `test/tool/dinh_tuyen/huan_luyen_dinh_tuyen_test.dart` | `skip`, chạy tay `--run-skipped`: in bảng so sánh, ghi tệp `.g.dart` |
| `test/tool/dinh_tuyen/bo_do.tsv` · `bo_huan_luyen.tsv` | dữ liệu |
| `test/features/ai_edge/domain/dinh_tuyen_72_cau_test.dart` | thêm cột đường ghép |
| `test/features/ai_edge/domain/dinh_tuyen_hoc_test.dart` · `dinh_tuyen_test.dart` · `dinh_tuyen_du_lieu_test.dart` | đặc trưng; phép đoán; đường ghép; bộ đo khoá (mã băm); vệ sinh dữ liệu; trọng số không cũ |
| `test/features/ai_edge/data/vong_lap_cong_cu_test.dart` | ca định tuyến mềm: nguồn `moHinh` + không gọi tool → L1, không tự chạy tool |

`congCuTheoCauHoi` **không sửa một dòng**. `tools_json`, lời hệ thống, schema, payload, `pubspec` không đổi.

## 8. Ngoài phạm vi

Học theo từng người dùng (dự án C) · sửa hay bớt luật hiện có · đổi lời hệ thống · thêm tool · mở rộng bộ chỉnh tham
số · định tuyến câu cần hai tool · tinh chỉnh Gemma (dự án A2).

## 9. Câu hỏi còn mở

- Bộ đo do tôi soạn. Nếu sau này người dùng gõ 30–40 câu thật thì đó là phép đo đáng tin hơn — chạy lại bằng đúng
  script, không đổi mã.
- Chưa biết Gemma ở phiên một tool `truy_van_giao_dich` điền tham số tốt hơn hay kém hơn phiên sáu tool; cổng 4 là
  phép đo trả lời.
- Thời gian chờ trên OnePlus vốn ngắn (GPU, vài giây mỗi câu) nên lợi ích về giây ở máy này sẽ nhỏ; lợi ích lớn nằm ở
  máy CPU.
