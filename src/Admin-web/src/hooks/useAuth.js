import { useAuthContext } from '../store/auth.context';

const useAuth = () => {
  return useAuthContext();
};

export default useAuth;
