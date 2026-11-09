# NCKH — Dự báo xác suất vượt ngân sách cuối kỳ

Đề tài NCKH sinh viên cấp trường (nhóm Nguyễn Phú Bảo, Trần Quang Đạt; GVHD ThS. Huỳnh Nam).
Tên (dạng 3 vế theo góp ý của thầy, 2026-11-09):

- **VI:** Nghiên cứu và phát triển mô hình dự báo xác suất dựa trên trung vị, EWMA và hồi quy phân vị nhằm cảnh báo sớm
  nguy cơ vượt ngân sách cuối kỳ từ nhịp chi tiêu cá nhân trong ứng dụng quản lý tài chính cá nhân.
- **EN:** Research and Development of Probabilistic Forecasting Models Based on Median, EWMA, and Quantile Regression for
  Early Warning of End-of-Period Budget Overruns in Personal Finance Management Applications.

Hạn: bản thảo khung bài nộp thầy 2026-11-09 23h; bài hoàn chỉnh (~10 trang khuôn IEEE, tiếng Anh) 2026-11-14.

## Thiết kế đã chốt (2026-11-09)

| Mục | Chốt |
|---|---|
| Bài toán | Tại ngày t của kỳ, ước lượng p = P(S_T > B); cảnh báo khi p ≥ p\* |
| Phương pháp | M0 chia đều (pro-rata) · M1 trung vị nhịp chi (= `nhip_chi.dart` của app, baseline) · M2 EWMA mức + phương sai theo ngày · M3 hồi quy phân vị gộp nhiều người (19 mức τ, sắp lại chống cắt nhau) |
| Dữ liệu | Berka / PKDD-99 (chính) + mô phỏng 4 kiểu người A1–A4 (phụ) |
| Ngân sách | Tổng theo tháng; B = κ × trung bình 3 tháng trước, κ ∈ {0,9; 1,0; 1,1} |
| Đánh giá | Rolling-origin theo tháng, mốc ngày 5/10/15/20/25; Brier, log loss, AUC, ECE, MAE, pinball; recall + lead time ở tỉ lệ báo nhầm 10 % / 20 %; bootstrap theo người dùng |
| Mã | Python (pandas, statsmodels) trong thư mục này; **không sửa `src/`** (mã đồ án đang chốt) |

## Tệp

- `paper/draft_paper.docx` / `.pdf`: bản thảo tiếng Anh (5 trang, số liệu để trống).
- `paper/draft_paper_vi.docx` / `.pdf`: bản tiếng Việt cùng khuôn, cùng nội dung.
- Chữ của hai bài ở `paper/content_en.js` và `paper/content_vi.js` (đã soát văn phong bằng skill `humanizer`, 2026-11-09);
  `paper/build_paper.js` chỉ giữ khuôn IEEE. Dựng: `NODE_PATH=<thư mục chứa node_modules/docx 9.x> node build_paper.js en|vi`
  (trên máy này: `C:/Users/tadd1/AppData/Local/Temp/flowmoney-dacta/node_modules`).
- `paper/make_figures.py`: vẽ Hình 1–2 cho cả hai ngôn ngữ (SVG → PNG bằng `pymupdf`); Hình 2 là chuỗi minh hoạ tự dựng,
  không phải dữ liệu thật.

## Thực nghiệm (`experiment/`, chạy 2026-11-09)

- Dữ liệu Berka: tải `trans.asc`, `account.asc` từ `https://github.com/ldaniel/R_Bank_Berka` (thư mục `data/`) vào
  `data/raw/` (gitignore; SHA-256 ghi trong `experiment/berka.py`).
- `core.py` (M0–M3, đánh giá cuốn chiếu, chỉ số) · `sim.py` (tập mô phỏng) · `berka.py` (nạp Berka) ·
  `run_synthetic.py` · `run_berka.py [--nofixed]` (biến môi trường `M3_ROWS`, `KAPPAS` cho phép kiểm độ nhạy) ·
  `bootstrap.py` · `plots.py <nguồn> <số hình>` (`python plots.py berka 3,4`, `python plots.py synthetic 5,6`).
