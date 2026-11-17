# AIOps: chuẩn hoá công thức và đo lường

Ngày: 2026-11-17 · Nhánh: `NguyenPhuBao` · Phạm vi: `src/Backend/modules/aiops`, `src/Backend/core/resilience`, `src/Admin-web/src/pages/system/aiops`. Không đụng Client-app, không migration.

- **Phần A**: đã được Chủ dự án duyệt, giao FullStack thi công.
- **Phần B**: đề xuất công thức, **chờ Chủ dự án duyệt**. Chưa được làm.

Ký hiệu dùng chung:
- **N**: số người dùng đồng thời mà quản trị viên nhập ở mục "Quy mô người dùng".
- **RPM** (requests per minute): số yêu cầu mỗi phút.
- **Cửa sổ**: chu kỳ lấy mẫu 10 giây của `FeatureCollector`.

---

## Phần A: thi công ngay (đã duyệt)

### Ràng buộc chung
- Test viết trước, phải ĐỎ, sau đó code tối thiểu cho XANH. Không sửa test cho khớp code.
- Backend chỉ chạy test qua npm: `cd src/Backend && npm run test:unit`. Admin-web: `cd src/Admin-web && npm test`.
- Không commit, không push. Không động vào Supabase. Không migration.
- Ở phần A **giữ nguyên các công thức tính điểm và ngưỡng mặc định** hiện có. Phần A chỉ chuyển nơi tính, sửa cách đo và sửa chỗ hiển thị. Công thức mới thuộc phần B.
- Payload `/aiops/status` chỉ được **thêm** trường, không xoá hay đổi tên trường cũ.

### A1. Mọi chỉ số do Backend trả (Admin-web không tự tính)

**Backend**
1. `AnomalyDetector.getEffectiveThresholds(hour?)` (hàm mới, trong `anomaly.detector.js`) trả về đúng các con số mà `evaluate()` đang dùng. `evaluate()` phải đọc ngưỡng từ hàm này, không tính lại riêng.
   ```
   {
     traffic:  { baselineRpm,        // = max(100, hourlyBaselines[h].requestsPerMin): số bộ phát hiện đang so sánh
                 alertRpm,           // = round(baselineRpm × effectiveTrafficRatio): ngưỡng thật sự gây cảnh báo
                 ratio,              // effectiveTrafficRatio (mặc định 3,5)
                 minRpm: 300 },
     auth:     { failedLogins,       // bruteForceThreshold
                 tokenReuse: 5 },
     exploit:  { malformed },        // exploitThreshold
     resource: { lagMs, cpuPercent, ramPercent, error5xxRate: 0.25, minRequestsFor5xx: 10 },
     ipBurstPer10s,                  // xem A2
     scoreBands: { elevated: 40, warning: 70, critical: 85 }
   }
   ```
2. `AIOpsService.getStatus()` thêm trường `indicators = detector.getEffectiveThresholds()`. `tick()` cũng gắn `indicators` vào `_currentStatus` để socket `admin.security_alert` mang theo.
3. `setConcurrencyScale()` thôi trả `expectedBaselineRPM = N×10` và `peakCeilingRPM = N×25`; trả `indicators` thay cho hai trường này. Kiểm tra trước: hai trường cũ không được Admin-web dùng (`Grep expectedBaselineRPM|peakCeilingRPM src/Admin-web`). Nếu có chỗ dùng thì giữ trường cũ và báo lại.

