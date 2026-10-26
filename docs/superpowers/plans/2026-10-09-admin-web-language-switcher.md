# 📘 Kế Hoạch Triển Khai: Chuyển Đổi Ngôn Ngữ Admin-Web (Tiếng Việt & Tiếng Anh)

> **Dự án:** Personal Finance Management — Module `src/Admin-web`  
> **Tài liệu nguồn sự thật:** `docs/superpowers/plans/2026-10-09-admin-web-language-switcher.md`  
> **Trạng thái:** Chờ Product Owner (PO) phê duyệt (Phase 1: Scope & Plan)  
> **Mục tiêu:** Xây dựng hệ thống đa ngôn ngữ nội bộ Admin-web hỗ trợ 2 ngôn ngữ chính (Tiếng Việt `vi` và Tiếng Anh `en`), nút chuyển đổi dạng pill toggle `[ EN | VI ]` trên Header đúng theo thiết kế người dùng cung cấp, kèm bộ từ điển chuẩn hóa toàn giao diện và kiểm thử 2 tầng (UI + System Impact).

---

## 🏛️ TỔNG QUAN KIẾN TRÚC HỆ THỐNG ĐA NGÔN NGỮ

```mermaid
graph TD
    subgraph "Core State & Persistence"
        LS[(LocalStorage: admin_language)] <--> LC[LanguageContext / LanguageProvider]
        LC -->|setAttribute 'lang'| DOM_HTML[document.documentElement lang='vi' / 'en']
    end

    subgraph "Language Dictionaries (Locales)"
        VI[vi.js: Tiếng Việt chuẩn] --> Dictionary[Dictionary Registry]
        EN[en.js: Tiếng Anh chuẩn] --> Dictionary
        Dictionary --> LC
    end

    subgraph "UI Controls & Toggles"
        LC -->|useLanguage: language, t, changeLanguage| HeaderPill[LanguageToggle.jsx: Pill Switch EN | VI]
        LC -->|useLanguage| SettingsTab[SettingsModal.jsx: Tab Giao diện]
    end

    subgraph "Consumer Components"
        HeaderPill -->|1-Click Switch| LC
        LC -->|Instant Re-render| Sidebar[Sidebar.jsx: Menus & Logout]
        LC -->|Instant Re-render| Header[Header.jsx: Notifications, Alerts]
        LC -->|Instant Re-render| Dashboard[DashboardPage.jsx: Cards, Charts, Tables]
        LC -->|Instant Re-render| AllPages[Users, Categories, AIOps, Broadcast, Audit, Permissions]
    end
```

### 1. Nguyên Tắc Thiết Kế Cốt Lõi
1. **Nội bộ độc lập 100%:** Chỉ chạy trong phạm vi `src/Admin-web`, không phụ thuộc API Backend, không làm phình bundle size (0 dependency bên ngoài, thuần React Context + JavaScript dictionaries).
2. **Thiết kế UI chuẩn xác theo yêu cầu người dùng:** Nút chuyển đổi dạng pill toggle bo tròn `[ EN | VI ]` đặt tại Header cạnh icon chuông thông báo, hiển thị tooltip *"Ngôn ngữ giao diện"* (*"Interface language"*) khi hover.
3. **Chuyển ngữ tức thời (Zero Reload):** Chuyển đổi ngôn ngữ cập nhật ngay lập tức toàn bộ giao diện thông qua React Context mà không cần tải lại trang.
4. **Bền vững & Khôi phục tự động:** Ghi nhớ ngôn ngữ đã chọn vào `localStorage` (`admin_language`), mặc định là Tiếng Việt (`vi`).
5. **Cơ chế Fallback an toàn:** Nếu một key chưa có bản dịch Tiếng Anh, tự động hiển thị Tiếng Việt dự phòng, tuyệt đối không hiển thị màn hình trắng hay vỡ giao diện.
6. **Tuân thủ Kiểm thử 2 Tầng (Rule 11):**
   * *Tầng 1 (UI Rendering & Interaction):* Render đúng pill toggle, active side nổi bật màu xanh, hover hiển thị tooltip, click chuyển trạng thái mượt mà.
   * *Tầng 2 (Real System Impact):* Lưu đúng `localStorage`, cập nhật thuộc tính `document.documentElement.lang`, re-render các chuỗi text thực tế trên Sidebar và Header sang ngôn ngữ tương ứng.

---

