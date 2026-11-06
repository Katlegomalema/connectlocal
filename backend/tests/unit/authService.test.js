import { jest } from '@jest/globals';

const supabase = {
  auth: {
    signUp: jest.fn(),
    signInWithPassword: jest.fn(),
    refreshSession: jest.fn(),
    verifyOtp: jest.fn(),
    resetPasswordForEmail: jest.fn(),
    signInWithOtp: jest.fn(),
    resend: jest.fn()
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

  test('sign-up sends the chosen role to Supabase and uses the row the database trigger created', async () => {
    supabase.auth.signUp.mockResolvedValue({
      data: {
        user: {
          id: 'auth-user-1', email: 'person@example.test', email_confirmed_at: null, identities: [{ id: 'i1' }]
        },
        session: null
      },
      error: null
    });
    userRepository.getUserById.mockResolvedValue({ id: 'auth-user-1', role: 'provider', full_name: 'Test Provider' });

    const user = await authService.registerUser('person@example.test', 'StrongPassword123!', {
      fullName: 'Test   Provider', role: 'provider'
    });

    expect(supabase.auth.signUp).toHaveBeenCalledWith(expect.objectContaining({
      email: 'person@example.test',
      options: expect.objectContaining({ data: { full_name: 'Test Provider', role: 'provider' } })
    }));
    // The trigger already created public.users; no second insert (that used to fail with a duplicate key).
    expect(userRepository.createUser).not.toHaveBeenCalled();
    expect(user.application_profile.role).toBe('provider');
  });

  test('sign-up creates the profile itself only if the trigger did not', async () => {
    const { NotFoundError } = await import('../../src/utils/errors.js');
    supabase.auth.signUp.mockResolvedValue({
      data: { user: { id: 'u2', email: 'p@example.test', identities: [{}] }, session: null }, error: null
    });
    userRepository.getUserById.mockRejectedValue(new NotFoundError('User not found'));
    userRepository.createUser.mockResolvedValue({ id: 'u2', role: 'customer' });

    await authService.registerUser('p@example.test', 'StrongPassword123!', { fullName: 'Pat Doe', role: 'customer' });

    expect(userRepository.createUser).toHaveBeenCalledWith(expect.objectContaining({ id: 'u2', role: 'customer' }));
  });

  test('an already registered email is a 409', async () => {
    supabase.auth.signUp.mockResolvedValue({
      data: { user: { id: 'fake', email: 'p@example.test', identities: [] }, session: null }, error: null
    });
    await expect(authService.registerUser('p@example.test', 'StrongPassword123!', { fullName: 'Pat Doe', role: 'customer' }))
      .rejects.toMatchObject({ statusCode: 409 });
  });

  test('a weak password from Supabase is a 400, not a 401', async () => {
    supabase.auth.signUp.mockResolvedValue({ data: {}, error: { code: 'weak_password', message: 'Password is too weak' } });
    await expect(authService.registerUser('p@example.test', 'x', { fullName: 'Pat Doe', role: 'customer' }))
      .rejects.toMatchObject({ statusCode: 400 });
  });

  test("Supabase's password policy and email limit get plain messages", async () => {
    supabase.auth.signUp.mockResolvedValue({
      data: {},
      error: { code: 'weak_password', message: 'Password should contain at least one character of each: abc, ABC, 012, !@#$%^&*()' }
    });
    await expect(authService.registerUser('p@example.test', 'Longpass11', { fullName: 'Pat Doe', role: 'customer' }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('add a symbol') });

    supabase.auth.signUp.mockResolvedValue({ data: {}, error: { code: 'over_email_send_rate_limit', status: 429 } });
    await expect(authService.registerUser('p@example.test', 'Longpass11!', { fullName: 'Pat Doe', role: 'customer' }))
      .rejects.toMatchObject({ statusCode: 429, message: expect.stringContaining('confirmation emails') });
  });

  test('sign-up never accepts the admin role', async () => {
    await expect(authService.registerUser('p@example.test', 'StrongPassword123!', { fullName: 'Pat Doe', role: 'admin' }))
      .rejects.toMatchObject({ statusCode: 400 });
    expect(supabase.auth.signUp).not.toHaveBeenCalled();
  });

  test('login with an unconfirmed email says so (403), not "wrong password"', async () => {
    supabase.auth.signInWithPassword.mockResolvedValue({
      data: {}, error: { code: 'email_not_confirmed', message: 'Email not confirmed', status: 400 }
    });
    await expect(authService.loginUser('p@example.test', 'StrongPassword123!'))
      .rejects.toMatchObject({ statusCode: 403, code: 'EMAIL_NOT_CONFIRMED' });
  });

  test('uses the database profile role when logging in', async () => {
    supabase.auth.signInWithPassword.mockResolvedValue({
      data: {
        user: { id: 'auth-user-1', email: 'person@example.test', user_metadata: { role: 'admin' } },
        session: { access_token: 'access', refresh_token: 'refresh' }
      },
      error: null
    });
    userRepository.getUserById.mockResolvedValue({ id: 'auth-user-1', role: 'customer', is_active: true });

    const result = await authService.loginUser('person@example.test', 'StrongPassword123!');

    expect(result.user.role).toBe('customer');
    expect(result.session.access_token).toBe('access');
  });

  test('login syncs email_verified when Supabase already confirmed the email', async () => {
    supabase.auth.signInWithPassword.mockResolvedValue({
      data: { user: { id: 'u1', email_confirmed_at: '2026-11-01T00:00:00Z' }, session: { access_token: 't' } },
      error: null
    });
    userRepository.getUserById.mockResolvedValue({ id: 'u1', role: 'customer', is_active: true, email_verified: false });
    userRepository.updateUser.mockResolvedValue({ id: 'u1', role: 'customer', is_active: true, email_verified: true });

    const { user } = await authService.loginUser('person@example.test', 'StrongPassword123!');

    expect(userRepository.updateUser).toHaveBeenCalledWith('u1', { email_verified: true });
    expect(user.email_verified).toBe(true);
  });

  test('rejects login for an inactive account', async () => {
    supabase.auth.signInWithPassword.mockResolvedValue({
      data: { user: { id: 'auth-user-1' }, session: { access_token: 'access' } },
      error: null
    });
    userRepository.getUserById.mockResolvedValue({ id: 'auth-user-1', role: 'customer', is_active: false });

    await expect(authService.loginUser('person@example.test', 'StrongPassword123!'))
      .rejects.toMatchObject({ statusCode: 403 });
  });

  test('revokes the caller token on logout', async () => {
    supabaseAdmin.auth.admin.signOut.mockResolvedValue({ error: null });
    await expect(authService.logoutUser('access-token')).resolves.toEqual({ success: true });
    expect(supabaseAdmin.auth.admin.signOut).toHaveBeenCalledWith('access-token', 'global');
  });
});