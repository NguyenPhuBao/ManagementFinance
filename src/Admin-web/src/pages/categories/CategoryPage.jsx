import React, { useState, useEffect } from 'react';
import { TRANSACTION_TYPE_LABELS } from '../../utils/constants';

const MOCK_CATEGORIES = [
  { id: 1, icon: 'restaurant', name: 'Ăn uống', keywords: 'ăn uống, food, restaurant, cafe, grabfood, shopeefood', isDefault: true, type: 'expense' },
  { id: 2, icon: 'commute', name: 'Di chuyển', keywords: 'di chuyển, taxi, grab, be, xăng, vé xe, gửi xe', isDefault: false, type: 'expense' },
  { id: 3, icon: 'payments', name: 'Lương', keywords: 'lương, salary, thưởng, bonus, thu nhập, được cho', isDefault: true, type: 'income' },
  { id: 4, icon: 'home', name: 'Nhà ở', keywords: 'tiền nhà, rent, điện, nước, internet, wifi, cáp', isDefault: true, type: 'expense' },
  { id: 5, icon: 'shopping_cart', name: 'Mua sắm', keywords: 'shopee, lazada, tiki, siêu thị, bách hóa xanh', isDefault: true, type: 'expense' },
  { id: 6, icon: 'credit_score', name: 'Trả nợ', keywords: 'trả nợ, thanh toán thẻ, lãi vay', isDefault: false, type: 'debt' },
  { id: 7, icon: 'health_and_safety', name: 'Sức khỏe', keywords: 'thuốc, bệnh viện, khám bệnh, bảo hiểm', isDefault: true, type: 'expense' },
  { id: 8, icon: 'school', name: 'Giáo dục', keywords: 'học phí, sách vở, khóa học', isDefault: true, type: 'expense' },
  { id: 9, icon: 'savings', name: 'Tiết kiệm', keywords: 'gửi tiết kiệm, heo đất, đầu tư', isDefault: false, type: 'income' },
];

