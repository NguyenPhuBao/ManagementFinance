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

module.exports = { loginSchema, refreshSchema, registerSchema };
