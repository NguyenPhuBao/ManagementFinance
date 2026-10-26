# 📘 Kế Hoạch Triển Khai Toàn Diện: Trung Tâm Cài Đặt (Settings Engine) Admin-Web

> **Dự án:** Personal Finance Management — Module `src/Admin-web`  
> **Tài liệu nguồn sự thật:** `docs/superpowers/plans/2026-10-08-admin-settings-engine.md`  
> **Trạng thái:** Kế hoạch kỹ thuật chi tiết từng chức năng con (TDD Ready)  
> **Mục tiêu:** Chuyển đổi toàn diện 10 chức năng con bên trong 4 danh mục nội dung của Settings Modal từ bản Mockup thành hệ thống hoạt động thực tế 100%.

---

## 🏛️ TỔNG QUAN KIẾN TRÚC HỆ THỐNG CÀI ĐẶT

```mermaid
graph TD
    subgraph "Core State & Event Bus"
        LS[(LocalStorage: admin_system_settings)] <--> SC[SettingsContext / SettingsProvider]
        Watcher[Inactivity Watcher Timer] -->|Timeout| SC
    end

    subgraph "1. Giao Diện & Hiển Thị"
        SC -->|theme: light/dark/system| DOM_HTML[document.documentElement .dark & data-theme]
        SC -->|tableDensity: comfortable/compact| DOM_BODY[document.body data-density]
    end

    subgraph "2. Cảnh Báo & Âm Thanh"
        SC -->|soundEnabled| AudioEngine[sound.service.js: Web Audio API Oscillator]
        SC -->|toastDuration: 3s/4.5s/7s/10s| AlertCtx[AlertContext: alert.context.jsx]
        SC -->|showUnreadBadge: true/false| HeaderBell[Header.jsx Icon Bell Badge]
        AIOpsAlert[AIOps Security Alert CRITICAL] -->|Trigger Audio| AudioEngine
    end

    subgraph "3. Thời Gian Thực & Socket"
        SocketHub[useSocket.js] <-->|socket.connected & admin_ping| SC
        SC -->|Ping Latency (ms)| SettingsUI[SettingsModal Ping Display]
        SC -->|metricsInterval: 1s/3s/5s/10s| AIOpsPoller[AIOpsPage.jsx Polling Interval]
    end

    subgraph "4. Bảo Mật & Thông Tin"
        SC -->|isLocked: true| LockModal[LockScreenModal.jsx Fullscreen Lock]
        SC -->|safeClearCache| StorageCleaner[Safe LocalStorage Cleaner]
        RuntimeMeta[Runtime Env, Socket ID, Storage KB] --> SettingsUI
    end
```

---

## 📋 MA TRẬN 10 CHỨC NĂNG CON BÊN TRONG 4 DANH MỤC

