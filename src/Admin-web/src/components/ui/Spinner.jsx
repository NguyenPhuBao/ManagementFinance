import React from 'react';

const SIZES = {
  sm: 'h-4 w-4 border-2',
  md: 'h-6 w-6 border-2',
  lg: 'h-10 w-10 border-[3px]',
};

const Spinner = ({ size = 'md', label, className = '' }) => (
  <span role="status" aria-label={label} className={`inline-flex ${className}`}>
    <span className={`${SIZES[size]} animate-spin rounded-full border-current border-t-transparent`} />
  </span>
);

export default Spinner;
