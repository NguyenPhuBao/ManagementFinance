import React from 'react';

const SIZES = {
  sm: 'text-base',
  md: 'text-xl',
  lg: 'text-2xl',
};

const Icon = ({ name, size = 'md', className = '' }) => (
  <span aria-hidden="true" className={`material-symbols-outlined ${SIZES[size]} ${className}`}>
    {name}
  </span>
);

export default Icon;