| Danh Mục | STT | Tên Chức Năng Con | Trạng Thái Trước | Cơ Chế Hoạt Động Thực Tế | File Can Thiệp |
|---|:---:|---|---|---|---|
| **1. Giao Diện & Hiển Thị** | 1.1 | Chế độ hiển thị màu sắc (Sáng / Tối) | Bỏ "Theo hệ thống" theo PO | Chỉ giữ 2 lựa chọn chuẩn: Sáng và Tối (Class `.dark` trên `<html>`) | `index.css`, `settings.context.jsx`, `SettingsModal.jsx` |
| | 1.2 | Mật độ dòng bảng dữ liệu (Thoải mái / Thu gọn) | Hoàn thiện 100% | Gắn `data-density="compact"` lên `body`, CSS toàn cục co padding `th, td` | `index.css`, `settings.context.jsx`, `SettingsModal.jsx` |
| **2. Cảnh Báo & Âm Thanh** | 2.1 | Âm thanh chuông cảnh báo khẩn cấp | Hoàn thiện 100% | Web Audio API Synthesizer (880Hz-440Hz), nút Nghe thử 🔊, còi khi AIOps Critical | `sound.service.js`, `Header.jsx`, `SettingsModal.jsx` |
| | 2.2 | Thời gian tự ẩn thông báo Toast (3s/4.5s/7s/10s) | Áp dụng tức thì cho admin-web | Đọc `settings.toastDuration` trong `alert.context.jsx` để điều chỉnh timeout chuẩn xác | `alert.context.jsx`, `settings.context.jsx` |
| | 2.3 | Huy hiệu số lượng thông báo chưa đọc (Badge) | Hoàn thiện 100% | Đọc `settings.showUnreadBadge`, ẩn/hiện chấm đỏ số lượng trên icon chuông Header | `Header.jsx`, `settings.context.jsx` |
| **3. Thời Gian Thực & Socket** | 3.1 | Trạng thái kết nối Socket Live & Tự động đo độ trễ | Tự động chuyển live & đo Ping | Bắt `socket.connected` sống thực tế, tự động đo ping roundtrip ms định kỳ | `settings.context.jsx`, `SettingsModal.jsx` |
| | 3.2 | Tần suất nhịp tim AIOps Metrics (1s/3s/5s/10s) | Hoàn thiện 100% | Đọc `metricsInterval` trong `AIOpsPage.jsx`, điều chỉnh chu kỳ lấy mẫu `/health/metrics` | `AIOpsPage.jsx`, `settings.context.jsx` |
| **4. Bảo Mật & Thông Tin** | 4.1 | Tự động khóa an toàn khi không mở website | Đổi cơ chế theo PO chọn | Dùng Page Visibility API đếm thời gian khi rời tab/ẩn browser, hiện `LockScreenModal` | `LockScreenModal.jsx`, `settings.context.jsx`, `AppLayout.jsx` |
| | 4.2 | Dọn dẹp bộ nhớ đệm nhanh (Clear Cache) | Xóa sessionStorage & caches | Dọn dẹp bộ nhớ tạm nhanh, bảo toàn 100% auth token và settings | `settings.context.jsx`, `SettingsModal.jsx` |
| | 4.3 | Khôi phục cài đặt gốc (Footer Modal) | Nút chuẩn tại Footer | Modal xác nhận khôi phục toàn bộ cài đặt về mặc định ban đầu | `SettingsModal.jsx`, `settings.context.jsx` |

---

## 🔍 CHI TIẾT ĐẶC TẢ KỸ THUẬT TỪNG CHỨC NĂNG CON

---

### DANH MỤC 1: GIAO DIỆN & HIỂN THỊ

#### 1.1. Chế độ hiển thị màu sắc (Theme Mode: Light / Dark / System)
* **Mô tả hành vi:**
  - Admin bấm **"Giao diện Sáng"**: Toàn bộ hệ thống chuyển sang giao diện nền sáng (`#f8f9ff`), chữ đậm, thẻ trắng.
  - Admin bấm **"Giao diện Tối"**: Toàn bộ hệ thống chuyển sang giao diện dark mode hiện đại (`#0f172a`), các khối thẻ màu xám đậm (`#1e293b`), chữ sáng (`#f8fafc`), viền sắc nét (`#334155`).
  - Admin bấm **"Theo Hệ Thống"**: Tự động phát hiện theme của Windows/macOS thông qua CSS Media Query `prefers-color-scheme`. Nếu người dùng đổi theme OS, Admin-web lập tức đổi theo.
* **Nguyên lý kỹ thuật:**
  ```javascript
  const applyTheme = (themeMode) => {
    const root = document.documentElement;
    let isDark = false;
    if (themeMode === 'dark') isDark = true;
    else if (themeMode === 'system') {
      isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    }
    if (isDark) {
      root.classList.add('dark');
      root.setAttribute('data-theme', 'dark');
    } else {
      root.classList.remove('dark');
      root.setAttribute('data-theme', 'light');
    }
  };
  ```
