import React from 'react';
import Icon from './Icon';
import Spinner from './Spinner';

const VARIANTS = {
  primary: 'bg-brand text-brand-on hover:bg-brand-hover',
  secondary: 'bg-card text-ink border border-line hover:bg-muted',
  ghost: 'text-ink-muted hover:bg-muted hover:text-ink',
  danger: 'bg-danger text-card hover:bg-danger-hover',
  'danger-ghost': 'text-danger hover:bg-danger-soft',
};

const SIZES = {
  md: { text: 'h-10 px-4', icon: 'h-10 w-10' },
  sm: { text: 'h-9 px-3', icon: 'h-9 w-9' },
};

const Button = ({
  variant = 'secondary',
  size = 'md',
  icon,
  loading = false,
  disabled = false,
  type = 'button',
  className = '',
  children,
  ...rest
}) => {
  const iconOnly = icon && !children;
  const sizeClass = iconOnly ? SIZES[size].icon : SIZES[size].text;
  return (
    <button
      type={type}
      disabled={disabled || loading}
      className={`inline-flex shrink-0 items-center justify-center gap-2 rounded-lg text-sm font-medium transition-colors cursor-pointer disabled:cursor-not-allowed disabled:opacity-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand ${VARIANTS[variant]} ${sizeClass} ${className}`}
      {...rest}
    >
      {loading ? <Spinner size="sm" /> : icon && <Icon name={icon} size={size === 'sm' ? 'sm' : 'md'} />}
      {children}
    </button>
  );
};

export default Button;
