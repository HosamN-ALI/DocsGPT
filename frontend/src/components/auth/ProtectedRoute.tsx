import { useEffect } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { Navigate, useLocation } from 'react-router-dom';
import { selectIsAuthenticated, selectAuthLoading, setUser, setLoading } from '../../features/auth/authSlice';
import { selectToken } from '../../preferences/preferenceSlice';
import authService from '../../api/services/authService';

interface ProtectedRouteProps {
  children: React.ReactNode;
}

export default function ProtectedRoute({ children }: ProtectedRouteProps) {
  const isAuthenticated = useSelector(selectIsAuthenticated);
  const isLoading = useSelector(selectAuthLoading);
  const token = useSelector(selectToken);
  const location = useLocation();
  const dispatch = useDispatch();

  useEffect(() => {
    const verifyAuth = async () => {
      const authToken = localStorage.getItem('authToken');
      
      if (!authToken) {
        dispatch(setLoading(false));
        return;
      }

      try {
        const response = await authService.getCurrentUser(authToken);
        const data = await response.json();

        if (data.success && data.user) {
          dispatch(setUser(data.user));
        } else {
          dispatch(setUser(null));
          localStorage.removeItem('authToken');
          localStorage.removeItem('refreshToken');
        }
      } catch (error) {
        console.error('Auth verification failed:', error);
        dispatch(setUser(null));
        localStorage.removeItem('authToken');
        localStorage.removeItem('refreshToken');
      }
    };

    if (!isAuthenticated && isLoading) {
      verifyAuth();
    }
  }, [isAuthenticated, isLoading, dispatch]);

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return <>{children}</>;
}