* **Bổ sung CSS Token trong `src/Admin-web/src/index.css`:**
  ```css
  /* Dark Mode Tokens & Overrides */
  .dark {
    --color-surface-bright: #0b1320;
    --color-surface: #0f172a;
    --color-on-surface: #f8fafc;
    --color-on-surface-variant: #94a3b8;
    --color-outline-variant: #334155;
    background-color: #0b1320;
    color: #f8fafc;
  }
  .dark body {
    background-color: #0b1320 !important;
    color: #f8fafc !important;
  }
  .dark .bg-white {
    background-color: #1e293b !important;
    border-color: #334155 !important;
  }
  .dark .bg-surface-bright, .dark .bg-surface {
    background-color: #0f172a !important;
  }
  .dark .text-on-surface {
    color: #f8fafc !important;
  }
  .dark .text-on-surface-variant, .dark .text-secondary {
    color: #94a3b8 !important;
  }
  .dark .border-outline-variant {
    border-color: #334155 !important;
  }
  ```

---

#### 1.2. Mật độ dòng bảng dữ liệu (Table Density: Comfortable vs Compact)
* **Mô tả hành vi:**
  - Chế độ **"Thoải mái" (Comfortable - Mặc định)**: Hàng bảng có padding rộng rãi (`py-3.5` ~ 14px), font size tiêu chuẩn 12-14px, tạo cảm giác thông thoáng.
  - Chế độ **"Thu gọn" (Compact)**: Hàng bảng tự động co nhỏ padding (`py-2` ~ 8px), font chữ 11-12px, giảm 40% chiều cao dòng. Giúp quản trị viên quan sát được 15-20 dòng trên một màn hình laptop mà không cần cuộn trang.
* **Nguyên lý kỹ thuật:**
  - Gắn thuộc tính `data-density="compact"` hoặc `data-density="comfortable"` lên `document.body`.
  - CSS quy tắc toàn cục trong `index.css`:
  ```css
  /* Compact Table Density Rules */
  body[data-density="compact"] table th,
  body[data-density="compact"] table td {
    padding-top: 0.5rem !important;
    padding-bottom: 0.5rem !important;
    font-size: 0.75rem !important;
  }
  body[data-density="compact"] table input[type="checkbox"] {
    width: 0.875rem !important;
    height: 0.875rem !important;
  }
  body[data-density="compact"] .stat-card {
    padding: 1rem !important;
  }
  ```
  - Áp dụng tức thì cho mọi trang có bảng: `UserListPage`, `CategoryPage`, `AuditLogPage`, `PermissionManagementPage`, `BroadcastPage`.

---

### DANH MỤC 2: CẢNH BÁO & ÂM THANH

#### 2.1. Âm thanh chuông cảnh báo khẩn cấp (Emergency Sound Alarm)
* **Mô tả hành vi:**
  - Toggle Switch Bật/Tắt: Khi Bật (`soundEnabled = true`), hệ thống sẵn sàng phát âm thanh khi có sự kiện khẩn cấp. Khi Tắt, hoàn toàn im lặng.
  - Nút **"🔊 Nghe thử" (Test Sound)**: Nằm ngay cạnh toggle, cho phép Admin bấm vào để nghe thử âm thanh cảnh báo mẫu.
  - Kích hoạt tự động:
    - Khi AIOps Sentinel gửi sự kiện Socket `admin.security_alert` có level `CRITICAL` hoặc threat score > 80.
    - Khi phát sinh lỗi nghiêm trọng từ `alert.error()`.
* **Nguyên lý kỹ thuật (`src/Admin-web/src/services/sound.service.js`):**
  - Sử dụng **Web Audio API** (`window.AudioContext || window.webkitAudioContext`), không cần tải file MP3 bên ngoài (tránh lỗi 404, CORS, trễ mạng).
  ```javascript
  class SoundService {
    constructor() {
      this.ctx = null;
    }
    init() {
      if (!this.ctx) {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (AudioContext) this.ctx = new AudioContext();
      }
      if (this.ctx && this.ctx.state === 'suspended') {
        this.ctx.resume();
      }
    }
    // Còi báo động khẩn cấp: 2 hồi âm 880Hz và 440Hz
    playCriticalAlarm() {
      try {
        this.init();
        if (!this.ctx) return;
        const now = this.ctx.currentTime;
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(880, now);
        osc.frequency.setValueAtTime(440, now + 0.15);
        osc.frequency.setValueAtTime(880, now + 0.3);
        gain.gain.setValueAtTime(0.3, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.5);
        osc.connect(gain);
        gain.connect(this.ctx.destination);
        osc.start(now);
        osc.stop(now + 0.5);
      } catch (_) {}
    }
  }
  ```

