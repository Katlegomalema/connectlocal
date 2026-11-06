import { jest } from '@jest/globals';

const repository = {
  getBookingById: jest.fn(),
  getProviderById: jest.fn(),
  getProviderByUserId: jest.fn(),
  getReviewById: jest.fn(),
  createReview: jest.fn(),
  updateReview: jest.fn(),
  replyToReview: jest.fn(),
  deleteReview: jest.fn(),
  hideReview: jest.fn(),
  refreshProviderRating: jest.fn(),
  listVisibleReviews: jest.fn(),
  listAllReviews: jest.fn()
};

jest.unstable_mockModule('../../src/repositories/reviewRepository.js', () => repository);
jest.unstable_mockModule('../../src/services/bookingNotifier.js', () => ({ notifyBookingEvent: jest.fn(async () => {}) }));
const reviewService = await import('../../src/services/reviewService.js');

describe('Review service', () => {
  beforeEach(() => jest.clearAllMocks());

  test('creates a review only for a completed booking owned by the customer', async () => {
    repository.getBookingById.mockResolvedValue({
      id: 'booking-1',
      customer_id: 'customer-1',
      provider_id: 'provider-1',
      status: 'completed',
      balance_status: 'paid'
    });
    repository.createReview.mockResolvedValue({ id: 'review-1', rating: 5 });
    repository.refreshProviderRating.mockResolvedValue({ averageRating: 5, reviewCount: 1 });

    const result = await reviewService.createReview(
      { id: 'customer-1', role: 'customer' },
      { bookingId: 'booking-1', rating: 5, comment: 'Great service' }
    );

    expect(repository.createReview).toHaveBeenCalledWith({
      booking_id: 'booking-1',
      customer_id: 'customer-1',
      provider_id: 'provider-1',
      rating: 5,
      review_text: 'Great service',
      is_flagged: false
    });
    expect(repository.refreshProviderRating).toHaveBeenCalledWith('provider-1');
    expect(result.id).toBe('review-1');
  });

  test('rejects reviews until the balance is paid', async () => {
    repository.getBookingById.mockResolvedValue({
      id: 'booking-1', customer_id: 'customer-1', provider_id: 'provider-1', status: 'completed', balance_status: 'pending'
    });
    await expect(reviewService.createReview(
      { id: 'customer-1', role: 'customer' },
      { bookingId: 'booking-1', rating: 5 }
    )).rejects.toThrow('balance is paid');
    expect(repository.createReview).not.toHaveBeenCalled();
  });

  test('rejects reviews for bookings that are not complete', async () => {
    repository.getBookingById.mockResolvedValue({
      id: 'booking-1',
      customer_id: 'customer-1',
      provider_id: 'provider-1',
      status: 'confirmed'
    });

    await expect(reviewService.createReview(
      { id: 'customer-1', role: 'customer' },
      { bookingId: 'booking-1', rating: 5 }
    )).rejects.toMatchObject({ statusCode: 409 });
    expect(repository.createReview).not.toHaveBeenCalled();
  });

  test('rejects a customer who does not own the completed booking', async () => {
    repository.getBookingById.mockResolvedValue({
      id: 'booking-1',
      customer_id: 'another-customer',
      provider_id: 'provider-1',
      status: 'completed'
    });

    await expect(reviewService.createReview(
      { id: 'customer-1', role: 'customer' },
      { bookingId: 'booking-1', rating: 5 }
    )).rejects.toMatchObject({ statusCode: 403 });
    expect(repository.createReview).not.toHaveBeenCalled();
  });
});