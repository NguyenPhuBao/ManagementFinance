const loginSchema = {
  username: { required: true, type: 'string', minLength: 1, maxLength: 50 },
  password: { required: true, type: 'string', minLength: 6, maxLength: 100 },
};

const refreshSchema = {
  refreshToken: { required: true, type: 'string', minLength: 10, maxLength: 2000 },
};

const registerSchema = {
  username: { required: true, type: 'string', minLength: 3, maxLength: 50 },
  password: { required: true, type: 'string', minLength: 6, maxLength: 100 },
  fullname: { required: true, type: 'string', minLength: 2, maxLength: 100 },
  email: { required: true, type: 'string', minLength: 5, maxLength: 100 },
  phone: { required: false, type: 'string', minLength: 8, maxLength: 15 },
};

const changePasswordSchema = {
  currentPassword: { required: true, type: 'string', minLength: 6, maxLength: 100 },
  newPassword: { required: true, type: 'string', minLength: 6, maxLength: 100 },
};

const forgotPasswordSchema = {
  email: { required: true, type: 'string', minLength: 5, maxLength: 100 },
};

const verifyOtpSchema = {
  email: { required: true, type: 'string', minLength: 5, maxLength: 100 },
  otp: { required: true, type: 'string', minLength: 6, maxLength: 6 },
};

const resetPasswordSchema = {
  resetToken: { required: true, type: 'string', minLength: 10 },
  newPassword: { required: true, type: 'string', minLength: 6, maxLength: 100 },
};

const deleteAccountSchema = {
  password: { required: true, type: 'string', minLength: 6, maxLength: 100 },
};

const updateProfileSchema = {
  fullname: { required: false, type: 'string', minLength: 2, maxLength: 100 },
  phone: { required: false, type: 'string', minLength: 8, maxLength: 15 },
  address: { required: false, type: 'string', maxLength: 255 },
  country_code: { required: false, type: 'string', maxLength: 4 },
};

const requestEmailChangeSchema = {
  newEmail: { required: true, type: 'string', minLength: 5, maxLength: 100 },
};

const confirmEmailChangeSchema = {
  newEmail: { required: true, type: 'string', minLength: 5, maxLength: 100 },
  otp: { required: true, type: 'string', minLength: 6, maxLength: 6 },
};

module.exports = { 
  loginSchema, refreshSchema, registerSchema,
  changePasswordSchema, forgotPasswordSchema, verifyOtpSchema, resetPasswordSchema,
  deleteAccountSchema, updateProfileSchema, requestEmailChangeSchema, confirmEmailChangeSchema
};