## 🎨 THIẾT KẾ GIAO DIỆN NÚT CHUYỂN ĐỔI (PILL TOGGLE)

Theo hình ảnh thực tế người dùng cung cấp:

```
           Tooltip hover:
      ┌─────────────────────────┐
      │   Ngôn ngữ giao diện    │
      └────────────▲────────────┘
                   │
      ┌────────────┴────────────┐
      │    ┌──────┬────────┐    │
      │    │  EN  │   VI   │    │
      │    └──────┴────────┘    │
      └─────────────────────────┘
```

* **Vị trí:** Trên thanh Header bar (`Header.jsx`), nằm giữa cụm icon Chuông thông báo (`notifications`) và Cài đặt (`settings`).
* **Trạng thái khi chọn Tiếng Việt (`VI`):**
  * Phần `VI`: Nền xanh dương `bg-blue-600 text-white font-bold shadow-xs`, bo góc `rounded-full`.
  * Phần `EN`: Chữ xanh nhạt `text-blue-500 font-semibold hover:text-blue-700`.
* **Trạng thái khi chọn Tiếng Anh (`EN`):**
  * Phần `EN`: Nền xanh dương `bg-blue-600 text-white font-bold shadow-xs`, bo góc `rounded-full`.
  * Phần `VI`: Chữ xanh nhạt `text-blue-500 font-semibold hover:text-blue-700`.
* **Tooltip nổi bật:** Hộp đen bo góc mềm mại `bg-slate-800 text-white text-xs px-2.5 py-1 rounded-md shadow-lg pointer-events-none whitespace-nowrap` kèm mũi tên chỉ ngược lên nút pill.

---

## 📂 CẤU TRÚC TỆP TIN TRIỂN KHAI

```
src/Admin-web/src/
├── locales/
│   ├── vi.js                        # Từ điển Tiếng Việt (Source of Truth)
│   ├── en.js                        # Từ điển Tiếng Anh đối ứng
│   └── index.js                     # Export vi, en, SUPPORTED_LANGUAGES, DEFAULT_LANGUAGE
├── store/
│   └── language.context.jsx         # LanguageContext, LanguageProvider, useLanguage, useLanguageSafe
├── components/
│   ├── common/
│   │   └── LanguageToggle.jsx       # Component Pill Toggle [ EN | VI ] + Tooltip
│   └── layout/
│       ├── Header.jsx               # Tích hợp LanguageToggle vào thanh điều khiển
│       ├── Sidebar.jsx              # Dịch toàn bộ menu điều hướng & nút Đăng xuất
│       ├── AppLayout.jsx            # Dịch các thông báo khẩn & Toast bảo mật
│       └── SettingsModal.jsx        # Bổ sung lựa chọn ngôn ngữ trong Tab Giao diện
├── tests/
│   └── language.system.test.jsx     # Bộ kiểm thử 2 tầng (UI + System Impact)
└── App.jsx                          # Bọc <LanguageProvider> vào tầng ứng dụng
```

---

## 📋 CHI TIẾT CÁC BƯỚC THỰC THI (TASKS)

---

### Task 1: Xây Dựng Bộ Từ Điển Ngôn Ngữ Song Ngữ (`src/Admin-web/src/locales/`)

**Tệp tin:**
* Tạo mới: `src/Admin-web/src/locales/vi.js`
* Tạo mới: `src/Admin-web/src/locales/en.js`
* Tạo mới: `src/Admin-web/src/locales/index.js`

**Nội dung bộ từ điển chuẩn hóa theo namespace:**
* `common`: Các nút bấm, nhãn chung (`confirm`, `cancel`, `save`, `delete`, `edit`, `filter`, `reset`, `refresh`, `loading`, `noData`, `statusActive`, `statusInactive`...).
* `nav`: Menu Sidebar (`dashboard`, `aiops`, `users`, `permissions`, `categories`, `auditLogs`, `broadcast`, `logout`, `brandTitle`).
* `header`: Tooltip ngôn ngữ (`languageTooltip: 'Ngôn ngữ giao diện'`), Thông báo (`notifications`, `newAlerts`, `allCaughtUp`, `systemStable`...).
* `settings`: Tiêu đề modal, 4 tabs (`general`, `notifications`, `realtime`, `system`), các nhãn cài đặt (`themeLight`, `themeDark`, `languageTitle`...).
* `dashboard`: Tiêu đề, thẻ thống kê, biểu đồ (`loginFrequency`, `requestTraffic`, `recentActivities`...).
* `users`: Quản trị người dùng, chi tiết, trạng thái 4 mức, lý do vô hiệu hóa...
* `categories`: Danh mục mặc định, loại (`income`, `expense`, `debt`), thêm/sửa/xóa...
* `permissions`: Phân quyền gói cước, 4 nhóm tính năng, hạn mức...
* `aiops`: Sentinel, Threat score, 4 vectors, danh sách cách ly, nút phong tỏa IP...
* `broadcast`: Bảo trì khẩn cấp, lên lịch bảo trì, phát thông báo...