**Admin-web**
4. `ScaleSection.jsx`: bỏ ba dòng tính `baselineRpm`, `safePeakRpm`, `ipThreshold`. Ba thẻ lấy `ops.indicators.traffic.baselineRpm`, `ops.indicators.traffic.alertRpm`, `ops.indicators.ipBurstPer10s`. Thẻ thứ hai đổi nhãn thành "Ngưỡng cảnh báo lưu lượng" (vi) / "Traffic alert threshold" (en). Chưa có dữ liệu thì hiện `--`.
5. `SignalsSection.jsx`: thẻ chuyển sang màu `danger` khi giá trị ≥ ngưỡng tương ứng trong `indicators`. Cụ thể: đăng nhập sai so với `auth.failedLogins`, token dùng lại so với `auth.tokenReuse`, yêu cầu độc hại so với `exploit.malformed`, độ trễ so với `resource.lagMs`, CPU so với `resource.cpuPercent`, RAM so với `resource.ramPercent`, 5xx so với `resource.error5xxRate`. Bỏ toàn bộ số cứng 5 / 1 / 3 / 100 / 85 / 90 / 0,05.
6. `VectorSection.jsx`: `barTone` dùng `indicators.scoreBands` (≥ critical: danger, ≥ warning: warning, ≥ elevated: info). Nhãn trạng thái từng vectơ lấy từ `statusData.vectorDefenses[key].status`, không tự suy từ điểm. Riêng vectơ `auth` vẫn giữ phần đếm số khoá đang hiệu lực.
7. `useAIOps.js`:
   - Bỏ `autoRecommendedThresholds`.
   - Ô ngưỡng trong hộp "Hiệu chuẩn" lấy placeholder từ `indicators` (ngưỡng đang hiệu lực).
   - `handleCalibrate` chỉ gửi những ô người dùng đã nhập. Ô để trống thì không gửi, để Backend giữ nguyên giá trị đang dùng. Cách này sửa lỗi cũ: trước đây ô trống bị ghi đè bằng lag 100 / RAM 85.
   - `isEmergencyResourceRisk` = `recommendedAction === 'EMERGENCY_MAINTENANCE' || vectorDefenses.resource.status === 'CRITICAL'` (khi vectơ tài nguyên đang bật). Bỏ công thức tự tính `0,15 / 250`.
   - Xuất `indicators` qua `ops`.
8. `TrendSection.jsx` `scoreOf`: thiếu `vectorScores[key]` thì trả `null`. Đoạn đó ngắt đường như khi mất số liệu, không quy đổi sang thang khác (`×10`, `/30`, `×25`, `max(CPU,RAM)`). Cập nhật cách vẽ để `null` không bị coi là 0.

**Ca test**
- BE `aiops.detector.test.js`: `getEffectiveThresholds()` khớp với ngưỡng mà `evaluate()` dùng. Có ca ngưỡng tuỳ chỉnh `trafficSpikeRps` và `authFailureThreshold`: `alertRpm` và `failedLogins` đổi theo, và `evaluate()` báo đúng tại biên (dưới ngưỡng thì không có sự cố, bằng ngưỡng thì có).
- BE `aiops.service.test.js`: `getStatus()` có `indicators`; `setConcurrencyScale()` trả `indicators`.
- AW `aiops.test.jsx`: status giả có `indicators.traffic.baselineRpm = 777` thì thẻ "Lưu lượng nền" hiện 777, chứng minh không còn tính N×10. Thẻ đăng nhập sai không đỏ ở 5 khi ngưỡng là 15, và đỏ ở 15. Hiệu chuẩn với ô trống thì payload không có khoá đó.
- AW `aiops.trend.test.jsx`: mẫu thiếu `vectorScores` thì không vẽ điểm cho mẫu đó.

### A2. Ngưỡng chặn IP không phụ thuộc N
- `feature.collector.js`: `_getBurstThreshold()` trả hằng `IP_BURST_PER_10S = 150`, đọc được từ biến môi trường `AIOPS_IP_BURST_PER_10S` nếu đặt (số nguyên > 0). Bỏ `20 + 50·log₁₀N`. Với N ≤ ~1.600, công thức cũ cũng ra 150, nên hành vi trên hệ thống hiện tại không đổi.
- `setTargetConcurrency()` của collector giữ lại (service vẫn gọi) nhưng không còn ảnh hưởng ngưỡng.
- Detector lấy `ipBurstPer10s` từ collector, hoặc dùng chung một hằng xuất từ collector, để đưa vào `indicators`.
- Test: N = 100 và N = 50.000 đều cho ngưỡng 150. Có biến môi trường = 80 thì ngưỡng là 80, và yêu cầu thứ 81 trong cửa sổ gọi `quarantine`.

