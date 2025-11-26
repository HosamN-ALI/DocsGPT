import apiClient from '../client';
import endpoints from '../endpoints';

interface RegisterData {
  email: string;
  password: string;
  name: string;
}

interface LoginData {
  email: string;
  password: string;
}

interface ChangePasswordData {
  old_password: string;
  new_password: string;
}

const authService = {
  register: (data: RegisterData) =>
    apiClient.post(endpoints.AUTH.REGISTER, data, null),

  login: (data: LoginData) =>
    apiClient.post(endpoints.AUTH.LOGIN, data, null),

  getCurrentUser: (token: string | null) =>
    apiClient.get(endpoints.AUTH.ME, token),

  changePassword: (data: ChangePasswordData, token: string | null) =>
    apiClient.post(endpoints.AUTH.CHANGE_PASSWORD, data, token),

  refreshToken: (refreshToken: string) =>
    apiClient.post(endpoints.AUTH.REFRESH, {}, refreshToken),
};

export default authService;
