import React, { useState, useEffect } from 'react';
import { USER_STATUS_LABELS } from '../../utils/constants';
import adminApi from '../../api/admin.api';
import UserDetailModal from '../../components/common/UserDetailModal';

const UserListPage = () => {
  const [loading, setLoading] = useState(true);
  const [users, setUsers] = useState([]);
  const [search, setSearch] = useState('');
  
  const [modals, setModals] = useState({
      filter: false,
      blockAlert: false
  });
  const [userToBlock, setUserToBlock] = useState(null);
  const [detailUserId, setDetailUserId] = useState(null);

  const [filter, setFilter] = useState({ location: 'all', status: 'all' });
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  const filteredUsers = users.filter((u) => {
    const matchSearch = u.name.toLowerCase().includes(search.toLowerCase()) || u.email.toLowerCase().includes(search.toLowerCase()) || (u.phone || '').includes(search);
    const matchStatus = filter.status === 'all' || u.status === filter.status;
    const matchLocation = filter.location === 'all' || 
      (filter.location === 'hcm' && (u.address || '').toLowerCase().includes('hồ chí minh')) ||
      (filter.location === 'hn' && (u.address || '').toLowerCase().includes('hà nội')) ||
      (filter.location === 'dn' && (u.address || '').toLowerCase().includes('đà nẵng')) ||
      (filter.location === 'ct' && (u.address || '').toLowerCase().includes('cần thơ'));
    return matchSearch && matchStatus && matchLocation;
  });

  const totalPages = Math.ceil(filteredUsers.length / itemsPerPage);
  const start = (currentPage - 1) * itemsPerPage;
  const end = Math.min(start + itemsPerPage, filteredUsers.length);
  const pageData = filteredUsers.slice(start, end);

  useEffect(() => {
    const fetchUsers = async () => {
      try {
        const res = await adminApi.getUsers();
        const mapped = res.data.map((u) => ({
          id: u.id,
          name: u.fullname,
          email: u.email,
          phone: u.phone || '—',
          status: u.status ? u.status.toLowerCase() : 'active',
          address: u.address || '',
          username: u.username,
          created_at: u.created_at,
        }));
        setUsers(mapped);
      } catch (err) {
        console.error('Lỗi tải danh sách người dùng:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchUsers();
  }, []);

  const toggleModal = (modalName, isOpen) => {
    setModals(prev => ({ ...prev, [modalName]: isOpen }));
  };

  const handleBlockClick = (user) => {
    setUserToBlock(user);
    toggleModal('blockAlert', true);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const confirmBlock = async () => {
    if (!userToBlock) return;
    try {
      await adminApi.updateUserStatus(userToBlock.id);
      // Cập nhật UI local sau khi API thành công
      setUsers(users.map(u =>
        u.id === userToBlock.id
          ? { ...u, status: u.status === 'active' ? 'inactive' : 'active' }
          : u
      ));
    } catch (err) {
      console.error('Lỗi cập nhật trạng thái:', err);
    }
    setUserToBlock(null);
    toggleModal('blockAlert', false);
  };

  return (
    <>
    <div className="bg-surface-bright relative p-4 md:p-6 min-h-full">
      {modals.blockAlert && (
          <div className="mb-6 bg-surface-container-low border border-error-container rounded-lg p-4 flex flex-col md:flex-row items-center justify-between gap-4 animate-in fade-in zoom-in-95 duration-200">
              <div className="flex items-center gap-3 text-on-surface">
                  <span className="material-symbols-outlined text-error">warning</span>
                  <p className="font-body-lg">
                      Bạn có chắc chắn muốn {userToBlock?.status === 'active' ? 'vô hiệu hóa' : 'kích hoạt'} tài khoản <strong>{userToBlock?.name}</strong> hay không?
                  </p>
              </div>
              <div className="flex items-center gap-3">
                  <button className="px-4 py-1.5 bg-error text-white rounded font-label-md hover:opacity-90 transition-colors cursor-pointer shadow-sm" onClick={confirmBlock}>Xác nhận</button>
                  <button className="px-4 py-1.5 bg-surface-container-high text-on-surface rounded font-label-md hover:bg-surface-container-low transition-colors cursor-pointer" onClick={() => { setUserToBlock(null); toggleModal('blockAlert', false); }}>Hủy bỏ</button>
              </div>
          </div>
      )}

      <div className="max-w-[1440px] mx-auto w-full">
          <div className="flex flex-col md:flex-row md:items-center justify-between mb-stack-lg gap-4">
              <div>
                  <h2 className="font-headline-md text-headline-md text-on-surface m-0">Quản lý người dùng</h2>
              </div>
              <div className="flex flex-wrap items-center gap-3">
                  <div className="relative w-full md:w-64">
                      <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-outline text-[18px]">search</span>
                      <input 
                          className="w-full pl-10 pr-4 py-2 border border-outline-variant rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary-container focus:border-transparent font-body-md text-body-md text-on-surface shadow-sm" 
                          placeholder="Tìm kiếm người dùng..." 
                          type="text"
                          value={search}
                          onChange={(e) => setSearch(e.target.value)}
                      />
                  </div>
                  <button className="px-4 py-2 border border-outline rounded text-on-surface font-label-md text-label-md hover:bg-surface-container-low transition-colors flex items-center gap-2 cursor-pointer shadow-sm bg-white" onClick={() => toggleModal('filter', true)}>
                      <span className="material-symbols-outlined text-[18px]">filter_alt</span>Bộ lọc
                  </button>
              </div>
          </div>

          <div className="bg-white border border-outline-variant rounded-xl overflow-hidden shadow-sm relative">
              {loading && (
                <div className="absolute inset-0 bg-white bg-opacity-70 z-10 flex items-center justify-center">
                  <span className="material-symbols-outlined animate-spin text-primary text-3xl">progress_activity</span>
                </div>
              )}
              <div className="overflow-x-auto">
                  <table className="w-full text-left border-collapse min-w-[800px]">
                      <thead>
                          <tr className="bg-surface-container-low border-b border-outline-variant">
                              <th className="px-6 py-4 w-12 text-center">
                                  <input type="checkbox" className="w-4 h-4 rounded border-outline-variant text-primary focus:ring-primary cursor-pointer" />
                              </th>
                              <th className="px-6 py-4 font-label-md text-label-md text-on-surface uppercase">Họ tên</th>
                              <th className="px-6 py-4 font-label-md text-label-md text-on-surface uppercase">Email</th>
                              <th className="px-6 py-4 font-label-md text-label-md text-on-surface uppercase">Số điện thoại</th>
                              <th className="px-6 py-4 font-label-md text-label-md text-on-surface uppercase text-center">Trạng thái</th>
                              <th className="px-6 py-4 font-label-md text-label-md text-on-surface uppercase text-right">Hành động</th>
                          </tr>
                      </thead>
                      <tbody className="font-body-md text-body-md text-on-surface">
                          {pageData.length > 0 ? (
                            pageData.map((item, index) => {
                                const isLastRow = index === pageData.length - 1;
                                const rowClass = isLastRow ? 'hover:bg-surface-container-low transition-all duration-200' : 'border-b border-surface-container-high hover:bg-surface-container-low transition-all duration-200';
                                const isActive = item.status === 'active';
                                return (
                                    <tr key={item.id} className={rowClass}>
                                        <td className="px-6 py-4 text-center">
                                            <input type="checkbox" className="w-4 h-4 rounded border-outline-variant text-primary focus:ring-primary cursor-pointer" />
                                        </td>
                                        <td className="px-6 py-4">
                                            <div className="flex items-center gap-3">
                                                <div className="w-8 h-8 rounded-full bg-primary-container text-on-primary-container flex items-center justify-center font-bold text-sm">
                                                    {item.name.charAt(0)}
                                                </div>
                                                <span className="font-semibold">{item.name}</span>
                                            </div>
                                        </td>
                                        <td className="px-6 py-4 text-on-surface-variant">{item.email}</td>
                                        <td className="px-6 py-4 text-on-surface-variant font-tabular-nums">{item.phone}</td>
                                        <td className="px-6 py-4 text-center">
                                            <span className={`inline-flex items-center px-2 py-1 rounded-full font-label-md text-[10px] ${isActive ? 'bg-[#dcfce7] text-[#166534]' : 'bg-surface-container-high text-secondary'}`}>
                                              {USER_STATUS_LABELS[item.status] || item.status}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-right">
                                            <button 
                                                className={`px-3 py-1.5 rounded font-label-md text-[12px] transition-colors shadow-sm cursor-pointer border ${isActive ? 'bg-white border-error text-error hover:bg-error-container' : 'bg-primary border-primary text-white hover:bg-surface-tint'}`} 
                                                onClick={() => handleBlockClick(item)}
                                            >
                                                {isActive ? 'Vô hiệu hóa' : 'Kích hoạt'}
                                            </button>
                                            <button className="p-1.5 text-secondary hover:text-primary transition-colors ml-2 border border-transparent hover:border-on-background rounded cursor-pointer" onClick={() => setDetailUserId(item.id)} title="Xem chi tiết">
                                                <span className="material-symbols-outlined text-[20px]">visibility</span>
                                            </button>
                                        </td>
                                    </tr>
                                );
                            })
                          ) : (
                            <tr>
                              <td colSpan="6" className="px-6 py-8 text-center text-on-surface-variant">
                                Không tìm thấy người dùng nào.
                              </td>
                            </tr>
                          )}
                      </tbody>
                  </table>
              </div>
              
              <div className="px-6 py-4 border-t border-outline-variant bg-surface-bright flex flex-col md:flex-row items-center justify-between gap-4">
                  <span className="font-tabular-nums text-tabular-nums text-on-surface-variant">Hiển thị {filteredUsers.length > 0 ? start + 1 : 0} - {end} của {filteredUsers.length} người dùng</span>
                  <div className="flex items-center gap-1">
                      <button 
                          className={`p-1 rounded transition-colors cursor-pointer active:opacity-80 ${currentPage === 1 ? 'text-outline pointer-events-none' : 'text-on-surface hover:bg-surface-container-low'}`}
                          onClick={() => currentPage > 1 && setCurrentPage(currentPage - 1)}
                          disabled={currentPage === 1}
                      >
                          <span className="material-symbols-outlined text-[20px]">chevron_left</span>
                      </button>
                      {Array.from({ length: totalPages }, (_, i) => i + 1).map(page => (
                          <button
                              key={page}
                              className={page === currentPage 
                                  ? 'w-8 h-8 rounded bg-primary-container text-white font-tabular-nums text-tabular-nums flex items-center justify-center shadow-sm cursor-pointer active:scale-95 transition-all'
                                  : 'w-8 h-8 rounded hover:bg-surface-container-low text-on-surface font-tabular-nums text-tabular-nums flex items-center justify-center transition-colors cursor-pointer active:scale-95'
                              }
                              onClick={() => setCurrentPage(page)}
                          >
                              {page}
                          </button>
                      ))}
                      <button 
                          className={`p-1 rounded transition-colors cursor-pointer active:opacity-80 ${currentPage === totalPages || totalPages === 0 ? 'text-outline pointer-events-none' : 'text-on-surface hover:bg-surface-container-low'}`}
                          onClick={() => currentPage < totalPages && setCurrentPage(currentPage + 1)}
                          disabled={currentPage === totalPages || totalPages === 0}
                      >
                          <span className="material-symbols-outlined text-[20px]">chevron_right</span>
                      </button>
                  </div>
              </div>
          </div>
      </div>

      {/* Filter Modal */}
      {modals.filter && (
          <div className="fixed inset-0 bg-on-background/50 flex items-center justify-center z-50 p-4">
              <div className="bg-white rounded-lg w-full max-w-sm shadow-xl overflow-hidden animate-in fade-in zoom-in duration-200">
                  <div className="px-6 py-4 border-b border-outline-variant flex items-center justify-between bg-surface">
                      <h3 className="font-headline-sm text-on-surface m-0">Lọc dữ liệu</h3>
                      <button className="text-on-surface-variant hover:text-on-surface cursor-pointer" onClick={() => toggleModal('filter', false)}>
                          <span className="material-symbols-outlined">close</span>
                      </button>
                  </div>
                  <div className="p-6 space-y-5">
                      <div>
                          <label className="block text-[11px] font-bold uppercase tracking-wider text-on-surface mb-2">Khu vực (Location)</label>
                          <select value={filter.location} onChange={e => setFilter({...filter, location: e.target.value})} className="w-full px-3 py-2 border border-outline-variant rounded focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary font-body-md bg-white h-[40px] cursor-pointer">
                              <option value="all">Tất cả khu vực</option>
                              <option value="hcm">TP. Hồ Chí Minh</option>
                              <option value="hn">Hà Nội</option>
                              <option value="dn">Đà Nẵng</option>
                              <option value="ct">Cần Thơ</option>
                          </select>
                      </div>
                      <div>
                          <label className="block text-[11px] font-bold uppercase tracking-wider text-on-surface mb-3">Trạng thái</label>
                          <div className="space-y-3">
                              <label className="flex items-center gap-3 cursor-pointer group">
                                  <input type="radio" name="status" value="all" checked={filter.status === 'all'} onChange={e => setFilter({ ...filter, status: e.target.value })} className="w-4 h-4 text-primary focus:ring-primary border-outline-variant" />
                                  <span className="text-on-surface font-body-md group-hover:text-primary transition-colors">Tất cả</span>
                              </label>
                              <label className="flex items-center gap-3 cursor-pointer group">
                                  <input type="radio" name="status" value="active" checked={filter.status === 'active'} onChange={e => setFilter({ ...filter, status: e.target.value })} className="w-4 h-4 text-primary focus:ring-primary border-outline-variant" />
                                  <span className="text-on-surface font-body-md group-hover:text-primary transition-colors">{USER_STATUS_LABELS['active']}</span>
                              </label>
                              <label className="flex items-center gap-3 cursor-pointer group">
                                  <input type="radio" name="status" value="inactive" checked={filter.status === 'inactive'} onChange={e => setFilter({ ...filter, status: e.target.value })} className="w-4 h-4 text-primary focus:ring-primary border-outline-variant" />
                                  <span className="text-on-surface font-body-md group-hover:text-primary transition-colors">{USER_STATUS_LABELS['inactive']}</span>
                              </label>
                          </div>
                      </div>
                  </div>
                  <div className="px-6 py-4 bg-surface-bright border-t border-outline-variant flex justify-end gap-3">
                      <button className="px-4 py-2 border border-outline rounded text-on-surface font-label-md hover:bg-surface-container-low transition-colors cursor-pointer" onClick={() => { setFilter({ location: 'all', status: 'all' }); toggleModal('filter', false); }}>Đặt lại</button>
                      <button className="px-4 py-2 bg-primary text-white rounded font-label-md hover:bg-surface-tint transition-colors cursor-pointer shadow-sm" onClick={() => toggleModal('filter', false)}>Áp dụng</button>
                  </div>
              </div>
          </div>
      )}
    </div>

    {/* User Detail Modal */}
    {detailUserId && (
      <UserDetailModal userId={detailUserId} onClose={() => setDetailUserId(null)} />
    )}
    </>
  );
};

export default UserListPage;
