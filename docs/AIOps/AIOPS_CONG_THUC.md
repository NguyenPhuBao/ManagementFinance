# AIOps — Đặc tả công thức và đo lường

Cập nhật: 2026-11-17. Mã nguồn: `src/Backend/modules/aiops/aiops.formulas.js` (hàm thuần), `anomaly.detector.js`, `feature.collector.js`, `aiops.service.js`. Test: `tests/unit/aiops.formulas.test.js`, `aiops.detector.formulas.test.js`, `aiops.measurement.test.js`, `aiops.service.formulas.test.js`.

Ký hiệu:
- **N**: số người dùng đồng thời quản trị viên nhập ("Quy mô người dùng").
- **RPM**: số yêu cầu mỗi phút.
- **Cửa sổ**: chu kỳ lấy mẫu 10 giây.
- **A / T / T_nặng**: ngưỡng chú ý / ngưỡng cảnh báo / mức nghiêm trọng của một tín hiệu.

## 1. Nguồn sự thật duy nhất

Mọi ngưỡng và số dẫn xuất do Backend tính. `AnomalyDetector.getEffectiveThresholds()` trả về `indicators`, gồm đúng các con số `evaluate()` đang dùng. `indicators` có mặt trong `GET /admin/aiops/status`, trong socket `admin.security_alert`, và trong kết quả `setConcurrencyScale` / `calibrate`. Admin-web chỉ hiển thị, không tự tính lại.

## 2. Đo lường (mỗi cửa sổ)

| Chỉ số | Cách đo |
|---|---|
| `requestCount` | số yêu cầu đến trong cửa sổ |
| `completedCount` | số yêu cầu đã hoàn tất (sự kiện `finish`) |
| `requestsPerMin` | `requestCount × 60 / số giây thực của cửa sổ` |
| `cpuMs` | thời gian CPU tiến trình trong cửa sổ, đo bằng `process.cpuUsage()` (gồm cả luồng phụ) |
| `eventLoopLagMs` / `eventLoopLagMaxMs` | p99 / giá trị lớn nhất của độ trễ vòng lặp sự kiện trong cửa sổ, đo bằng `perf_hooks.monitorEventLoopDelay` (độ phân giải 20 ms, đã trừ chu kỳ đo) |
| `ramPercent` | RAM tiến trình = RSS / hạn mức bộ nhớ × 100; hạn mức = quota container nếu có, ngược lại tổng RAM máy. RAM toàn máy chỉ giữ để tham khảo (`hostPercent`) |
| `warmingUp` | 45 giây đầu sau khởi động. Trong giai đoạn này độ trễ không được chấm điểm và cửa sổ không dùng cho ước lượng năng lực |

Chỉ `tick()` (10 giây một lần) được chốt cửa sổ (`getSample`). Đọc trạng thái, hiệu chuẩn, bật/tắt vectơ và chụp snapshot đều dùng `peekSample()` hoặc mẫu đã chốt gần nhất, không xoá bộ đếm.

## 3. Đường nền và ngưỡng lưu lượng

**Đường nền theo giờ (B1).** Tính lại mỗi giờ và khi khởi động, từ `aiops_metric_snapshot` của 7 ngày gần nhất:
```
RPM_nền(h) = trung vị { requests_per_min của snapshot có is_anomaly = false, giờ VN = h }
```
- `h`: giờ trong ngày theo giờ Việt Nam. Giờ VN được tính trong JS sau khi đọc, vì cột `recorded_at` không có múi giờ.
- Giờ `h` đủ ≥ 24 mẫu thì dùng trung vị của chính giờ đó (nguồn `history`).
- Không đủ thì dùng trung vị mẫu sạch của 24 giờ gần nhất, nếu có ≥ 12 mẫu (nguồn `recent`).
- Nếu vẫn không đủ thì dùng ước tính `N × r`, với `r = 2` yêu cầu/phút/người (nguồn `estimate`). Con số `r` là giả định: app đồng bộ định kỳ 15 phút một lần, cộng các lần đẩy sau thao tác.

**Ngưỡng cảnh báo (B2):**
```
T = max(3 × RPM_nền, 1,5 × P95, 300)
```
- `P95`: phân vị 95 của cùng tập mẫu ở B1.
- 300: mức sàn, tránh báo động khi hệ thống gần như không có tải.
- Quản trị viên đặt `trafficSpikeRps` thì `T = trafficSpikeRps × 60`, ghi đè công thức.

**Mốc của tín hiệu lưu lượng:**
- `A = max(1,5 × RPM_nền, 0,5 × T)`. Mức sàn 0,5 × T tránh A ≈ 0 khi lịch sử toàn mẫu rỗi.
- `T_nặng = 2 × T`.

## 4. Điểm rủi ro (B3)

```
        ⎧ 0                                         x ≤ A
s(x) =  ⎨ min(69, 70 × (x − A) / (T − A))           A < x < T
        ⎩ 70 + 30 × min(1, (x − T) / (T_nặng − T))   x ≥ T
```
Bất biến: **s ≥ 70 khi và chỉ khi x ≥ T**. Điểm vượt ngưỡng cảnh báo luôn đi kèm việc ghi sự cố.