### A3. Tách "đọc mẫu" khỏi "chốt cửa sổ"
- `FeatureCollector.peekSample()` (mới): trả mẫu tính trên bộ đếm hiện tại, **không** xoá bộ đếm. `getSample()` = `peekSample()` + xoá bộ đếm, và **chỉ `tick()` được gọi**.
- Quy đổi RPM theo thời gian thật đã trôi: `requestsPerMin = round(requests × 60 / max(1, giây_đã_trôi))`, với `giây_đã_trôi` tính từ lần chốt cửa sổ trước (lưu `_windowStartedAt`). Bỏ hệ số cố định `60 / windowSeconds`. Mẫu thêm trường `windowSeconds` (số giây thực của cửa sổ).
- `detector.evaluate()` có chỗ suy số yêu cầu trong cửa sổ từ RPM (`sampleWindowRequests`). Đổi sang dùng `sample.requestCount` (trường mới, bằng số yêu cầu thật trong cửa sổ). Nếu không có trường này thì giữ cách cũ.
- `aiops.service.js`: bốn chỗ đang gọi `collector.getSample()` ngoài `tick()` (`captureMetricSnapshot`, `toggleVector`, `getStatus`, `calibrate`) đổi thành `this._currentStatus?.sample || this.collector.peekSample()`.
- Test: gửi 7 yêu cầu, gọi `getStatus()`, rồi gửi thêm 8 lần đăng nhập sai. Mẫu ở `tick()` kế tiếp có `failedLogins = 8` và `requestCount = 15`, tức là `getStatus` không làm mất dữ liệu. `calibrate()` không xoá bộ đếm.

### A4. Độ trễ đo bằng p99 trong cửa sổ
- `event-loop-monitor.js`: thêm bộ đo `perf_hooks.monitorEventLoopDelay({ resolution: 20 })`. Thêm hàm `getWindowLag()` trả `{ p99Ms, maxMs }` (đổi từ nano giây sang mili giây, làm tròn 1 chữ số) rồi `reset()` histogram. Giữ nguyên `getLag()` và `isOverloaded()` (load shedding vẫn dùng như cũ).
- Collector:
  - `getSample()` dùng `p99Ms` cho `eventLoopLagMs`, thêm `eventLoopLagMaxMs`.
  - `peekSample()` đọc p99 **không** reset histogram (thêm `peekWindowLag()`).
  - Bỏ việc gán cứng 10 ms trong 45 giây đầu. Thay vào đó, mẫu có cờ `warmingUp: true` và `evaluate()` bỏ qua điểm độ trễ khi cờ này bật.
- Admin-web: nhãn "Độ trễ xử lý" đổi thành "Độ trễ vòng lặp (p99)" (vi) / "Event loop delay (p99)" (en). Dòng phụ ghi `max <maxMs> ms`.
- Test: monitor giả trả p99 = 300, mẫu có `eventLoopLagMs = 300`. Khi `warmingUp` bật, điểm độ trễ = 0 dù p99 lớn.

### A5. Thống nhất định nghĩa RAM
- Định nghĩa chung: `ramPercent = RSS tiến trình / hạn mức bộ nhớ × 100`.
  - Hạn mức = quota container nếu chạy trong container (`getRuntimeHardwareSpecs().ramTotalMb`), ngược lại = `os.totalmem()`.
- `system-hardware-monitor.js` `_sampleRam()`: nhánh máy thật đổi sang định nghĩa trên. Giữ thêm `hostRamPercent` (RAM toàn máy) làm trường phụ để tham khảo, không dùng để chấm điểm.
- Hàm dự phòng `_getRamPercent()` / `_getHardwareMetrics()` trong collector đổi theo cùng định nghĩa.
- Admin-web: nhãn "RAM" đổi thành "RAM tiến trình" (vi) / "Process RAM" (en). Dòng phụ hiện `rssMb / ramTotalMb MB`.
- Test: monitor với RSS = 512 MB, totalmem = 8.192 MB cho `ramPercent = 6`, bất kể `os.freemem()`.

### Tiêu chí nghiệm thu phần A
- `npm run test:unit` (Backend) và `npm test` (Admin-web) xanh. Lint Admin-web sạch.
- `Grep "Math.log10|\* 10\b|safePeakRpm|autoRecommendedThresholds" src/Admin-web/src/pages/system/aiops` không còn công thức chỉ số.
- Báo cáo ngắn: tệp đã sửa, lệnh đã chạy, ca đỏ/xanh, điểm lệch so với kế hoạch.

---

## Phần B: đề xuất công thức (CHỜ DUYỆT, chưa làm)

