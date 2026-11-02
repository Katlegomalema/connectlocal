import { jest } from '@jest/globals';

const userRepository = {
  getUserById: jest.fn(),
  updateUser: jest.fn(),
  deleteUser: jest.fn()
};
const bookingRepository = { listBookings: jest.fn() };

jest.unstable_mockModule('../../src/repositories/userRepository.js', () => userRepository);
jest.unstable_mockModule('../../src/repositories/bookingRepository.js', () => bookingRepository);
const userService = await import('../../src/services/userService.js');

describe('User service', () => {
  beforeEach(() => jest.clearAllMocks());

  test('updates only allowlisted profile columns', async () => {
    userRepository.updateUser.mockResolvedValue({ id: 'user-1' });
    userRepository.getUserById.mockResolvedValue({
      id: 'user-1',
      full_name: 'Updated Name',
      profile_photo_url: null,
      role: 'customer',
      created_at: '2026-01-01T00:00:00Z',
      email: 'private@example.test'
    });

    const profile = await userService.updateUserProfile(
      { id: 'user-1', role: 'customer' },
      'user-1',
      { fullName: 'Updated Name', role: 'admin', account_status: 'active' }
    );

    expect(userRepository.updateUser).toHaveBeenCalledWith('user-1', { full_name: 'Updated Name' });
    expect(profile).not.toHaveProperty('email');
    expect(profile.role).toBe('customer');
  });

  test('rejects attempts to edit another user profile', async () => {
    await expect(userService.updateUserProfile(
      { id: 'user-1', role: 'customer' },
      'user-2',
      { fullName: 'Unauthorized Edit' }
    )).rejects.toMatchObject({ statusCode: 403 });
    expect(userRepository.updateUser).not.toHaveBeenCalled();
  });
});