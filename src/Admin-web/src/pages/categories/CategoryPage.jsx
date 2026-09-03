import React, { useState, useEffect } from 'react';
import { TRANSACTION_TYPE_LABELS } from '../../utils/constants';
import adminApi from '../../api/admin.api';
import Pagination from '../../components/common/Pagination';

const CLASSIFY_MAP = { Thu: 'income', Chi: 'expense', 'Vay/no': 'debt', 'Vay/nợ': 'debt' };
const TYPE_TO_CLASSIFY = { income: 'Thu', expense: 'Chi', debt: 'Vay/no' };

const CategoryPage = () => {
  const [loading, setLoading] = useState(true);
  const [categories, setCategories] = useState([]);
  const [search, setSearch] = useState('');
  const [syncToast, setSyncToast] = useState(null);
  
  const [modals, setModals] = useState({
      add: false,
      edit: false,
      filter: false,
      deleteAlert: false,
      syncAlert: false,
  });
  const [editingCategory, setEditingCategory] = useState(null);
  const [categoryToDelete, setCategoryToDelete] = useState(null);
  const [processing, setProcessing] = useState({ isProcessing: false, text: '' });

  const [form, setForm] = useState({ name: '', isDefault: 'yes', type: 'expense', keyword: '' });
  const [filter, setFilter] = useState({ isDefault: 'all', type: 'all' });

  // Pagination states
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  const filtered = categories.filter(c =>
    c.name.toLowerCase().includes(search.toLowerCase()) &&
    (filter.isDefault === 'all' || (filter.isDefault === 'yes' ? c.isDefault : !c.isDefault)) &&
    (filter.type === 'all' || c.type === filter.type)
  );

  const totalPages = Math.ceil(filtered.length / pageSize) || 1;
  const start = (currentPage - 1) * pageSize;
  const end = Math.min(start + pageSize, filtered.length);
  const pageData = filtered.slice(start, end);

  useEffect(() => {
    setCurrentPage(1);
  }, [search, filter]);

  const fetchCategories = async () => {
    try {
      const res = await adminApi.getCategories();
      const mapped = res.data.map((c) => ({
        id: c.id,
        name: c.name,
        type: CLASSIFY_MAP[c.classify] || 'expense',
        classify: c.classify,
        isDefault: c.is_default,
        keyword: c.keyword || '',
        created_by: c.created_by_name || c.created_by || (c.is_default ? 'Hệ thống' : 'Người dùng'),
        created_at: c.created_at,
      }));
      setCategories(mapped);
    } catch (err) {
      console.error('Lỗi tải danh mục:', err);
    }
  };

  useEffect(() => {
    fetchCategories().finally(() => setLoading(false));
  }, []);

  const toggleModal = (modalName, isOpen) => {
    setModals(prev => ({ ...prev, [modalName]: isOpen }));
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (processing.isProcessing) return; // Chặn bấm nhiều lần
    
    const actionText = editingCategory ? 'Đang cập nhật danh mục...' : 'Đang tạo danh mục mới...';
    setProcessing({ isProcessing: true, text: actionText });

    try {
      const payload = {
        name: form.name.trim(),
        classify: TYPE_TO_CLASSIFY[form.type] || 'Chi',
        is_default: form.isDefault === 'yes',
        keyword: form.keyword ? form.keyword.trim() : null,
      };
      if (editingCategory) {
        await adminApi.updateCategory(editingCategory.id, payload);
        toggleModal('edit', false);
        setEditingCategory(null);
      } else {
        await adminApi.createCategory(payload);
        toggleModal('add', false);
      }
      setForm({ name: '', isDefault: 'yes', type: 'expense', keyword: '' });
      await fetchCategories();
    } catch (err) {
      console.error('Lỗi lưu danh mục:', err);
      alert(err.response?.data?.message || err.message || 'Lỗi lưu danh mục');
    } finally {
      setProcessing({ isProcessing: false, text: '' });
    }
  };

  const confirmDelete = async () => {
    if (!categoryToDelete || processing.isProcessing) return; // Chặn bấm xóa nhiều lần
    setProcessing({ isProcessing: true, text: 'Đang xóa danh mục...' });
    try {
      await adminApi.deleteCategory(categoryToDelete);
      setCategoryToDelete(null);
      toggleModal('deleteAlert', false);
      await fetchCategories();
    } catch (err) {
      console.error('Lỗi xóa danh mục:', err);
      alert(err.response?.data?.message || err.message || 'Lỗi xóa danh mục');
    } finally {
      setProcessing({ isProcessing: false, text: '' });
    }
  };

  const handleDeleteClick = (id) => {
    setCategoryToDelete(id);
    toggleModal('deleteAlert', true);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const openEditModal = (cat) => {
    setEditingCategory(cat);
    setForm({
      name: cat.name,
      isDefault: cat.isDefault ? 'yes' : 'no',
      type: cat.type,
      keyword: cat.keyword || '',
    });
    toggleModal('edit', true);
  };

  const startAdd = () => {
    setEditingCategory(null);
    setForm({ name: '', isDefault: 'yes', type: 'expense', keyword: '' });
    toggleModal('add', true);
  };

  const handleSyncConfirm = async () => {
    if (processing.isProcessing) return;
    toggleModal('syncAlert', false);
    setProcessing({ isProcessing: true, text: 'Đang đồng bộ danh mục hệ thống...' });
    try {
      await fetchCategories();
      setSyncToast('Đã đồng bộ và làm mới danh mục hệ thống thành công!');
      setTimeout(() => setSyncToast(null), 3500);
    } catch (err) {
      console.error('Lỗi đồng bộ danh mục:', err);
    } finally {
      setProcessing({ isProcessing: false, text: '' });
    }
  };

  const getTypeBadgeClass = (type) => {
    if (type === 'income') return 'bg-[#dcfce7] text-[#166534]';
    if (type === 'expense') return 'bg-error-container text-on-error-container';
    return 'bg-surface-container-high text-on-surface';
  };

  return (
    <>
    {/* Full-screen Loading Overlay & Operation Blocker */}
    {processing.isProcessing && (
      <div className="fixed inset-0 bg-black/40 backdrop-blur-sm z-[9999] flex flex-col items-center justify-center pointer-events-auto select-none animate-in fade-in duration-200">
        <div className="bg-white/95 backdrop-blur-md px-8 py-6 rounded-2xl shadow-2xl border border-outline-variant flex flex-col items-center gap-4 text-center max-w-xs mx-4">
          <div className="relative flex items-center justify-center">
            <span className="material-symbols-outlined animate-spin text-primary text-5xl">progress_activity</span>
          </div>
          <div className="space-y-1">
            <h4 className="font-title-md font-bold text-on-surface text-base">
              {processing.text || 'Đang xử lý yêu cầu'}
            </h4>
            <p className="font-body-sm text-on-surface-variant text-xs">Vui lòng chờ trong giây lát...</p>
          </div>
        </div>
      </div>
    )}

    <div className="bg-surface-bright relative p-4 md:p-6 min-h-full">
      {syncToast && (
          <div className="mb-6 bg-[#dcfce7] border border-[#86efac] text-[#166534] rounded-lg p-4 flex items-center justify-between gap-4 animate-in fade-in duration-200">
              <div className="flex items-center gap-3">
                  <span className="material-symbols-outlined text-[#166534]">check_circle</span>
                  <p className="font-body-lg font-semibold">{syncToast}</p>
              </div>
              <button className="text-[#166534] hover:opacity-75 cursor-pointer" onClick={() => setSyncToast(null)}>
                  <span className="material-symbols-outlined">close</span>
              </button>
          </div>
      )}

      {modals.deleteAlert && (
          <div className="mb-6 bg-surface-container-low border border-error-container rounded-lg p-4 flex flex-col md:flex-row items-center justify-between gap-4">
              <div className="flex items-center gap-3 text-on-surface">
                  <span className="material-symbols-outlined text-error">warning</span>
                  <p className="font-body-lg">Bạn có chắc muốn xóa danh mục này hay không?</p>
              </div>
              <div className="flex items-center gap-3">
                  <button 
                    disabled={processing.isProcessing}
                    className="px-4 py-1.5 bg-error text-white rounded font-label-md hover:opacity-90 transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2" 
                    onClick={confirmDelete}
                  >
                    {processing.isProcessing && <span className="material-symbols-outlined animate-spin text-sm">progress_activity</span>}
                    Xác nhận
                  </button>
                  <button 
                    disabled={processing.isProcessing}
                    className="px-4 py-1.5 bg-surface-container-high text-on-surface rounded font-label-md hover:bg-surface-container-low transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed" 
                    onClick={() => { setCategoryToDelete(null); toggleModal('deleteAlert', false); }}
                  >
                    Hủy bỏ
                  </button>
              </div>
          </div>
      )}

      <div className="max-w-[1440px] mx-auto w-full">
          {modals.syncAlert && (
              <div className="mb-6 bg-surface-container-low border border-primary-container rounded-lg p-4 flex flex-col md:flex-row items-center justify-between gap-4">
                  <div className="flex items-center gap-3 text-on-surface">
                      <span className="material-symbols-outlined text-primary">info</span>
                      <p className="font-body-lg">Bạn có chắc chắn muốn đồng bộ các danh mục mặc định?</p>
                  </div>
                  <div className="flex items-center gap-3">
                      <button 
                        disabled={processing.isProcessing}
                        className="px-4 py-1.5 bg-primary text-white rounded font-label-md hover:bg-surface-tint transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2" 
                        onClick={handleSyncConfirm}
                      >
                        {processing.isProcessing && <span className="material-symbols-outlined animate-spin text-sm">progress_activity</span>}
                        Xác nhận
                      </button>
                      <button 
                        disabled={processing.isProcessing}
                        className="px-4 py-1.5 bg-error text-white rounded font-label-md hover:opacity-90 transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed" 
                        onClick={() => toggleModal('syncAlert', false)}
                      >
                        Hủy bỏ
                      </button>
                  </div>
              </div>
          )}

          <div className="flex flex-col md:flex-row md:items-center justify-between mb-stack-lg gap-4">
              <div>
                  <h2 className="font-headline-md text-headline-md text-on-surface m-0">Quản lý danh mục mặc định</h2>
              </div>
              <div className="flex flex-wrap items-center gap-3">
                  <div className="relative w-full md:w-64">
                      <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-outline text-[18px]">search</span>
                      <input 
                          className="w-full pl-10 pr-4 py-2 border border-outline-variant rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary-container focus:border-transparent font-body-md text-body-md text-on-surface shadow-sm" 
                          placeholder="Tìm kiếm danh mục..." 
                          type="text"
                          value={search}
                          onChange={(e) => setSearch(e.target.value)}
                      />
                  </div>
                  <button className="px-4 py-2 border border-outline rounded text-on-surface font-label-md text-label-md hover:bg-surface-container-low transition-colors flex items-center gap-2 cursor-pointer" onClick={() => toggleModal('filter', true)}>
                      <span className="material-symbols-outlined text-[18px]">filter_alt</span>Lọc
                  </button>
                  <button className="px-4 py-2 border rounded font-label-md text-label-md transition-colors flex items-center gap-2 bg-primary text-white border-transparent hover:bg-surface-tint shadow-sm cursor-pointer" onClick={startAdd}>
                      Thêm danh mục mới
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
                  <table className="w-full text-left border-collapse">
                      <thead>
                          <tr className="bg-surface-container-low border-b border-outline-variant">
                              <th className="px-6 py-4 font-label-md text-label-md text-on-surface uppercase">Tên danh mục</th>
                              <th className="px-6 py-4 font-label-md text-label-md text-on-surface uppercase">Loại</th>
                              <th className="px-6 py-4 font-label-md text-label-md text-on-surface uppercase">Phân loại</th>
                              <th className="px-6 py-4 font-label-md text-label-md text-on-surface uppercase">Người tạo</th>
                              <th className="px-6 py-4 font-label-md text-label-md text-on-surface uppercase">Từ khóa (Keyword)</th>
                              <th className="px-6 py-4 font-label-md text-label-md text-on-surface uppercase text-right">Hành động</th>
                          </tr>
                      </thead>
                      <tbody className="font-body-md text-body-md text-on-surface">
                          {pageData.length > 0 ? (
                            pageData.map((item, index) => {
                                const isLastRow = index === pageData.length - 1;
                                const rowClass = isLastRow ? 'hover:bg-surface-container-low transition-all duration-200' : 'border-b border-surface-container-high hover:bg-surface-container-low transition-all duration-200';
                                return (
                                    <tr key={item.id} className={rowClass}>
                                        <td className="px-6 py-4">
                                            <div className="flex items-center gap-3">
                                                <div className="w-8 h-8 rounded-full bg-surface-container flex items-center justify-center text-primary">
                                                    <span className="material-symbols-outlined text-[18px]">category</span>
                                                </div>
                                                <span className="font-semibold">{item.name}</span>
                                            </div>
                                        </td>
                                        <td className="px-6 py-4">
                                            <span className={`inline-flex items-center px-2 py-1 rounded-full font-label-md text-[10px] ${getTypeBadgeClass(item.type)}`}>
                                              {TRANSACTION_TYPE_LABELS[item.type] || item.type}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-on-surface-variant">
                                          <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs ${item.isDefault ? 'bg-primary/10 text-primary font-medium' : 'bg-surface-container text-on-surface-variant'}`}>
                                            {item.isDefault ? 'Hệ thống' : 'Tùy chỉnh'}
                                          </span>
                                        </td>
                                        <td className="px-6 py-4 text-on-surface-variant text-sm">
                                          {item.created_by}
                                        </td>
                                        <td className="px-6 py-4 w-72 max-w-[280px] md:max-w-[340px]">
                                          {item.keyword ? (
                                            <div 
                                              className="w-full bg-[#f8fafc] border border-outline-variant rounded px-2.5 pt-1.5 pb-1 text-xs text-black font-medium font-mono whitespace-nowrap overflow-x-scroll keyword-scrollbar select-all cursor-text shadow-xs"
                                              title={item.keyword}
                                            >
                                              {item.keyword}
                                            </div>
                                          ) : (
                                            <span className="text-outline italic text-xs">Chưa có</span>
                                          )}
                                        </td>
                                        <td className="px-6 py-4 text-right">
                                            <button className="p-1 text-secondary hover:text-primary transition-colors border border-transparent hover:border-on-background rounded cursor-pointer" onClick={() => openEditModal(item)} title="Sửa">
                                                <span className="material-symbols-outlined text-[20px]">edit</span>
                                            </button>
                                            <button className="p-1 text-secondary hover:text-error transition-colors ml-2 border border-transparent hover:border-on-background rounded cursor-pointer" onClick={() => handleDeleteClick(item.id)} title="Xóa">
                                                <span className="material-symbols-outlined text-[20px]">delete</span>
                                            </button>
                                        </td>
                                    </tr>
                                );
                            })
                          ) : (
                            <tr>
                              <td colSpan="6" className="px-6 py-8 text-center text-on-surface-variant">
                                Không tìm thấy danh mục nào.
                              </td>
                            </tr>
                          )}
                      </tbody>
                  </table>
              </div>
              
              <Pagination
                currentPage={currentPage}
                pageSize={pageSize}
                total={filtered.length}
                pageSizeOptions={[5, 10, 20, 50]}
                onPageChange={(page) => setCurrentPage(page)}
                onPageSizeChange={(newSize) => {
                  setPageSize(newSize);
                  setCurrentPage(1);
                }}
                itemLabel="danh mục"
              />
              <div className="px-6 py-4 flex justify-end border-t border-outline-variant bg-surface-container-lowest">
                  <button className="px-4 py-2 bg-primary text-white rounded font-label-md text-label-md hover:bg-surface-tint transition-colors flex items-center gap-2 shadow-sm cursor-pointer" onClick={() => toggleModal('syncAlert', true)}>
                      <span className="material-symbols-outlined text-[18px]">sync</span>Đồng bộ danh mục
                  </button>
              </div>
          </div>
      </div>

      {/* Add / Edit Modal */}
      {(modals.add || modals.edit) && (
          <div className="fixed inset-0 bg-on-background/50 flex items-center justify-center z-50 p-4">
              <div className="bg-white rounded-lg w-full max-w-lg shadow-xl overflow-hidden animate-in fade-in zoom-in duration-200">
                  <div className="px-6 py-4 border-b border-outline-variant flex items-center justify-between">
                      <h3 className="font-headline-sm text-on-surface m-0">
                        {modals.edit ? 'Chỉnh sửa danh mục' : 'Thêm danh mục mới'}
                      </h3>
                      <button 
                        disabled={processing.isProcessing}
                        className="text-on-surface-variant hover:text-on-surface cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed" 
                        onClick={() => toggleModal(modals.edit ? 'edit' : 'add', false)}
                      >
                          <span className="material-symbols-outlined">close</span>
                      </button>
                  </div>
                  <form onSubmit={handleSave}>
                    <div className="p-6 space-y-4">
                        <div>
                            <label className="block font-label-md text-on-surface mb-1">Tên danh mục <span className="text-error">*</span></label>
                            <input 
                              required 
                              disabled={processing.isProcessing}
                              value={form.name} 
                              onChange={e => setForm({...form, name: e.target.value})} 
                              className="w-full px-3 py-2 border border-outline-variant rounded focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary font-body-md h-[40px] disabled:bg-surface-container-low disabled:cursor-not-allowed" 
                              placeholder="Nhập tên danh mục" 
                              type="text"
                            />
                        </div>
                        <div>
                            <label className="block font-label-md text-on-surface mb-1">
                              Từ khóa nhận diện (Keyword)
                              <span className="text-xs text-on-surface-variant font-normal ml-1">(Tùy chọn)</span>
                            </label>
                            <textarea 
                              disabled={processing.isProcessing}
                              value={form.keyword} 
                              onChange={e => setForm({...form, keyword: e.target.value})} 
                              className="w-full px-3 py-2 border border-outline-variant rounded focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary font-body-md min-h-[72px] resize-none disabled:bg-surface-container-low disabled:cursor-not-allowed text-sm" 
                              placeholder="Ví dụ: cafe, highlands, trà sữa, ăn sáng, phở" 
                              rows={2}
                            />
                            <p className="text-[11px] text-on-surface-variant mt-0.5">
                              Nhập các từ khóa phân cách bởi dấu phẩy (,). Giúp bộ máy AI tự động nhận diện danh mục khi phân loại giao dịch.
                            </p>
                        </div>
                        <div className="grid grid-cols-2 gap-4 items-start">
                            <div>
                                <label className="block font-label-md text-on-surface mb-1">Mặc định</label>
                                <select 
                                  disabled={processing.isProcessing}
                                  value={form.isDefault} 
                                  onChange={e => setForm({...form, isDefault: e.target.value})} 
                                  className="w-full px-3 py-2 border border-outline-variant rounded focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary font-body-md bg-white h-[40px] cursor-pointer disabled:bg-surface-container-low disabled:cursor-not-allowed"
                                >
                                    <option value="yes">Yes</option>
                                    <option value="no">No</option>
                                </select>
                            </div>
                            <div>
                                <label className="block font-label-md text-on-surface mb-1">Phân loại</label>
                                <select 
                                  disabled={processing.isProcessing}
                                  value={form.type} 
                                  onChange={e => setForm({...form, type: e.target.value})} 
                                  className="w-full px-3 py-2 border border-outline-variant rounded focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary font-body-md bg-white h-[40px] cursor-pointer disabled:bg-surface-container-low disabled:cursor-not-allowed"
                                >
                                    {Object.keys(TRANSACTION_TYPE_LABELS).map(key => (
                                      <option key={key} value={key}>{TRANSACTION_TYPE_LABELS[key]}</option>
                                    ))}
                                </select>
                            </div>
                        </div>
                    </div>
                    <div className="px-6 py-4 bg-surface-bright border-t border-outline-variant flex justify-end gap-3">
                        <button 
                          type="button" 
                          disabled={processing.isProcessing}
                          className="px-4 py-2 border border-outline rounded text-on-surface font-label-md hover:bg-surface-container-low transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed" 
                          onClick={() => toggleModal(modals.edit ? 'edit' : 'add', false)}
                        >
                          Hủy
                        </button>
                        <button 
                          type="submit" 
                          disabled={processing.isProcessing}
                          className="px-4 py-2 bg-primary text-white rounded font-label-md hover:bg-surface-tint transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                        >
                          {processing.isProcessing && <span className="material-symbols-outlined animate-spin text-sm">progress_activity</span>}
                          Lưu
                        </button>
                    </div>
                  </form>
              </div>
          </div>
      )}

      {/* Filter Modal */}
      {modals.filter && (
          <div className="fixed inset-0 bg-on-background/50 flex items-center justify-center z-50 p-4">
              <div className="bg-white rounded-lg w-full max-w-sm shadow-xl overflow-hidden animate-in fade-in zoom-in duration-200">
                  <div className="px-6 py-4 border-b border-outline-variant flex items-center justify-between">
                      <h3 className="font-headline-sm text-on-surface m-0">Lọc danh mục</h3>
                      <button className="text-on-surface-variant hover:text-on-surface cursor-pointer" onClick={() => toggleModal('filter', false)}>
                          <span className="material-symbols-outlined">close</span>
                      </button>
                  </div>
                  <div className="p-6 space-y-4">
                      <div className="grid grid-cols-2 gap-4 items-start">
                          <div>
                              <label className="block font-label-md text-on-surface mb-1">Mặc định</label>
                              <select value={filter.isDefault} onChange={e => setFilter({...filter, isDefault: e.target.value})} className="w-full px-3 py-2 border border-outline-variant rounded focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary font-body-md bg-white h-[40px] cursor-pointer">
                                  <option value="all">Tất cả</option>
                                  <option value="yes">Yes</option>
                                  <option value="no">No</option>
                              </select>
                          </div>
                          <div>
                              <label className="block font-label-md text-on-surface mb-1">Loại danh mục</label>
                              <select value={filter.type} onChange={e => setFilter({...filter, type: e.target.value})} className="w-full px-3 py-2 border border-outline-variant rounded focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary font-body-md bg-white h-[40px] cursor-pointer">
                                  <option value="all">Tất cả</option>
                                  {Object.keys(TRANSACTION_TYPE_LABELS).map(key => (
                                      <option key={key} value={key}>{TRANSACTION_TYPE_LABELS[key]}</option>
                                  ))}
                              </select>
                          </div>
                      </div>
                  </div>
                  <div className="px-6 py-4 bg-surface-bright border-t border-outline-variant flex justify-end gap-3">
                      <button className="px-4 py-2 border border-outline rounded text-on-surface font-label-md hover:bg-surface-container-low transition-colors cursor-pointer" onClick={() => { setFilter({ isDefault: 'all', type: 'all' }); toggleModal('filter', false); }}>Đặt lại</button>
                      <button className="px-4 py-2 bg-primary text-white rounded font-label-md hover:bg-surface-tint transition-colors cursor-pointer" onClick={() => toggleModal('filter', false)}>Áp dụng</button>
                  </div>
              </div>
          </div>
      )}
    </div>
    </>
  );
};

export default CategoryPage;
