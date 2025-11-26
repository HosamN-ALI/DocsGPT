import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '../../store';

interface User {
  user_id: string;
  email: string;
  name: string;
  subscription_plan: string;
  subscription_status?: string;
  created_at?: string;
}

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
}

const initialState: AuthState = {
  user: null,
  isAuthenticated: false,
  isLoading: true,
};

export const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    setUser: (state, action: PayloadAction<User | null>) => {
      state.user = action.payload;
      state.isAuthenticated = !!action.payload;
      state.isLoading = false;
    },
    setLoading: (state, action: PayloadAction<boolean>) => {
      state.isLoading = action.payload;
    },
    logout: (state) => {
      state.user = null;
      state.isAuthenticated = false;
      state.isLoading = false;
      localStorage.removeItem('authToken');
      localStorage.removeItem('refreshToken');
    },
  },
});

export const { setUser, setLoading, logout } = authSlice.actions;

export const selectUser = (state: RootState) => (state.auth as AuthState).user;
export const selectIsAuthenticated = (state: RootState) =>
  (state.auth as AuthState).isAuthenticated;
export const selectAuthLoading = (state: RootState) => (state.auth as AuthState).isLoading;

export default authSlice.reducer;
