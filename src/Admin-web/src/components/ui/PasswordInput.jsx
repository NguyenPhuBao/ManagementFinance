import React, { useState } from 'react';
import Button from './Button';
import { useLanguageSafe } from '../../store/language.context';

const inputClass =
  'h-10 w-full rounded-lg border border-line bg-card px-3 pr-11 text-sm text-ink placeholder:text-ink-faint focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20 disabled:opacity-60';

const PasswordInput = ({ className = '', ...rest }) => {
  const { t } = useLanguageSafe();
  const [visible, setVisible] = useState(false);
  return (
    <div className="relative">
      <input {...rest} type={visible ? 'text' : 'password'} className={`${inputClass} ${className}`} />
      <Button
        variant="ghost"
        size="sm"
        icon={visible ? 'visibility_off' : 'visibility'}
        aria-label={visible ? t('common.security.hidePassword', 'Ẩn mật khẩu') : t('common.security.showPassword', 'Hiện mật khẩu')}
        onClick={() => setVisible((v) => !v)}
        className="absolute right-0.5 top-0.5"
      />
    </div>
  );
};

export default PasswordInput;