### B1. Lưu lượng nền theo giờ: lấy từ dữ liệu thật, thay `N × 10` và EWMA
```
RPM_nền(h) = trung vị { requests_per_min của aiops_metric_snapshot
                         trong 7 ngày gần nhất, giờ VN = h, is_anomaly = false }
```
- `h`: giờ trong ngày (0–23) theo giờ Việt Nam. Snapshot được ghi 5 phút một lần, nên mỗi giờ có tối đa 12 × 7 = 84 mẫu.
- Lý do dùng trung vị: một đợt tấn công lọt vào dữ liệu không kéo lệch kết quả như trung bình hay EWMA. Bỏ mẫu `is_anomaly = true` để chống "nhiễm độc" đường nền.
- Đủ dữ liệu khi có ≥ 24 mẫu cho giờ `h` (khoảng 2 ngày). Nếu chưa đủ thì lấy trung vị mẫu sạch của 24 giờ gần nhất. Nếu vẫn dưới 12 mẫu thì dùng **giá trị khởi đầu `N × r`**, với `r = 2` yêu cầu/phút/người. Con số này là **ước tính**: app đồng bộ định kỳ 15 phút một lần, thêm các lần đẩy dữ liệu sau thao tác. Giao diện ghi rõ nguồn của con số: "từ lịch sử" hoặc "ước tính".
- Đường nền tính lại mỗi giờ và khi khởi động, giữ trong bộ nhớ. Bỏ cập nhật EWMA mỗi 10 giây. Bỏ hệ số đêm cố định 0,25, vì dữ liệu từng giờ đã phản ánh ngày và đêm.

### B2. Ngưỡng cảnh báo lưu lượng: một định nghĩa duy nhất, thay ×3 / ×3,5 / ×25
```
RPM_trần(h) = max( 3 × RPM_nền(h),  1,5 × P95_sạch(h),  300 )
```
- `P95_sạch(h)`: phân vị 95 của cùng tập mẫu ở B1. Thành phần này giữ cho giờ cao điểm thật không bị báo nhầm.
- 300 RPM là sàn tối thiểu (bằng điều kiện "≥ 300" đang có), tránh báo động khi hệ thống gần như rỗi.
- Quản trị viên đặt `trafficSpikeRps` thì `RPM_trần = trafficSpikeRps × 60`, ghi đè công thức.

### B3. Điểm rủi ro liên tục, thay luật bật/tắt (14 lần ra 14 điểm, 15 lần ra 70 điểm)
Mỗi tín hiệu `x` có ba mốc: **A** = ngưỡng chú ý, **T** = ngưỡng cảnh báo, **T_nặng** = mức nghiêm trọng.
```
        ⎧ 0                                         x ≤ A
s(x) =  ⎨ 70 × (x − A) / (T − A)                    A < x < T
        ⎩ 70 + 30 × min(1, (x − T) / (T_nặng − T))   x ≥ T
```
- Điểm tăng đều từ 0 lên 70 khi tín hiệu đi từ A tới T, rồi từ 70 lên 100 khi tiến tới T_nặng.
- **s ≥ 70 khi và chỉ khi x ≥ T**, nên điểm cảnh báo luôn khớp với việc ghi sự cố. Lỗi cũ "sự cố đã ghi mà điểm chỉ 50" không còn.

Mốc đề xuất:

| Tín hiệu (mỗi cửa sổ 10 giây) | A | T | T_nặng | Ghi chú |
|---|---|---|---|---|
| Đăng nhập sai (toàn hệ thống) | 5 | 15 | 30 | T cố định, khớp ngưỡng cách ly theo IP (15). Bỏ `log₁₀N`. |
| Token bị dùng lại | 1 | 5 | 10 | giữ như hiện tại |
| Yêu cầu độc hại | 1 | 8 | 20 | giữ như hiện tại |
| Độ trễ vòng lặp p99 (ms) | 100 | 250 | 400 | T trùng ngưỡng load shedding |
| CPU (%) | 70 | 85 | 95 | |
| RAM tiến trình (%) | 80 | 92 | 97 | |
| Tỷ lệ lỗi 5xx (khi ≥ 10 yêu cầu) | 0,02 | 0,10 | 0,25 | **đổi**: T từ 25% xuống 10%. 10% yêu cầu lỗi đã là sự cố rõ ràng. |
| Lưu lượng (RPM) | 1,5 × RPM_nền | RPM_trần | 2 × RPM_trần | Nếu **không** có dấu hiệu tấn công thì chặn trên 40 (chỉ ELEVATED, không cảnh báo) |