---

#### 2.2. Thời gian tự ẩn thông báo Toast (Toast Duration)
* **Mô tả hành vi:**
  - Dropdown có 4 mức: `3000` (3 giây - Nhanh), `4500` (4.5 giây - Chuẩn), `7000` (7 giây - Đọc chậm), `10000` (10 giây - Rất chậm).
  - Khi Admin chọn mức nào, tất cả các thông báo Toast (`alert.success`, `alert.info`, `alert.warning`, `alert.error`) xuất hiện trên góc phải màn hình sẽ tự biến mất sau đúng số giây đó.
* **Nguyên lý kỹ thuật:**
  - Sửa `src/Admin-web/src/store/alert.context.jsx`:
  ```javascript
  const { settings } = useSettings();
  const activeDuration = settings?.toastDuration || 4500;
  // Trong hàm showToast:
  setTimeout(() => removeToast(id), activeDuration);
  ```

---

#### 2.3. Huy hiệu số lượng thông báo chưa đọc (Show Unread Badge)
* **Mô tả hành vi:**
  - Toggle Switch Bật/Tắt: Mặc định BẬT (`showUnreadBadge = true`).
  - Khi Bật: Icon chuông trên Header hiển thị chấm đỏ số lượng đếm ngược (ví dụ: `3`, `12`, `99+`) nhấp nháy.
  - Khi Tắt: Chấm đỏ số lượng bị ẩn hoàn toàn, chuông hiển thị tĩnh tinh tế, không làm mất tập trung của Admin.
* **Nguyên lý kỹ thuật:**
  - Sửa `src/Admin-web/src/components/layout/Header.jsx`:
  ```jsx
  {settings.showUnreadBadge && unreadCount > 0 && (
    <span className="absolute top-1 right-1 min-w-[18px] h-[18px] bg-red-600 text-white text-[10px] font-bold rounded-full flex items-center justify-center px-1 shadow-sm animate-pulse">
      {unreadCount > 99 ? '99+' : unreadCount}
    </span>
  )}
  ```

---

### DANH MỤC 3: THỜI GIAN THỰC & SOCKET

#### 3.1. Trạng thái kết nối Socket Live & Đo độ trễ (Ping Test)
* **Mô tả hành vi:**
  - **Trạng thái thực tế:** Không dùng text cố định. Lắng nghe trực tiếp `socket.on('connect')` và `socket.on('disconnect')`:
    - Nếu kết nối: Card xanh lá, chấm xanh ping nhấp nháy, hiển thị `"Trực Tuyến — Socket ID: abc...xyz"`, badge `"Cổng 3000 (Active)"`.
    - Nếu mất kết nối: Card đỏ, chấm đỏ, hiển thị `"Mất Kết Nối (Offline)"`, kèm nút **"Kết nối lại ngay"** (`socket.connect()`).
  - **Tính năng Đo Độ Trễ (Ping Latency Test):**
    - Thêm nút **"Kiểm tra độ trễ (Ping Test)"**.
    - Bấm nút: Gửi event `admin_ping` lên Backend (Backend đã có sẵn handler tại `src/Backend/core/socket.js:82`).
    - Tính thời gian phản hồi tròn (Round-trip time):
      - `< 30ms`: Xanh lá (`18ms — Cực tốt`)
      - `30ms - 100ms`: Vàng (`65ms — Ổn định`)
      - `> 100ms`: Đỏ (`140ms — Độ trễ cao`)
* **Nguyên lý kỹ thuật:**
  ```javascript
  const testPingLatency = async () => {
    if (!socket || !socket.connected) return null;
    const start = performance.now();
    return new Promise((resolve) => {
      socket.timeout(5000).emit('admin_ping', (err) => {
        if (err) resolve(-1);
        else resolve(Math.round(performance.now() - start));
      });
    });
  };
  ```

