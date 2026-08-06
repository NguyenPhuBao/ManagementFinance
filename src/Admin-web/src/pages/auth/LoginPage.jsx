import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuthContext } from '../../store/auth.context';

const LoginPage = () => {
  const navigate = useNavigate();
  const { login } = useAuthContext();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showPassword, setShowPassword] = useState(false);

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      await login({ username: email, password: password });
      navigate('/dashboard');
    } catch (err) {
      const msg = err.response?.data?.message || err.message || 'Đăng nhập thất bại';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col lg:flex-row min-h-screen bg-surface-bright">
        
        {/* Left Side - Illustration & Branding (Hidden on mobile) */}
        <div className="hidden lg:flex lg:w-1/2 bg-primary relative items-center justify-center overflow-hidden">
            <div className="absolute inset-0 bg-[url('https://images.unsplash.com/photo-1551288049-bebda4e38f71?q=80&w=2070&auto=format&fit=crop')] bg-cover bg-center mix-blend-overlay opacity-20"></div>
            <div className="absolute inset-0 bg-gradient-to-t from-primary via-primary/80 to-transparent"></div>
            
            <div className="relative z-10 p-12 text-white max-w-lg">
                <div className="flex items-center gap-3 mb-12">
                    <div className="w-12 h-12 bg-white rounded-xl flex items-center justify-center shadow-lg">
                        <span className="material-symbols-outlined text-primary text-[28px]">account_balance</span>
                    </div>
                    <span className="font-display-sm text-display-sm font-bold tracking-tight">FinanceAdmin</span>
                </div>
                
                <h1 className="font-display-lg text-display-lg font-bold mb-6 leading-tight">Quản lý tài chính thông minh & hiệu quả.</h1>
                <p className="font-body-lg text-body-lg text-primary-container/90 mb-12">Nền tảng quản trị tập trung giúp bạn theo dõi, phân tích và kiểm soát mọi hoạt động tài chính một cách dễ dàng và bảo mật.</p>
                
                <div className="flex gap-4">
                    <div className="bg-white/10 backdrop-blur-md rounded-lg p-4 border border-white/20">
                        <span className="material-symbols-outlined text-primary-container mb-2">monitoring</span>
                        <h3 className="font-title-md font-bold mb-1">Báo cáo realtime</h3>
                        <p className="font-body-sm text-primary-container/80">Dữ liệu được cập nhật liên tục 24/7</p>
                    </div>
                    <div className="bg-white/10 backdrop-blur-md rounded-lg p-4 border border-white/20">
                        <span className="material-symbols-outlined text-primary-container mb-2">shield_locked</span>
                        <h3 className="font-title-md font-bold mb-1">Bảo mật đa lớp</h3>
                        <p className="font-body-sm text-primary-container/80">An toàn tuyệt đối cho mọi giao dịch</p>
                    </div>
                </div>
            </div>
            
            {/* Decorative circles */}
            <div className="absolute top-1/4 -right-20 w-64 h-64 rounded-full bg-white/10 blur-3xl"></div>
            <div className="absolute bottom-1/4 -left-20 w-80 h-80 rounded-full bg-primary-container/20 blur-3xl"></div>
        </div>

        {/* Right Side - Login Form */}
        <div className="w-full lg:w-1/2 flex items-center justify-center p-6 sm:p-12 relative">
            <div className="absolute top-6 left-6 lg:hidden flex items-center gap-2">
                <div className="w-8 h-8 bg-primary rounded-lg flex items-center justify-center shadow-sm">
                    <span className="material-symbols-outlined text-white text-[20px]">account_balance</span>
                </div>
                <span className="font-title-md font-bold text-primary tracking-tight">FinanceAdmin</span>
            </div>

            <div className="w-full max-w-md">
                <div className="mb-10 text-center lg:text-left mt-8 lg:mt-0">
                    <h2 className="font-display-sm text-display-sm lg:text-display-md font-bold text-on-surface mb-3 tracking-tight">Đăng nhập hệ thống</h2>
                    <p className="font-body-lg text-body-lg text-on-surface-variant">Vui lòng nhập thông tin tài khoản của bạn để tiếp tục.</p>
                </div>

                {error && (
                  <div className="mb-6 p-4 rounded-lg bg-error-container text-on-error-container border border-error border-opacity-20 flex items-center gap-3">
                    <span className="material-symbols-outlined text-error">error</span>
                    <p className="font-body-md text-body-md">{error}</p>
                  </div>
                )}

                <form className="space-y-6" onSubmit={handleSubmit}>
                    <div>
                        <label htmlFor="email" className="block font-label-md text-label-md text-on-surface mb-2 font-semibold">Email hoặc Tên đăng nhập</label>
                        <div className="relative group">
                            <span className="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-outline group-focus-within:text-primary transition-colors">mail</span>
                            <input 
                                type="text" 
                                id="email" 
                                name="email"
                                value={email}
                                onChange={e => setEmail(e.target.value)}
                                disabled={loading}
                                className="w-full pl-12 pr-4 py-3.5 bg-surface-container-lowest border border-outline-variant rounded-xl focus:ring-2 focus:ring-primary focus:border-primary outline-none transition-all font-body-md text-on-surface placeholder:text-outline shadow-sm hover:border-outline"
                                placeholder="admin@example.com"
                                required
                            />
                        </div>
                    </div>

                    <div>
                        <div className="flex items-center justify-between mb-2">
                            <label htmlFor="password" className="block font-label-md text-label-md text-on-surface font-semibold">Mật khẩu</label>
                            <Link to="/forgot-password" className="font-label-md text-label-md text-primary hover:text-primary-container transition-colors font-semibold">
                                Quên mật khẩu?
                            </Link>
                        </div>
                        <div className="relative group">
                            <span className="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-outline group-focus-within:text-primary transition-colors">lock</span>
                            <input 
                                type={showPassword ? 'text' : 'password'}
                                id="password" 
                                name="password"
                                value={password}
                                onChange={e => setPassword(e.target.value)}
                                disabled={loading}
                                className="w-full pl-12 pr-12 py-3.5 bg-surface-container-lowest border border-outline-variant rounded-xl focus:ring-2 focus:ring-primary focus:border-primary outline-none transition-all font-body-md text-on-surface placeholder:text-outline shadow-sm hover:border-outline"
                                placeholder="••••••••"
                                required
                            />
                            <button 
                                type="button" 
                                onClick={() => setShowPassword(!showPassword)}
                                className="absolute right-4 top-1/2 -translate-y-1/2 text-outline hover:text-on-surface transition-colors cursor-pointer p-1"
                            >
                                <span className="material-symbols-outlined text-[20px]">
                                    {showPassword ? 'visibility' : 'visibility_off'}
                                </span>
                            </button>
                        </div>
                    </div>

                    <button 
                        type="submit" 
                        disabled={loading}
                        className="w-full py-3.5 bg-primary hover:bg-surface-tint text-white rounded-xl font-label-lg text-label-lg font-bold shadow-md shadow-primary/20 transition-all active:scale-[0.98] cursor-pointer flex items-center justify-center gap-2 mt-8 disabled:opacity-70 disabled:cursor-not-allowed"
                    >
                        {loading ? (
                          <>
                            <span className="material-symbols-outlined animate-spin" style={{ fontSize: 20 }}>progress_activity</span>
                            Đang xử lý...
                          </>
                        ) : (
                          <>
                            Đăng nhập
                            <span className="material-symbols-outlined text-[20px]">arrow_forward</span>
                          </>
                        )}
                    </button>
                </form>

                <div className="mt-12 text-center">
                    <p className="font-body-sm text-body-sm text-on-surface-variant flex items-center justify-center gap-1.5">
                        <span className="material-symbols-outlined text-[16px]">lock</span>
                        Hệ thống được bảo mật bằng mã hóa 256-bit
                    </p>
                </div>
            </div>
        </div>
    </div>
  );
};

export default LoginPage;
