import { useState, useEffect, useCallback, useRef } from 'react';

/**
 * Custom hook quản lý co dãn cột kéo thả như Excel và ghi nhớ kích thước vào LocalStorage
 * @param {string} tableKey - Khóa duy nhất xác định bảng (vd: 'users', 'audit_logs')
 * @param {Object} defaultWidths - Độ rộng mặc định theo từng cột tính bằng px { colName: 200 }
 * @param {number} minWidth - Độ rộng tối thiểu (mặc định 60px)
 * @param {number} maxWidth - Độ rộng tối đa (mặc định 1000px)
 */
export default function useResizableColumns({ tableKey, defaultWidths = {}, minWidth = 60, maxWidth = 1000 }) {
  const storageKey = `admin_tbl_widths_${tableKey}`;

  const [widths, setWidths] = useState(() => {
    try {
      const saved = localStorage.getItem(storageKey);
      if (saved) {
        return { ...defaultWidths, ...JSON.parse(saved) };
      }
    } catch (e) {
      console.warn('Failed to parse table widths from localStorage', e);
    }
    return { ...defaultWidths };
  });

  const [isResizing, setIsResizing] = useState(false);
  const [activeCol, setActiveCol] = useState(null);

  const dragRef = useRef({
    colKey: null,
    startX: 0,
    startWidth: 0,
    currentWidth: 0,
  });

  const startResizing = useCallback((colKey, startX, startWidth) => {
    dragRef.current = {
      colKey,
      startX,
      startWidth,
      currentWidth: startWidth,
    };
    setIsResizing(true);
    setActiveCol(colKey);
  }, []);

  useEffect(() => {
    if (!isResizing) return;

    const handleMouseMove = (e) => {
      const { colKey, startX, startWidth } = dragRef.current;
      if (!colKey) return;

      const diff = e.clientX - startX;
      let newWidth = Math.round(startWidth + diff);

      if (newWidth < minWidth) newWidth = minWidth;
      if (newWidth > maxWidth) newWidth = maxWidth;

      dragRef.current.currentWidth = newWidth;
      setWidths((prev) => ({ ...prev, [colKey]: newWidth }));
    };

    const handleMouseUp = () => {
      const { colKey, currentWidth } = dragRef.current;
      setIsResizing(false);
      setActiveCol(null);

      if (colKey && currentWidth) {
        setWidths((latest) => {
          try {
            localStorage.setItem(storageKey, JSON.stringify(latest));
          } catch (e) {
            console.warn('Failed to save table widths to localStorage', e);
          }
          return latest;
        });
      }
    };

    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseup', handleMouseUp);

    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleMouseUp);
    };
  }, [isResizing, minWidth, maxWidth, storageKey]);

  const resetWidths = useCallback(() => {
    setWidths({ ...defaultWidths });
    try {
      localStorage.removeItem(storageKey);
    } catch (e) {
      console.warn('Failed to remove table widths from localStorage', e);
    }
  }, [defaultWidths, storageKey]);

  const resetColumn = useCallback((colKey) => {
    if (defaultWidths[colKey] !== undefined) {
      setWidths((prev) => {
        const next = { ...prev, [colKey]: defaultWidths[colKey] };
        try {
          localStorage.setItem(storageKey, JSON.stringify(next));
        } catch (e) {
          console.warn('Failed to update table widths in localStorage', e);
        }
        return next;
      });
    }
  }, [defaultWidths, storageKey]);

  return {
    widths,
    isResizing,
    activeCol,
    startResizing,
    resetWidths,
    resetColumn,
  };
}
