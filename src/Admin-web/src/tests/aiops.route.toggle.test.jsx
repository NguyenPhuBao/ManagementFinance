import React from 'react';
import { render, screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import routes from '../router/routes';

// Đặc tả: docs/Admin-web/09-aiops-sentinel-and-quarantine.md, mục "Trạng thái: tạm dừng" (2026-11-17).
vi.mock('../pages/system/AIOpsPage', () => ({ default: () => <div>trang AIOps</div> }));

const renderAt = (path) => {
  const aiops = routes.find((r) => r.path === '/aiops');
  return render(
    <MemoryRouter initialEntries={[path]}>
      <Routes>
        <Route path="/aiops" element={aiops.element} />
        <Route path="/dashboard" element={<div>trang Dashboard</div>} />
      </Routes>
    </MemoryRouter>
  );
};

afterEach(() => vi.unstubAllEnvs());

describe('Route /aiops theo công tắc VITE_AIOPS_ENABLED', () => {
  it('tắt (mặc định): /aiops chuyển về Dashboard, không dựng trang AIOps', () => {
    vi.stubEnv('VITE_AIOPS_ENABLED', '');
    renderAt('/aiops');
    expect(screen.getByText('trang Dashboard')).toBeInTheDocument();
    expect(screen.queryByText('trang AIOps')).not.toBeInTheDocument();
  });

  it('bật: /aiops hiện trang AIOps', () => {
    vi.stubEnv('VITE_AIOPS_ENABLED', 'true');
    renderAt('/aiops');
    expect(screen.getByText('trang AIOps')).toBeInTheDocument();
  });
});
