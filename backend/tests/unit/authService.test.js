import { jest } from '@jest/globals';

const supabase = {
  auth: {
    signUp: jest.fn(),
    signInWithPassword: jest.fn(),
    refreshSession: jest.fn(),
    verifyOtp: jest.fn(),
    resetPasswordForEmail: jest.fn(),
    signInWithOtp: jest.fn()
  }
};
const supabaseAdmin = {
  auth: {
    admin: {
      deleteUser: jest.fn(),
      updateUserById: jest.fn(),
      signOut: jest.fn()
    }
  }
};
const userRepository = {
  getUserById: jest.fn(),
  createUser: jest.fn(),
  updateUser: jest.fn()
};

jest.unstable_mockModule('../../src/config/supabase.js', () => ({ supabase, supabaseAdmin }));
jest.unstable_mockModule('../../src/repositories/userRepository.js', () => userRepository);
const authService = await import('../../src/services/authService.js');

describe('Auth service', () => {
  beforeEach(() => jest.clearAllMocks());

  test('registers through Supabase Auth and creates an application profile', async () => {
    supabase.auth.signUp.mockResolvedValue({
      data: { user: { id: 'auth-user-1', email: 'person@example.test', email_confirmed_at: null }, session: null },
      error: null
    });
    userRepository.createUser.mockResolvedValue({ id: 'auth-user-1', role: 'provider', full_name: 'Test Provider' });

    const user = await authService.registerUser('person@example.test', 'StrongPassword123!', {
      firstName: 'Test', lastName: 'Provider', role: 'provider', phone: '+27123456789'
    });

    expect(supabase.auth.signUp).toHaveBeenCalledWith(expect.objectContaining({
      email: 'person@example.test',
      options: { data: { full_name: 'Test Provider' } }
    }));
    expect(userRepository.createUser).toHaveBeenCalledWith(expect.objectContaining({
      id: 'auth-user-1', role: 'provider', full_name: 'Test Provider', phone_number: '+27123456789'
    }));
    expect(user.application_profile.role).toBe('provider');
  });

  test('uses the database profile role when logging in', async () => {
    supabase.auth.signInWithPassword.mockResolvedValue({
      data: {
        user: { id: 'auth-user-1', email: 'person@example.test', user_metadata: { role: 'admin' } },
        session: { access_token: 'access', refresh_token: 'refresh' }
      },
      error: null
    });
    userRepository.getUserById.mockResolvedValue({ id: 'auth-user-1', role: 'customer', account_status: 'active' });

    const result = await authService.loginUser('person@example.test', 'StrongPassword123!');

    expect(result.user.role).toBe('customer');
    expect(result.session.access_token).toBe('access');
  });

  test('rejects login for an inactive account', async () => {
    supabase.auth.signInWithPassword.mockResolvedValue({
      data: { user: { id: 'auth-user-1' }, session: { access_token: 'access' } },
      error: null
    });
    userRepository.getUserById.mockResolvedValue({ id: 'auth-user-1', role: 'customer', account_status: 'suspended' });

    await expect(authService.loginUser('person@example.test', 'StrongPassword123!'))
      .rejects.toMatchObject({ statusCode: 401 });
  });

  test('revokes the caller token on logout', async () => {
    supabaseAdmin.auth.admin.signOut.mockResolvedValue({ error: null });
    await expect(authService.logoutUser('access-token')).resolves.toEqual({ success: true });
    expect(supabaseAdmin.auth.admin.signOut).toHaveBeenCalledWith('access-token', 'global');
  });
});