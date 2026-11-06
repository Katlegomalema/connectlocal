import request from 'supertest';
import app from '../../src/app.js';

describe('Protected user REST endpoints', () => {
  test('requires authentication before updating a user profile', async () => {
    const response = await request(app)
      .put('/api/v1/users/00000000-0000-4000-8000-000000000001')
      .send({ fullName: 'Updated Name' });

    expect(response.status).toBe(401);
  });

  test('requires authentication before deleting a user account', async () => {
    const response = await request(app)
      .delete('/api/v1/users/00000000-0000-4000-8000-000000000001');

    expect(response.status).toBe(401);
  });
});
