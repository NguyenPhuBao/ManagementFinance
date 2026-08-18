# Implementation Plan: Bổ sung Chọn Ví vào Giao diện Thêm Giao Dịch

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bổ sung phần chọn ví thanh toán (Thu/Chi) và ví nguồn / ví đích (Chuyển khoản) vào giao diện `AddTransactionPage` trong ứng dụng Flutter và cập nhật thiết kế trên Stitch.

**Architecture:** Sử dụng Flutter StatefulWidget trong `add_transaction_page.dart` để điều khiển hiển thị hàng chọn ví, mở Modal Bottom Sheet `_showWalletPickerBottomSheet` chọn ví và phản hồi linh hoạt với từng chế độ giao dịch (Chi tiêu, Thu nhập, Chuyển khoản).

**Tech Stack:** Flutter, Material Design (ModalBottomSheet, InkWell, Custom Cards), StitchMCP.

## Global Constraints

- Preserving Design System: Tuân thủ màu sắc `AppColors`, góc bo rounded 12px, font Inter, thấu cảm Kinetic Finance.
- Preserving standard behavior: Tương thích với `GoRouter` và cấu trúc Flutter BLoC/Cubit hiện tại của ứng dụng.

---

### Task 1: Cập nhật Stitch Design Screen
**Files:**
- Stitch Screen ID: `40e508e64b5747f8a47cba469a844ad4`

- [ ] **Step 1: Gọi StitchMCP edit_screens**

Gọi tool `mcp_StitchMCP_edit_screens` với:
- `projectId`: `5106367939423432838`
- `selectedScreenIds`: `['40e508e64b5747f8a47cba469a844ad4']`
- `prompt`: "Bổ sung phần chọn ví thanh toán (Tên ví, số dư) vào form nhập giao dịch. Nếu chọn chuyển khoản thì hỗ trợ chọn Ví nguồn và Ví đích."

---

### Task 2: Implement UI Chọn Ví trên AddTransactionPage Flutter
**Files:**
- Modify: `src/Client-app/lib/features/transaction/presentation/pages/add_transaction_page.dart`

**Interfaces:**
- Produces: `_buildFormCard()` cập nhật trường Ví thanh toán/Ví nguồn/Ví đích và hàm `_showWalletPickerBottomSheet()`.

- [ ] **Step 1: Cập nhật `add_transaction_page.dart` với trường ví và Bottom Sheet**

Cập nhật `_AddTransactionPageState`:
- Thêm biến state `String _selectedWalletName = 'Ví chính • 15.000.000đ';`
- Thêm biến state `String _destinationWalletName = 'Tài khoản Tiết kiệm • 50.000.000đ';`
- Thêm widget `_showWalletPickerBottomSheet(BuildContext context, {required bool isDestination})`.
- Cập nhật `_buildFormCard()`:
  - Khi `_selectedSegment != 2` (Chi tiêu / Thu nhập): hiển thị dòng Ví thanh toán + Danh mục + Ghi chú + Ngày.
  - Khi `_selectedSegment == 2` (Chuyển khoản): hiển thị dòng Ví nguồn + Ví đích + Ghi chú + Ngày (ẩn Danh mục).

- [ ] **Step 2: Kiểm tra biên dịch**

Chạy: `flutter build web` trong `src/Client-app` để đảm bảo không bị lỗi syntax/compilation.

- [ ] **Step 3: Commit**

```bash
git add src/Client-app/lib/features/transaction/presentation/pages/add_transaction_page.dart
git commit -m "feat: add wallet selection section to add transaction page"
```