- Kết quả: `experiment/results/*.json`. Tóm tắt (κ = 1,0, lưới λ mở rộng 2026-11-09): Berka M1 Brier 0,169 · M3 0,172 · M0 0,180 ·
  M2 0,211; M3 hiệu chuẩn tốt nhất (ECE 0,040); bootstrap M3 − M1 = +0,0018 [0,0010; 0,0025]; bỏ khoản cố định thì M3
  thắng. Mô phỏng: M3 0,125 thắng rõ. λ chọn: Berka 0,002 · bỏ cố định 0,005 · TabFormer 0,01 · mô phỏng 0,01
  (`lambda_scan.py`; lưới cũ dừng ở 0,02 là biên). Chạy lại toàn bộ: `sh rerun_all.sh` (~25 phút). Phần lõi mới tái lập đúng 1.060/1.060 giá trị của lượt mô phỏng đầu.
- **Đối chiếu M1 với mã app** (2026-11-09): `python -u export_cases.py 20000 7` (20.000 ca Berka, K ≥ 3) →
  `dart run dart_check/doi_chieu.dart` (chạy thẳng `src/Client-app/lib/features/budget/domain/nhip_chi.dart`, import
  theo đường dẫn, không sửa `src/`) → `python -u compare_m1_dart.py` → `results/m1_compare.json`. Khoản chi đặt lúc
  23:59:59: r_med, phần đã chi, K và quyết định vượt khớp **20.000/20.000**. Đặt lúc 00:00 thì r_med lệch ở 18,8 % ca
  (quyết định lệch 2,9 %), lúc 12:00 lệch 8,0 % (1,2 %): app tính theo giờ ghi, Python theo cuối ngày. App chỉ cho dự
  phóng điểm `S + r_med`; xác suất p1 là phần bài thêm vào — `p1 > 0,5` trùng quyết định của app 100 % khi K lẻ,
  94,4 % khi K chẵn (trung vị chẵn = trung bình hai giá trị giữa; 91,9 % ca có K chẵn).
- **Tập thứ ba: IBM TabFormer** (2026-11-09, mô phỏng, Apache-2.0, tải `transactions.tgz` từ `https://github.com/IBM/TabFormer`
  `data/credit_card` vào `data/raw/tabformer/`; SHA-256 trong `experiment/tabformer.py`). Lấy 01/2015 – 01/2020 (bỏ 02/2020 thiếu
  ngày), chi = số tiền > 0 và không gian lận, gộp mọi thẻ của một người, ≥ 18 tháng; bỏ 27 người ngừng chi sớm → 1.518 người.
  `python -u run_tabformer.py` (~8 phút) · `python -u bootstrap.py tabformer` · `profile_tabformer.py` (thống kê mô tả).
  κ = 1,0 (310.973 dự báo, tỉ lệ vượt 44,3 %): Brier M3 **0,148** · M2 0,149 · M1 0,166 · M0 0,177; ECE M3 0,005 · M2 0,024 ·
  M1 0,030; M3 − M1 = −0,0177 [−0,0184; −0,0171], M3 hơn ở 94 % người; M3 thắng cả ba κ, M2 sát nút. Ở báo nhầm ≤ 10 %:
  M3 77 %, M2 78 %, cùng sớm 12 ngày; M1 68 %, 9 ngày. λ = 0,01. Đối chiếu Dart (`export_cases.py tabformer` → `doi_chieu.dart tabformer`
  → `compare_m1_dart.py tabformer`): 23:59:59 khớp 20.000/20.000; **giờ thật** của giao dịch → r_med lệch 57,5 % ca (trung vị
  ~1 % ngân sách), quyết định lệch 2,1 %.

Xuất PDF: mở .docx bằng Word → Save As PDF (hoặc Word COM `ExportAsFixedFormat`).