---

### Task 2: Xây Dựng Context & Hook Quản Lý Ngôn Ngữ (`LanguageContext`)

**Tệp tin:**
* Tạo mới: `src/Admin-web/src/store/language.context.jsx`
* Sửa đổi: `src/Admin-web/src/App.jsx`

**Đặc tả kỹ thuật:**
* Quản lý state `language` (`'vi'` hoặc `'en'`), khởi tạo từ `localStorage.getItem('admin_language') || 'vi'`.
* Hàm `changeLanguage(newLang)`: Cập nhật state và lưu vào `localStorage`.
* **System Impact Hook (Tầng 2):**
  ```javascript
  useEffect(() => {
    document.documentElement.setAttribute('lang', language);
    document.documentElement.setAttribute('data-language', language);
  }, [language]);
  ```
* Hàm dịch `t(keyPath, params)`:
  * Truy xuất nested object theo chuỗi phân tách dấu chấm: `t('nav.dashboard')`.
  * Tự động fallback: nếu key không tìm thấy trong Tiếng Anh, lấy giá trị Tiếng Việt dự phòng; nếu vẫn không có, trả về chính `keyPath`.
  * Hỗ trợ chèn biến (Interpolation): `t('users.itemCount', { count: 5 })` $\rightarrow$ `"Hiển thị 5 người dùng"`.
* Bọc `<LanguageProvider>` trong `App.jsx` ở cấp cao nhất bao bọc toàn bộ router.

---

### Task 3: Xây Dựng Component Nút Chuyển Đổi Ngôn Ngữ (`LanguageToggle.jsx`)

**Tệp tin:**
* Tạo mới: `src/Admin-web/src/components/common/LanguageToggle.jsx`
* Sửa đổi: `src/Admin-web/src/components/layout/Header.jsx`

**Đặc tả UI & Hành vi:**
* Cấu trúc HTML & Tailwind CSS:
  ```jsx
  <div className="relative group inline-flex items-center" data-testid="language-toggle">
    <div className="flex items-center p-0.5 rounded-full border border-slate-200/90 bg-slate-100/80 shadow-2xs">
      <button
        type="button"
        data-testid="lang-btn-en"
        onClick={() => changeLanguage('en')}
        className={`px-2.5 py-0.5 text-xs font-bold rounded-full transition-all cursor-pointer ${
          isEnglish
            ? 'bg-blue-600 text-white shadow-xs'
            : 'text-blue-500 hover:text-blue-700'
        }`}
      >
        EN
      </button>
      <button
        type="button"
        data-testid="lang-btn-vi"
        onClick={() => changeLanguage('vi')}
        className={`px-2.5 py-0.5 text-xs font-bold rounded-full transition-all cursor-pointer ${
          isVietnamese
            ? 'bg-blue-600 text-white shadow-xs'
            : 'text-blue-500 hover:text-blue-700'
        }`}
      >
        VI
      </button>
    </div>
    
    {/* Tooltip nổi bên dưới khi hover */}
    <div className="absolute top-full left-1/2 -translate-x-1/2 mt-2 hidden group-hover:flex flex-col items-center z-50 pointer-events-none">
      <div className="w-0 h-0 border-x-4 border-x-transparent border-b-4 border-b-slate-800"></div>
      <div className="px-2.5 py-1 bg-slate-800 text-white text-[11px] font-medium rounded-md shadow-lg whitespace-nowrap">
        {t('header.languageTooltip')}
      </div>
    </div>
  </div>
  ```
* Tích hợp vào `Header.jsx`: Nằm bên cạnh icon Chuông thông báo, hiển thị cân đối và rõ nét trên mọi kích thước màn hình.

---

### Task 4: Tích Hợp Lựa Chọn Ngôn Ngữ Vào SettingsModal

**Tệp tin:**
* Sửa đổi: `src/Admin-web/src/components/layout/SettingsModal.jsx`