- Điểm vectơ = điểm lớn nhất trong các tín hiệu của vectơ đó. Vectơ tài nguyên giữ phần cộng khi nhiều chỉ số cùng ≥ 70: `+10 × (k − 1)`, với k là số chỉ số ≥ 70.
- Điểm tổng = `min(100, max điểm vectơ + 8 × (m − 1))`, với m là số vectơ ≥ 70. Ngưỡng đếm đổi từ 65 thành 70 cho khớp băng điểm.
- Băng trạng thái giữ nguyên: 40 ELEVATED, 70 WARNING, 85 CRITICAL.
- Bỏ phần cộng điểm cho lưu lượng bình thường (`min(15, tỷ lệ × 4)`): lưu lượng dưới A cho 0 điểm.

### B4. Dấu hiệu tấn công lưu lượng: thay "≤ 3 IP" và "entropy"
```
có_dấu_hiệu_tấn_công = (yêu_cầu_của_IP_lớn_nhất / tổng_yêu_cầu ≥ 0,5)
                      ∨ (tỷ_lệ_4xx ≥ 0,25)
                      ∨ (yêu_cầu_độc_hại > 0)
```
- Thành phần đầu là thị phần của IP gửi nhiều nhất trong cửa sổ. Nó đo đúng ý "lưu lượng dồn từ ít nguồn" và không phụ thuộc quy mô hệ thống, khác với "≤ 3 IP".
- Bỏ điều kiện 5xx khỏi dấu hiệu tấn công, vì 5xx là lỗi phía máy chủ và đã được vectơ tài nguyên xử lý.

### B5. Báo cáo hiệu chuẩn (bản sửa 2026-11-17, thay bản hồi quy CPU%/RAM% theo RPM)

**Lỗi của cách hiệu chuẩn hiện tại (đã đối chiếu mã)**
1. Lấy sai phần cứng. `calculateServerHardwareBaseline` dùng `os.cpus().length` và `os.totalmem()` ([anomaly.detector.js:103-105](../../../src/Backend/modules/aiops/anomaly.detector.js)). Trong container, hai giá trị này là của máy chủ vật lý chứ không phải hạn mức được cấp. Trong khi đó thẻ CPU trên trang lại dùng hạn mức (0,15 nhân). Kết quả là năng lực bị phóng đại nhiều lần.
2. Chia tải cho mọi nhân. Backend chạy một tiến trình (`node index.js`, không có cluster), nên luồng xử lý JavaScript dùng tối đa 1 nhân.
3. Hằng số không có nguồn: 1,8 ms CPU cho mỗi yêu cầu, 0,5 MB cho mỗi người dùng, độ trễ `4 + (CPU − 60) × 0,3`. Kết quả còn bị trộn `0,6 × số đo lúc bấm nút`, nên dự báo cho N lớn bị kéo về mức tải lúc rỗi.
4. Mỗi lần hiệu chuẩn, đường nền đã học bị xoá (`hourlyBaselines = _initializeBaselines()`), đồng thời một cửa sổ đo bị mất (A3 đã xử lý phần này).
5. Ngưỡng tuỳ chỉnh không được lưu. Service có đọc khoá `custom_vector_thresholds` khi khởi động, nhưng không chỗ nào ghi khoá này. Chú thích trong `calibrate` ghi "PO Rule: không lưu cứng". Sau mỗi lần khởi động lại, ngưỡng quản trị viên đặt bị mất.
6. Bộ đọc hạn mức CPU coi `cpu.shares` / `cpu.weight` là số nhân (`runtime-environment.js`). Đây là trọng số chia phần tương đối, không phải giới hạn cứng. Con số "0,15 nhân" trên trang có thể đến từ đây (**chưa xác minh trên máy chủ thật**).

