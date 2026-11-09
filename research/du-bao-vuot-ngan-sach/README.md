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
- Kết quả: `experiment/results/*.json`. Tóm tắt (κ = 1,0): Berka M1 Brier 0,169 · M3 0,171 · M0 0,180 · M2 0,225;
  M3 hiệu chuẩn tốt nhất (ECE 0,035); bootstrap M3 − M1 = +0,0012 [0,0005; 0,0019]; bỏ khoản cố định thì M3 thắng.
  Mô phỏng: M3 0,126 thắng rõ. Phần lõi mới tái lập đúng 1.060/1.060 giá trị của lượt mô phỏng đầu.

Xuất PDF: mở .docx bằng Word → Save As PDF (hoặc Word COM `ExportAsFixedFormat`).
