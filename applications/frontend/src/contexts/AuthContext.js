// applications/frontend/src/contexts/AuthContext.js

import React, { createContext, useContext, useState, useEffect } from 'react';
import { Amplify, Auth } from 'aws-amplify';

// Configure Amplify
Amplify.configure({
  Auth: {
    region: process.env.REACT_APP_AWS_REGION,
    userPoolId: process.env.REACT_APP_AWS_USER_POOL_ID,
    userPoolWebClientId: process.env.REACT_APP_AWS_USER_POOL_CLIENT_ID,
    identityPoolId: process.env.REACT_APP_AWS_IDENTITY_POOL_ID,
    mandatorySignIn: true,
  },
  API: {
    endpoints: [
      {
        name: 'api',
        endpoint: process.env.REACT_APP_API_URL,
        region: process.env.REACT_APP_AWS_REGION,
      },
    ],
  },
});

const AuthContext = createContext();

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Initialize authentication state
  useEffect(() => {
    const initializeAuth = async () => {
      try {
        const currentUser = await Auth.currentAuthenticatedUser();
        setUser(currentUser);
      } catch (error) {
        console.log('No authenticated user found');
        setUser(null);
      } finally {
        setLoading(false);
      }
    };

    initializeAuth();

    // Listen for auth state changes
    const unsubscribe = Auth.configure().Auth?.onAuthUIStateChange?.((authState, authData) => {
      if (authState === 'signedIn') {
        setUser(authData);
      } else {
        setUser(null);
      }
    });

    return () => {
      if (unsubscribe) unsubscribe();
    };
  }, []);

  const login = async (email, password) => {
    setLoading(true);
    setError(null);
    
    try {
      const user = await Auth.signIn(email, password);
      setUser(user);
      return user;
    } catch (error) {
      console.error('Login error:', error);
      setError(error.message);
      throw error;
    } finally {
      setLoading(false);
    }
  };

  const register = async (userData) => {
    setLoading(true);
    setError(null);
    
    try {
      const { email, password, ...attributes } = userData;
      const result = await Auth.signUp({
        username: email,
        password,
        attributes: {
          email,
          'custom:role': attributes.role || 'student',
          'custom:student_id': attributes.student_id || '',
          'custom:department': attributes.department || '',
        },
      });
      return result;
    } catch (error) {
      console.error('Registration error:', error);
      setError(error.message);
      throw error;
    } finally {
      setLoading(false);
    }
  };

  const logout = async () => {
    setLoading(true);
    
    try {
      await Auth.signOut();
      setUser(null);
    } catch (error) {
      console.error('Logout error:', error);
      setError(error.message);
    } finally {
      setLoading(false);
    }
  };

  const confirmSignUp = async (username, code) => {
    try {
      await Auth.confirmSignUp(username, code);
      return { success: true };
    } catch (error) {
      console.error('Confirmation error:', error);
      setError(error.message);
      throw error;
    }
  };

  const resendConfirmationCode = async (username) => {
    try {
      await Auth.resendSignUp(username);
      return { success: true };
    } catch (error) {
      console.error('Resend confirmation error:', error);
      setError(error.message);
      throw error;
    }
  };

  const forgotPassword = async (username) => {
    try {
      await Auth.forgotPassword(username);
      return { success: true };
    } catch (error) {
      console.error('Forgot password error:', error);
      setError(error.message);
      throw error;
    }
  };

  const forgotPasswordSubmit = async (username, code, newPassword) => {
    try {
      await Auth.forgotPasswordSubmit(username, code, newPassword);
      return { success: true };
    } catch (error) {
      console.error('Password reset error:', error);
      setError(error.message);
      throw error;
    }
  };

  const value = {
    user,
    loading,
    error,
    login,
    register,
    logout,
    confirmSignUp,
    resendConfirmationCode,
    forgotPassword,
    forgotPasswordSubmit,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