**Lỗi của bản B5 trước**
- RAM không tỷ lệ tuyến tính với RPM. RAM phụ thuộc số yêu cầu đang xử lý dở, bộ đệm, và việc V8 dọn rác nhưng không trả bộ nhớ lại cho hệ điều hành.
- Hồi quy CPU% theo RPM trên dữ liệu tải thấp rồi ngoại suy lên mức tải cao là không đáng tin. Đơn vị CPU% cũng phụ thuộc vào cách đọc hạn mức ở lỗi 6.
- Snapshot chỉ là một mẫu 10 giây trong mỗi 5 phút, không có số yêu cầu và thời gian CPU của cửa sổ.

**Công thức đề xuất: Luật sử dụng (Utilization Law, U = X × S)**
```
Mỗi cửa sổ i (10 giây):  C_i = thời gian CPU tiến trình đã dùng (ms), từ process.cpuUsage()
                         R_i = số yêu cầu hoàn tất trong cửa sổ
Khớp:                    C_i ≈ C₀ + S × R_i     (bình phương nhỏ nhất, trên K cửa sổ gần nhất trong bộ nhớ)
Ngân sách CPU / cửa sổ:  W = 10 000 ms × min(1, Q) × U_max
Năng lực:                X_max = (W − C₀) / S          (yêu cầu / 10 giây)
                         RPM_tối_đa = 6 × X_max
```
- `S`: thời gian CPU trung bình cho một yêu cầu (ms), đo trực tiếp.
- `C₀`: CPU nền mỗi cửa sổ khi không có yêu cầu (bộ hẹn giờ, socket, hàng đợi, chính AIOps).
- `Q`: hạn mức CPU **cứng** (`cpu.max`, `cfs_quota_us`, hoặc biến `CLOUD_CPU_CORES`). Không dùng shares/weight. Không có hạn mức cứng thì Q = 1. Dùng `min(1, Q)` vì một tiến trình Node chỉ dùng được 1 nhân cho JavaScript.
- `U_max = 0,7`: mức sử dụng tối đa nên nhắm tới. Theo mô hình hàng đợi M/M/1, thời gian chờ tỷ lệ với ρ/(1−ρ): tại ρ = 0,7 thời gian chờ khoảng 2,3 lần thời gian phục vụ, và tăng rất nhanh khi ρ > 0,8.
- Phương pháp này không ngoại suy một đường hồi quy CPU%. Nó đo `S` ở tải thấp và giả định `S` không đổi cho tới khi bão hoà, giả định chuẩn của phân tích vận hành. Phương pháp chỉ ước lượng nút cổ chai CPU.
- Điều kiện tin cậy: K ≥ 30 cửa sổ có R_i > 0, và R_i có độ trải (P90 ≥ 2 × P10). Không đạt thì báo "chưa đủ dữ liệu".
- Dữ liệu C_i, R_i giữ trong bộ nhớ, khoảng 1 giờ gần nhất (360 cửa sổ). Kết quả `S`, `C₀`, thời điểm tính được lưu vào `aiops_setting` (bảng khoá–giá trị sẵn có, không cần migration).

**Đánh giá năng lực**
- `RPM_trần ≤ RPM_tối_đa`: OPTIMAL.
- `RPM_trần ≤ RPM_tối_đa / U_max` (tức chưa tới 100% CPU): WARNING.
- Lớn hơn: OVER_CAPACITY.

**Những gì không dự báo, chỉ báo hiện trạng**
- RAM: `heapUsed / heap_size_limit` (V8) và `RSS / hạn mức`.
- CSDL: số kết nối đang dùng / kích thước pool lúc cao nhất.
- Báo cáo ghi rõ đây là giới hạn của phương pháp. Năng lực CSDL và dịch vụ ngoài (thanh toán, AI) không được ước lượng.

**Luồng hiệu chuẩn sau khi sửa**
- Không xoá đường nền nữa: đường nền lấy từ dữ liệu theo B1.
- Không ăn cửa sổ đo.
- Quy đổi ra người dùng `N_tối_đa ≈ RPM_tối_đa / r` chỉ để tham khảo, gắn nhãn "ước tính".
- Sửa bộ đọc hạn mức: shares/weight không tính là số nhân.
- Kiểm chứng ngoài hệ thống (khuyến nghị): chạy thử tải bằng `autocannon` trên môi trường thử riêng, so `RPM_tối_đa` dự báo với mức tải tại đó độ trễ p99 vượt 250 ms. Không chạy trên Supabase dùng chung.