---

#### 3.2. Tần suất nhịp tim AIOps Metrics (Metrics Interval)
* **Mô tả hành vi:**
  - Dropdown có 4 mức: `1` (1 giây - Thời gian thực cao), `3` (3 giây - Mặc định chuẩn), `5` (5 giây - Tiết kiệm tải), `10` (10 giây - Tiết kiệm tối đa).
  - Tác động: Điều khiển chu kỳ lấy mẫu `/health/metrics` và chu kỳ vẽ lại biểu đồ tài nguyên phần cứng (CPU, RAM, Event Loop lag, Threat Score) trên trang `AIOpsPage.jsx`.
* **Nguyên lý kỹ thuật:**
  - Sửa `src/Admin-web/src/pages/aiops/AIOpsPage.jsx`:
  ```javascript
  const { settings } = useSettings();
  const pollingRateMs = (settings?.metricsInterval || 3) * 1000;
  useEffect(() => {
    const timer = setInterval(fetchMetrics, pollingRateMs);
    return () => clearInterval(timer);
  }, [pollingRateMs]);
  ```

---

### DANH MỤC 4: BẢO MẬT & THÔNG TIN

#### 4.1. Tự động khóa an toàn khi không hoạt động (Auto Lock Screen)
* **Mô tả hành vi:**
  - Dropdown có 4 mức: `15` (15 phút), `30` (30 phút - Khuyên dùng), `60` (60 phút), `0` (Không bao giờ).
  - Nút **"🔒 Khóa ngay bây giờ" (Lock Now)**: Cho phép Admin bấm khóa lập tức trước khi rời bàn làm việc.
  - Khi khóa: Xuất hiện màn hình `LockScreenModal.jsx` che phủ toàn màn hình (Z-index 9999).
    - Hiển thị ảnh Avatar, Tên Admin, Email, và nhãn *"Phiên làm việc đã bị tạm khóa để bảo vệ an toàn"*.
    - Form nhập **Mật khẩu quản trị**:
      - Nhập đúng mật khẩu: Mở khóa ngay lập tức, quay lại màn hình đang làm việc dở dang, **giữ nguyên toàn bộ dữ liệu form chưa submit**.
      - Nhập sai mật khẩu: Báo đỏ *"Mật khẩu không chính xác, vui lòng thử lại"*.
    - Nút **"Đăng xuất"**: Cho phép thoát ra hoàn toàn về trang Đăng nhập nếu cần.
* **Nguyên lý kỹ thuật:**
  - Lắng nghe các sự kiện: `['mousemove', 'mousedown', 'keydown', 'touchstart', 'scroll']`.
  - Cập nhật `lastActivityTime = Date.now()`.
  - Timer kiểm tra mỗi 10 giây: nếu `Date.now() - lastActivityTime > autoLockMinutes * 60 * 1000` thì set `isLocked = true`.
  - Xác thực mở khóa: Gọi `authApi.login({ username: user.username, password })`.

---

#### 4.2. Dọn dẹp bộ nhớ đệm an toàn (Safe Local Cache Cleanup)
* **Mô tả hành vi:**
  - Hiển thị chính xác dung lượng LocalStorage đang sử dụng (ví dụ: `~42.8 KB / 5 MB`).
  - Bấm nút **"Xóa Cache"**: Mở Modal xác nhận chuyên nghiệp (không dùng `window.confirm` xấu).
  - Thực hiện dọn dẹp chọn lọc:
    - Xóa các bộ lọc tìm kiếm tạm, cache danh mục tạm, lịch sử tìm kiếm.
    - **Tuyệt đối BẢO TOÀN:** `access_token`, `refresh_token`, `admin_user`, `admin_system_settings`.
    - Sau khi xóa: Không bị văng phiên đăng nhập, hiển thị Toast xanh *"Đã dọn dẹp sạch sẽ bộ nhớ đệm cục bộ thành công!"*.