const CategoryPage = () => {
  const [loading, setLoading] = useState(true);
  const [categories, setCategories] = useState(MOCK_CATEGORIES);
  const [search, setSearch] = useState('');
  
  const [modals, setModals] = useState({
      add: false,
      edit: false,
      filter: false,
      deleteAlert: false,
      syncAlert: false,
  });
  const [editingCategory, setEditingCategory] = useState(null);
  const [categoryToDelete, setCategoryToDelete] = useState(null);

  const [form, setForm] = useState({ name: '', isDefault: 'yes', type: 'expense', keywords: '' });
  const [filter, setFilter] = useState({ isDefault: 'all', type: 'all' });

  // Pagination states
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  const filtered = categories.filter(c =>
    (c.name.toLowerCase().includes(search.toLowerCase()) ||
    c.keywords.toLowerCase().includes(search.toLowerCase())) &&
    (filter.isDefault === 'all' || (filter.isDefault === 'yes' ? c.isDefault : !c.isDefault)) &&
    (filter.type === 'all' || c.type === filter.type)
  );

  const totalPages = Math.ceil(filtered.length / itemsPerPage);
  const start = (currentPage - 1) * itemsPerPage;
  const end = Math.min(start + itemsPerPage, filtered.length);
  const pageData = filtered.slice(start, end);

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);

  const toggleModal = (modalName, isOpen) => {
    setModals(prev => ({ ...prev, [modalName]: isOpen }));
  };

  const handleSave = (e) => {
    e.preventDefault();
    if (editingCategory) {
      setCategories(categories.map(c =>
        c.id === editingCategory.id ? { ...c, ...form, isDefault: form.isDefault === 'yes' } : c
      ));
      toggleModal('edit', false);
    } else {
      const newCategory = {
        id: categories.length + 1,
        icon: 'category',
        ...form,
        isDefault: form.isDefault === 'yes',
      };
      setCategories([...categories, newCategory]);
      toggleModal('add', false);
    }
  };

  const confirmDelete = () => {
    if (categoryToDelete) {
      setCategories(categories.filter(c => c.id !== categoryToDelete));
      setCategoryToDelete(null);
    }
    toggleModal('deleteAlert', false);
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
      keywords: cat.keywords,
      isDefault: cat.isDefault ? 'yes' : 'no',
      type: cat.type
    });
    toggleModal('edit', true);
  };

  const startAdd = () => {
    setEditingCategory(null);
    setForm({ name: '', isDefault: 'yes', type: 'expense', keywords: '' });
    toggleModal('add', true);
  };

  const handleSyncConfirm = () => {
    toggleModal('syncAlert', false);
    // sync logic placeholder
  };

  const getTypeBadgeClass = (type) => {
    if (type === 'income') return 'bg-[#dcfce7] text-[#166534]';
    if (type === 'expense') return 'bg-error-container text-on-error-container';
    return 'bg-surface-container-high text-on-surface';
  };

  return (
    <div className="bg-surface-bright relative p-4 md:p-6 min-h-full">
      {modals.deleteAlert && (
          <div className="mb-6 bg-surface-container-low border border-error-container rounded-lg p-4 flex flex-col md:flex-row items-center justify-between gap-4">
              <div className="flex items-center gap-3 text-on-surface">
                  <span className="material-symbols-outlined text-error">warning</span>
                  <p className="font-body-lg">Bạn có chắc muốn xóa danh mục này hay không?</p>
              </div>
              <div className="flex items-center gap-3">
                  <button className="px-4 py-1.5 bg-error text-white rounded font-label-md hover:opacity-90 transition-colors cursor-pointer" onClick={confirmDelete}>Xác nhận</button>
                  <button className="px-4 py-1.5 bg-surface-container-high text-on-surface rounded font-label-md hover:bg-surface-container-low transition-colors cursor-pointer" onClick={() => { setCategoryToDelete(null); toggleModal('deleteAlert', false); }}>Hủy bỏ</button>
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
                      <button className="px-4 py-1.5 bg-primary text-white rounded font-label-md hover:bg-surface-tint transition-colors cursor-pointer" onClick={handleSyncConfirm}>Xác nhận</button>
                      <button className="px-4 py-1.5 bg-error text-white rounded font-label-md hover:opacity-90 transition-colors cursor-pointer" onClick={() => toggleModal('syncAlert', false)}>Hủy bỏ</button>
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
                              <th className="px-6 py-4 font-label-md text-label-md text-on-surface uppercase">Keyword nhận diện</th>
                              <th className="px-6 py-4 font-label-md text-label-md text-on-surface uppercase">MẶC ĐỊNH</th>
                              <th className="px-6 py-4 font-label-md text-label-md text-on-surface uppercase">Loại</th>
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
                                                    <span className="material-symbols-outlined text-[18px]">{item.icon}</span>
                                                </div>
                                                <span className="font-semibold">{item.name}</span>
                                            </div>
                                        </td>
                                        <td className="px-6 py-4 text-on-surface-variant max-w-[300px] truncate" title={item.keywords}>{item.keywords}</td>
                                        <td className="px-6 py-4 text-on-surface-variant">{item.isDefault ? 'Yes' : 'No'}</td>
                                        <td className="px-6 py-4">
                                            <span className={`inline-flex items-center px-2 py-1 rounded-full font-label-md text-[10px] ${getTypeBadgeClass(item.type)}`}>
                                              {TRANSACTION_TYPE_LABELS[item.type] || item.type}
                                            </span>
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
                              <td colSpan="5" className="px-6 py-8 text-center text-on-surface-variant">
                                Không tìm thấy danh mục nào.
                              </td>
                            </tr>
                          )}
                      </tbody>
                  </table>
              </div>
              
              <div className="px-6 py-4 border-t border-outline-variant bg-surface-bright flex flex-col md:flex-row items-center justify-between gap-4">
                  <span className="font-tabular-nums text-tabular-nums text-on-surface-variant">Hiển thị {filtered.length > 0 ? start + 1 : 0} - {end} của {filtered.length} danh mục</span>
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
                      <button className="text-on-surface-variant hover:text-on-surface cursor-pointer" onClick={() => toggleModal(modals.edit ? 'edit' : 'add', false)}>
                          <span className="material-symbols-outlined">close</span>
                      </button>
                  </div>
                  <form onSubmit={handleSave}>
                    <div className="p-6 space-y-4">
                        <div>
                            <label className="block font-label-md text-on-surface mb-1">Tên danh mục <span className="text-error">*</span></label>
                            <input required value={form.name} onChange={e => setForm({...form, name: e.target.value})} className="w-full px-3 py-2 border border-outline-variant rounded focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary font-body-md h-[40px]" placeholder="Nhập tên danh mục" type="text"/>
                        </div>
                        <div className="grid grid-cols-2 gap-4 items-start">
                            <div>
                                <label className="block font-label-md text-on-surface mb-1">Mặc định</label>
                                <select value={form.isDefault} onChange={e => setForm({...form, isDefault: e.target.value})} className="w-full px-3 py-2 border border-outline-variant rounded focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary font-body-md bg-white h-[40px] cursor-pointer">
                                    <option value="yes">Yes</option>
                                    <option value="no">No</option>
                                </select>
                            </div>
                            <div>
                                <label className="block font-label-md text-on-surface mb-1">Phân loại</label>
                                <select value={form.type} onChange={e => setForm({...form, type: e.target.value})} className="w-full px-3 py-2 border border-outline-variant rounded focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary font-body-md bg-white h-[40px] cursor-pointer">
                                    {Object.keys(TRANSACTION_TYPE_LABELS).map(key => (
                                      <option key={key} value={key}>{TRANSACTION_TYPE_LABELS[key]}</option>
                                    ))}
                                </select>
                            </div>
                        </div>
                        <div>
                            <label className="block font-label-md text-on-surface mb-1">Keyword nhận diện danh mục</label>
                            <textarea value={form.keywords} onChange={e => setForm({...form, keywords: e.target.value})} className="w-full px-3 py-2 border border-outline-variant rounded focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary font-body-md resize-none" placeholder="ăn uống, food, nhà hàng..." rows="3"></textarea>
                        </div>
                    </div>
                    <div className="px-6 py-4 bg-surface-bright border-t border-outline-variant flex justify-end gap-3">
                        <button type="button" className="px-4 py-2 border border-outline rounded text-on-surface font-label-md hover:bg-surface-container-low transition-colors cursor-pointer" onClick={() => toggleModal(modals.edit ? 'edit' : 'add', false)}>Hủy</button>
                        <button type="submit" className="px-4 py-2 bg-primary text-white rounded font-label-md hover:bg-surface-tint transition-colors cursor-pointer">Lưu</button>
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
  );
};

export default CategoryPage;
