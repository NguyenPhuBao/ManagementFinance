import React from 'react';
import { Link } from 'react-router-dom';

const ForgotPasswordPage = () => {
  return (
    <div className="flex items-center justify-center min-h-screen bg-slate-50 p-4">
      <main className="w-full max-w-md bg-white rounded-xl border border-gray-200 shadow-sm p-8 md:p-10">
        <div className="flex flex-col items-center mb-8">
          <div className="w-12 h-12 bg-primary rounded-md flex items-center justify-center mb-4">
            <svg className="h-8 w-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path d="M8 14v3m4-3v3m4-3v3M3 21h18M3 10h18M3 7l9-4 9 4M4 10h16v11H4V10z" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2"></path>
            </svg>
          </div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">WealthCommand</h1>
          <p className="text-gray-500 text-sm mt-1">Hệ thống Quản trị Viên</p>
        </div>
        
        <div className="text-center space-y-6">
          <h2 className="text-xl font-semibold text-gray-800">Quên mật khẩu?</h2>
          
          <div className="bg-amber-50 border-l-4 border-amber-400 p-4 text-left">
            <div className="flex">
              <div className="flex-shrink-0">
                <svg className="h-5 w-5 text-amber-400" fill="currentColor" viewBox="0 0 20 20">
                  <path clipRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" fillRule="evenodd"></path>
                </svg>
              </div>
              <div className="ml-3">
                <p className="text-sm text-amber-700 font-medium">
                  Vì lý do bảo mật, tài khoản Admin không thể tự đặt lại mật khẩu.
                </p>
              </div>
            </div>
          </div>
          
          <div className="space-y-4">
            <p className="text-gray-600 text-sm">
              Vui lòng liên hệ Hotline hỗ trợ kỹ thuật để được cấp lại mật khẩu mới:
            </p>
            <div className="flex items-center justify-center space-x-3 py-4 bg-gray-50 rounded-lg border border-gray-100">
              <svg className="h-6 w-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                <path d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2"></path>
              </svg>
              <a className="text-2xl font-bold text-gray-900 hover:text-primary transition-colors" href="tel:+84355281276">
                +84 355 281 276
              </a>
            </div>
          </div>
        </div>
        
        <div className="mt-10 pt-6 border-t border-gray-100 text-center">
          <Link className="inline-flex items-center text-sm font-semibold text-primary hover:underline" to="/login">
            <svg className="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path d="M10 19l-7-7m0 0l7-7m-7 7h18" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2"></path>
            </svg>
            Quay lại Đăng nhập
          </Link>
        </div>
      </main>
    </div>
  );
};

export default ForgotPasswordPage;