| Tín hiệu (mỗi cửa sổ) | A | T (mặc định) | T_nặng | Khi tuỳ chỉnh T |
|---|---|---|---|---|
| Đăng nhập sai | 5 | 15 | 30 | A = T/3, T_nặng = 2T |
| Token bị dùng lại | 1 | 5 | 10 | không tuỳ chỉnh |
| Yêu cầu độc hại | 1 | 8 | 20 | A = 1, T_nặng = 2,5T |
| Độ trễ vòng lặp p99 (ms) | 100 | 250 | 400 | A = 0,4T, T_nặng = 1,6T |
| CPU (%) | 70 | 85 | 95 | A = T − 15, T_nặng = min(100, T + 10) |
| RAM tiến trình (%) | 80 | 92 | 97 | A = T − 12, T_nặng = min(100, T + 5) |
| Tỷ lệ lỗi 5xx (khi ≥ 10 yêu cầu) | 0,02 | 0,10 | 0,25 | không tuỳ chỉnh |
| Lưu lượng (RPM) | mục 3 | mục 3 | 2T | `trafficSpikeRps` |

Nếu A ≥ T thì đặt A = T/2.

- **Dấu hiệu tấn công lưu lượng (B4):** có một trong ba điều kiện sau: IP gửi nhiều nhất chiếm ≥ 50% số yêu cầu của cửa sổ; tỷ lệ 4xx ≥ 25%; có yêu cầu độc hại. Không có dấu hiệu thì điểm lưu lượng bị chặn trên ở 40 (chỉ ELEVATED) và không ghi sự cố.
- **Điểm vectơ** = điểm lớn nhất trong các tín hiệu của vectơ. Vectơ tài nguyên cộng thêm `10 × (k − 1)` khi có k ≥ 2 chỉ số cùng ≥ 70.
- **Điểm tổng** = `min(100, max điểm các vectơ đang bật + 8 × (m − 1))`, với m là số vectơ ≥ 70.
- **Băng trạng thái:** 40 ELEVATED, 70 WARNING, 85 CRITICAL. Bảo trì khẩn cấp chỉ được đề xuất khi vectơ tài nguyên ≥ 85 và có ít nhất hai trong ba chỉ số độ trễ / RAM / 5xx cùng ≥ 70.
- **Ngưỡng chặn một IP:** cố định 150 yêu cầu/10 giây, không phụ thuộc N. Đổi được qua biến `AIOPS_IP_BURST_PER_10S`.

## 5. Hiệu chuẩn và năng lực (B5)

**Luật sử dụng** U = X × S (U: mức sử dụng, X: thông lượng, S: thời gian phục vụ mỗi yêu cầu). Mỗi cửa sổ không ở giai đoạn khởi động góp một điểm (C_i, R_i) vào bộ nhớ, tối đa 360 cửa sổ (khoảng 1 giờ):
```
C_i ≈ C₀ + S × R_i                      (bình phương nhỏ nhất)
X_max = (10 000 × min(1, Q) × U_max − C₀) / S      (yêu cầu / 10 giây)
RPM_tối_đa = 6 × X_max
```
- `C_i`: ms CPU tiến trình trong cửa sổ i.
- `R_i`: số yêu cầu hoàn tất trong cửa sổ i.
- `S`: ms CPU cho mỗi yêu cầu.
- `C₀`: CPU nền mỗi cửa sổ khi không có yêu cầu.
- `Q`: hạn mức CPU cứng (`cpu.max`, `cfs_quota_us`, `CLOUD_CPU_CORES`; cờ `cpuQuotaHard`). `cpu.shares` / `cpu.weight` và giá trị dự phòng 0,15 nhân trên Render không phải giới hạn cứng, khi đó Q = 1. Lấy `min(1, Q)` vì một tiến trình Node chỉ dùng 1 nhân cho JavaScript.
- `U_max = 0,7`: mức sử dụng mục tiêu. Theo mô hình hàng đợi M/M/1, thời gian chờ tỷ lệ với ρ/(1−ρ): tại ρ = 0,7 thời gian chờ khoảng 2,3 lần thời gian phục vụ.

**Điều kiện tin cậy:** ≥ 30 cửa sổ, ≥ 10 cửa sổ có yêu cầu, `P90(R) ≥ 2 × P10(R)`, và S > 0. Không đạt thì kết quả là `INSUFFICIENT_DATA` và không đưa ra con số.

**Đánh giá:**
- `T ≤ RPM_tối_đa`: OPTIMAL.
- `T ≤ RPM_tối_đa / U_max`: WARNING.
- Còn lại: OVER_CAPACITY.

**Chỉ báo hiện trạng, không dự báo:**
- RAM: RSS / hạn mức; heap / `heap_size_limit`.
- CSDL: số kết nối đang dùng / kích thước pool.

**Quy đổi ra người dùng** `RPM_tối_đa / r` chỉ để tham khảo, gắn nhãn "ước tính".

**Hiệu chuẩn:**
- Chỉ gộp các ngưỡng được gửi lên; ô để trống giữ nguyên ngưỡng đang dùng.
- **Về mặc định:** gửi `resetThresholds: true` (cùng route `POST /admin/aiops/calibrate`, PIN). Backend xoá mọi ngưỡng tuỳ chỉnh và lưu trạng thái rỗng vào `aiops_setting`, rồi trả ngưỡng mặc định. Ngưỡng lưu lượng quay về công thức ở mục 3.
- Lưu `custom_vector_thresholds`, `target_concurrency` và `capacity_estimate` vào `aiops_setting`. Khởi động lại sẽ nạp lại.
- Không xoá đường nền, không chốt cửa sổ đo.

**Giới hạn:** phương pháp chỉ ước lượng nút cổ chai CPU của tiến trình Node. Năng lực CSDL và các dịch vụ ngoài (thanh toán, AI) không được ước lượng. Muốn kiểm chứng thì chạy thử tải trên môi trường thử riêng và so `RPM_tối_đa` với mức tải tại đó độ trễ p99 vượt 250 ms.
