// Công tắc tính năng đọc lúc build (Vercel). Đọc mỗi lần gọi để test đổi được bằng vi.stubEnv.
// AIOps tạm dừng (2026-11-17): chỉ bật khi VITE_AIOPS_ENABLED = 'true', và phải bật cùng AIOPS_ENABLED ở Backend.
export const isAiopsEnabled = () => import.meta.env.VITE_AIOPS_ENABLED === 'true';
