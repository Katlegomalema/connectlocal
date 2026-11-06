import { jest } from '@jest/globals';
import express from 'express';
import request from 'supertest';

const USER_ID = '8b1b6f2e-2c1a-4b2a-9a0a-3f9c9e6a1234';

const userRepository = {
  getUserById: jest.fn(),
  updateUser: jest.fn(),
  deleteUser: jest.fn()
};
const bookingRepository = { listBookings: jest.fn() };

// Fake auth: "Authorization: Bearer good" signs in as USER_ID, anything else is 401.
jest.unstable_mockModule('../../src/middleware/auth.js', () => ({
  verifyToken: (req, res, next) => {
    if (req.headers.authorization !== 'Bearer good') {
      return res.status(401).json({ success: false, code: 'AUTHENTICATION_ERROR' });
    }
    req.user = { id: USER_ID, role: 'customer' };
    return next();
  },
  requireOwnership: () => (req, res, next) => next()
}));
jest.unstable_mockModule('../../src/repositories/userRepository.js', () => userRepository);
jest.unstable_mockModule('../../src/repositories/bookingRepository.js', () => bookingRepository);

const { default: userRoutes } = await import('../../src/routes/user.js');
const { errorHandler } = await import('../../src/middleware/errorHandler.js');

const app = express();
app.use(express.json());
app.use('/api/v1/users', userRoutes);
app.use(errorHandler);

const dbUser = {
  id: USER_ID,
  full_name: 'Jane Doe',
  email: 'jane@example.test',
  phone_number: '+27821234567',
  profile_image: null,
  role: 'customer',
  email_verified: true,
  phone_verified: false,
  created_at: '2026-11-01T00:00:00Z'
};

describe('User routes', () => {
  beforeEach(() => jest.clearAllMocks());

  test('GET /users/me returns the signed-in user profile (not treated as an id)', async () => {
    userRepository.getUserById.mockResolvedValue(dbUser);
    const res = await request(app).get('/api/v1/users/me').set('Authorization', 'Bearer good');
    expect(res.status).toBe(200);
    expect(userRepository.getUserById).toHaveBeenCalledWith(USER_ID);
    expect(res.body.data).toMatchObject({
      id: USER_ID,
      fullName: 'Jane Doe',
      email: 'jane@example.test',
      phoneNumber: '+27821234567',
      emailVerified: true,
      phoneVerified: false,
      isVerified: false,
      role: 'customer'
    });
  });

  test('GET /users/me without a token is 401', async () => {
    const res = await request(app).get('/api/v1/users/me');
    expect(res.status).toBe(401);
    expect(userRepository.getUserById).not.toHaveBeenCalled();
  });

  test('GET /users/<not-a-uuid> is 400 and never hits the database', async () => {
    const res = await request(app).get('/api/v1/users/not-a-uuid');
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('VALIDATION_ERROR');
    expect(userRepository.getUserById).not.toHaveBeenCalled();
  });

  test('PUT /users/:id rejects address (users table has no address column)', async () => {
    const res = await request(app)
      .put(`/api/v1/users/${USER_ID}`)
      .set('Authorization', 'Bearer good')
      .send({ address: '12 Main Rd' });
    expect(res.status).toBe(400);
    expect(userRepository.updateUser).not.toHaveBeenCalled();
  });

  test('changing the phone number resets phone_verified', async () => {
    userRepository.getUserById.mockResolvedValue({ ...dbUser, phone_verified: true });
    userRepository.updateUser.mockResolvedValue({ id: USER_ID });
    const res = await request(app)
      .put(`/api/v1/users/${USER_ID}`)
      .set('Authorization', 'Bearer good')
      .send({ phoneNumber: '+27829999999' });
    expect(res.status).toBe(200);
    expect(userRepository.updateUser).toHaveBeenCalledWith(USER_ID, {
      phone_number: '+27829999999',
      phone_verified: false
    });
  });

  test('saving the same phone number keeps it verified', async () => {
    userRepository.getUserById.mockResolvedValue({ ...dbUser, phone_verified: true });
    userRepository.updateUser.mockResolvedValue({ id: USER_ID });
    await request(app)
      .put(`/api/v1/users/${USER_ID}`)
      .set('Authorization', 'Bearer good')
      .send({ phoneNumber: '+27821234567' });
    expect(userRepository.updateUser).toHaveBeenCalledWith(USER_ID, { phone_number: '+27821234567' });
  });
});