* **Nguyên lý kỹ thuật:**
  ```javascript
  const safeClearCache = () => {
    const keepKeys = [STORAGE_KEYS.ACCESS_TOKEN, STORAGE_KEYS.REFRESH_TOKEN, STORAGE_KEYS.USER, 'admin_system_settings'];
    const backup = {};
    keepKeys.forEach(k => { backup[k] = localStorage.getItem(k); });
    localStorage.clear();
    keepKeys.forEach(k => {
      if (backup[k]) localStorage.setItem(k, backup[k]);
    });
  };
  ```

---

#### 4.3. Thông tin nền tảng thời gian thực (Platform Runtime Metadata)
* **Mô tả hành vi:**
  - Thay thế các dòng text hard-code tĩnh bằng dữ liệu thực tế được đọc trực tiếp từ môi trường runtime:
    - **Phiên bản quản trị:** `FinanceAdmin v2.5.0-Enterprise` (đọc từ `package.json` hoặc hằng số build).
    - **Môi trường:** `Development (Localhost:5173)` hoặc `Production (Vercel/Render)`.
    - **Cổng kết nối Backend:** Đọc trực tiếp từ `import.meta.env.VITE_API_URL || 'http://localhost:3000'`.
    - **Mã kết nối Socket ID:** Hiển thị `socket?.id || 'Chưa kết nối'` để tiện tra cứu log đối soát.
    - **Dung lượng lưu trữ cục bộ:** `(JSON.stringify(localStorage).length / 1024).toFixed(1) + ' KB'`.

---

## 🛠️ KẾ HOẠCH TRIỂN KHAI THEO TỪNG BƯỚC (BITE-SIZED TDD TASKS)

### Task 1: Xây Dựng `SoundService` (Web Audio API)
- File: `src/Admin-web/src/services/sound.service.js`
- Test: `src/Admin-web/src/tests/sound.service.test.jsx`
- Mục tiêu: Phát âm thanh cảnh báo độc lập, 0 dependency.

### Task 2: Xây Dựng `SettingsContext` Cốt Lõi
- File: `src/Admin-web/src/store/settings.context.jsx`
- Test: `src/Admin-web/src/tests/settings.context.test.jsx`
- Mục tiêu: Quản lý 10 cấu hình, persist LocalStorage, Inactivity Watcher, Theme/Density DOM side-effects.

### Task 3: Cập Nhật CSS Toàn Cục & App Layout
- File: `src/Admin-web/src/index.css`, `src/Admin-web/src/App.jsx`
- Mục tiêu: Bọc `SettingsProvider`, kích hoạt Dark Mode và Compact Table Density.

### Task 4: Hiện Thực Cảnh Báo Âm Thanh, Toast Duration & Header Bell
- File: `src/Admin-web/src/store/alert.context.jsx`, `src/Admin-web/src/components/layout/Header.jsx`
- Test: `src/Admin-web/src/tests/alert.system.test.jsx`
- Mục tiêu: Còi báo khi có AIOps Critical, thời gian Toast tự động theo cấu hình, ẩn/hiện badge chuông.

### Task 5: Hiện Thực Màn Hình Khóa `LockScreenModal.jsx`
- File: `src/Admin-web/src/components/layout/LockScreenModal.jsx`, `src/Admin-web/src/components/layout/AppLayout.jsx`
- Mục tiêu: Giao diện khóa an toàn, form nhập mật khẩu mở khóa giữ nguyên trạng thái làm việc.

### Task 6: Tích Hợp Toàn Bộ 4 Danh Mục Vào `SettingsModal.jsx`
- File: `src/Admin-web/src/components/layout/SettingsModal.jsx`
- Mục tiêu: Nối toàn bộ UI trong 4 tab với `useSettings()`, thêm nút Ping Test, nút Nghe thử âm thanh, nút Khóa ngay.

### Task 7: Kiểm Thử Toàn Diện & Verification
- Test: Chạy toàn bộ test suite `rtk npm test` (đảm bảo 65+ tests hiện có + các test mới đều PASS 100%).
- Build: Chạy `rtk npm run build` (0 lỗi).
- CodeGraph: Đồng bộ CodeGraph `rtk npx codegraph build`.