---

## Tự rà soát trước khi làm (2026-11-17)

Chủ dự án đã duyệt cả phần A và phần B, chọn phương án (a): lưu ngưỡng tuỳ chỉnh vào `aiops_setting`. Rà lại toàn bộ phương án, có các điều chỉnh sau:

1. **Hạn mức CPU.** Không đổi nghĩa của `cpuCores`, vì thẻ CPU% và `admin.service` đang dùng giá trị này. Thay vào đó thêm cờ `cpuQuotaHard`, chỉ bật khi hạn mức đến từ `cpu.max`, `cfs_quota_us` hoặc biến `CLOUD_CPU_CORES`. Năng lực tính với `Q = cpuQuotaHard ? cpuCores : 1`. Giá trị dự phòng 0,15 nhân khi `RENDER=true` không phải hạn mức cứng (chưa xác minh với Render).
2. **R_i** đếm yêu cầu **hoàn tất** (sự kiện `finish`), không đếm yêu cầu đến. Thời gian CPU của yêu cầu chỉ tính đủ khi yêu cầu đã xong.
3. **Giờ của snapshot.** Cột `recorded_at` không có múi giờ. Khi ghi và đọc, `pg` đều dùng múi giờ của tiến trình Node, nên quy đổi giờ Việt Nam trong JS sau khi đọc. Không dùng `EXTRACT` trong SQL, vì sẽ lệch khi máy chạy Backend không ở UTC.
4. **Ngưỡng tuỳ chỉnh** chỉ đặt T. A và T_nặng suy theo tỷ lệ mặc định: đăng nhập sai A = T/3, T_nặng = 2T; độ trễ A = 0,4T, T_nặng = 1,6T; CPU A = T − 15, T_nặng = min(100, T + 10); RAM A = T − 12, T_nặng = min(100, T + 5); yêu cầu độc hại A = 1, T_nặng = 2,5T. Nếu A ≥ T thì đặt A = T/2.
5. **Ô trống khi hiệu chuẩn** nghĩa là giữ ngưỡng đang dùng. Chưa có nút "về mặc định"; ghi nhận là việc sau.
6. **Lưu lượng hữu cơ vượt trần** cho ELEVATED (40 điểm), không còn NORMAL. Test cũ số 8 đổi kỳ vọng thành "không cảnh báo" (< 70).
7. **Test mã hoá công thức cũ** (N×10, ×25, hiệu chuẩn ghi đè đường nền, RPM = số yêu cầu × 6) được thay bằng test của công thức mới. Đây là đổi đặc tả có chủ đích, không phải sửa test cho khớp mã.
8. Dữ liệu năng lực (C_i, R_i) chỉ lấy từ cửa sổ không ở giai đoạn khởi động.

### Việc kèm theo khi phần B được duyệt
- Thêm ca test cho từng công thức ở biên: x = A, x = T − ε, x = T, x = T_nặng.
- Cập nhật `docs/AIOps/` (đặc tả công thức) và `docs/progress/Backend.md`.

---

## Điểm lệch so với kế hoạch (phát hiện khi kiểm thật, 2026-11-17)

1. **Mức chú ý lưu lượng có sàn:** `A = max(1,5 × nền, 0,5 × T)`. Trên CSDL thử, lịch sử snapshot toàn RPM = 0, nên nền = 0 và A = 0, khiến mọi lưu lượng đều có điểm. Khi T = 3 × nền (trường hợp thường gặp), giá trị không đổi so với bản đã duyệt.
2. **Histogram độ trễ gồm sẵn chu kỳ đo:** vòng lặp rảnh vẫn ghi khoảng 31 ms trên Windows (20 ms chu kỳ + độ thô bộ hẹn giờ). Mã trừ đi 20 ms; trên Windows lúc rảnh vẫn còn khoảng 10–14 ms do bộ hẹn giờ của hệ điều hành.
3. **Lỗi cũ được sửa kèm:** Admin-web không bao giờ hiện báo cáo hiệu chuẩn (đọc `serverSpecs` ở sai tầng `data`). Nhãn hộp hiệu chuẩn ghi "lần/phút" trong khi Backend đếm theo 10 giây.