**Đặc tả:**
* Trong Tab 1 ("Giao Diện & Hiển Thị"), bổ sung khối cài đặt **"Ngôn ngữ giao diện"** với 2 nút chọn:
  * Tiếng Việt (VI)
  * English (EN)
* Kết nối trực tiếp với `useLanguage()`: khi Admin đổi ngôn ngữ trong SettingsModal, Header pill toggle lập tức chuyển đổi theo và ngược lại.

---

### Task 5: Chuyển Đổi & Thống Nhất Ngôn Ngữ Trên Các Thành Phần Giao Diện

**Tệp tin:**
* Sửa đổi: `src/Admin-web/src/components/layout/Sidebar.jsx` (dịch các mục điều hướng, tiêu đề Admin, nút Logout)
* Sửa đổi: `src/Admin-web/src/components/layout/Header.jsx` (dịch tooltip, tiêu đề dropdown cảnh báo, nút Làm mới)
* Sửa đổi: `src/Admin-web/src/components/layout/AppLayout.jsx` (dịch banner cảnh báo hạ tầng đỏ và toast chặn an ninh)
* Sửa đổi: `src/Admin-web/src/components/layout/LockScreenModal.jsx` (dịch thông báo khóa an toàn, nút mở khóa)

---

### Task 6: Viết Bộ Kiểm Thử TDD 2 Tầng Toàn Diện (`language.system.test.jsx`)

**Tệp tin:**
* Tạo mới: `src/Admin-web/src/tests/language.system.test.jsx`

**Ma trận kiểm thử 2 tầng:**
1. **Tầng 1 (Hiển thị & Tương tác giao diện):**
   * Test 1.1: Render đầy đủ component `LanguageToggle` với 2 nút `EN` và `VI`.
   * Test 1.2: Hiển thị đúng active state (mặc định nút `VI` có class `bg-blue-600 text-white`).
   * Test 1.3: Hiển thị đúng tooltip "Ngôn ngữ giao diện" khi rê chuột.
   * Test 1.4: Thao tác click chuyển sang `EN` đổi active class sang nút `EN` mà không crash ứng dụng.
2. **Tầng 2 (Tác động hệ thống thực tế — Real System Impact):**
   * Test 2.1: **Tác động Persistence:** `localStorage.getItem('admin_language')` lưu giá trị `'en'` khi click `EN` và `'vi'` khi click `VI`.
   * Test 2.2: **Tác động Root DOM:** `document.documentElement.getAttribute('lang')` chuyển đổi chuẩn xác giữa `'vi'` và `'en'`.
   * Test 2.3: **Tác động Re-render dịch thuật:** Toàn bộ Sidebar menu (`Dashboard` $\rightarrow$ `Bảng điều khiển`, `Logout` $\rightarrow$ `Đăng xuất`) và Header tự động dịch sang ngôn ngữ tương ứng.
   * Test 2.4: **Tác động Đồng bộ hai chiều:** Đổi ngôn ngữ trong `SettingsModal` tự động cập nhật nút pill trên `Header` và ngược lại.
   * Test 2.5: **Cơ chế Fallback an toàn:** Khi truy vấn key không tồn tại trong từ điển EN, tự động lấy giá trị từ điển VI dự phòng, không quăng lỗi exception.

---

## 🔍 TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA)
- [ ] Giao diện nút chuyển đổi dạng pill `[ EN | VI ]` hiển thị chuẩn xác như hình ảnh mô tả.
- [ ] Tooltip `"Ngôn ngữ giao diện"` (hoặc `"Interface language"`) hiển thị mượt mà.
- [ ] Chuyển đổi ngôn ngữ hoạt động tức thì trên toàn giao diện Admin-web mà không cần reload trang.
- [ ] Lưu trạng thái ngôn ngữ bền vững vào `localStorage` (`admin_language`) và gán thuộc tính `lang` lên thẻ `<html>`.
- [ ] Bộ từ điển Tiếng Việt & Tiếng Anh được tổ chức khoa học, dễ bảo trì và dễ mở rộng.
- [ ] Bộ test 2 tầng mới (`language.system.test.jsx`) đạt **PASS 100%**.
- [ ] Toàn bộ test suite Admin-web và Backend tiếp tục đạt **PASS 100%**, không có bất kỳ lỗi hồi quy nào.
- [ ] Lệnh đóng gói `rtk npm run build` trên `src/Admin-web` hoàn thành sạch sẽ 0 lỗi.
