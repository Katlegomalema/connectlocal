import { jest } from '@jest/globals';

const repository = {
  getUserById: jest.fn(),
  getProviderByUserId: jest.fn(),
  getProviderById: jest.fn(),
  getBookingById: jest.fn(),
  getConversationById: jest.fn(),
  findConversation: jest.fn(),
  findConversationBetween: jest.fn(),
  createConversation: jest.fn(),
  listConversations: jest.fn(),
  createMessage: jest.fn(),
  listMessages: jest.fn(),
  getMessageById: jest.fn(),
  updateMessageStatus: jest.fn(),
  deleteMessage: jest.fn()
};

jest.unstable_mockModule('../../src/repositories/messageRepository.js', () => repository);
const messageService = await import('../../src/services/messageService.js');

describe('Message service', () => {
  beforeEach(() => jest.clearAllMocks());

  test('a conversation id from someone outside that conversation is refused', async () => {
    repository.getUserById.mockResolvedValue({ id: 'customer-1', role: 'customer', is_active: true });
    repository.findConversationBetween.mockResolvedValue(null);
    repository.getConversationById.mockResolvedValue({ id: 'c-other', user_a_id: 'customer-1', user_b_id: 'provider-2' });
    await expect(messageService.sendMessage({ id: 'provider-9', role: 'provider' },
      { conversationId: 'c-other', receiverId: 'customer-1' }, 'hello')).rejects.toThrow('not a participant');
    expect(repository.createMessage).not.toHaveBeenCalled();
  });

  test('persists a message only for a conversation participant', async () => {
    repository.getConversationById.mockResolvedValue({
      id: 'conversation-1',
      booking_id: null,
      user_a_id: 'customer-1',
      user_b_id: 'provider-1'
    });
    repository.createMessage.mockResolvedValue({ id: 'message-1', body: 'Hello' });

    const result = await messageService.sendMessage(
      { id: 'customer-1', role: 'customer' },
      { conversationId: 'conversation-1' },
      '  Hello  '
    );

    expect(repository.createMessage).toHaveBeenCalledWith({
      conversation_id: 'conversation-1',
      booking_id: null,
      sender_id: 'customer-1',
      receiver_id: 'provider-1',
      message_text: 'Hello',
      is_read: false
    });
    expect(result.id).toBe('message-1');
  });

  test('rejects history access by a non-participant', async () => {
    repository.getConversationById.mockResolvedValue({
      id: 'conversation-1',
      user_a_id: 'customer-1',
      user_b_id: 'provider-1'
    });

    await expect(messageService.getConversation(
      { id: 'other-user', role: 'customer' },
      'conversation-1'
    )).rejects.toMatchObject({ statusCode: 403 });
    expect(repository.listMessages).not.toHaveBeenCalled();
  });

  test('rejects marking the caller\'s own message as read', async () => {
    repository.getMessageById.mockResolvedValue({
      id: 'message-1',
      conversation_id: 'conversation-1',
      sender_id: 'customer-1',
      receiver_id: 'provider-1',
      is_read: false
    });
    repository.getConversationById.mockResolvedValue({
      id: 'conversation-1',
      user_a_id: 'customer-1',
      user_b_id: 'provider-1'
    });

    await expect(messageService.markAsRead(
      { id: 'customer-1', role: 'customer' },
      'message-1'
    )).rejects.toMatchObject({ statusCode: 403 });
    expect(repository.updateMessageStatus).not.toHaveBeenCalled();
  });
});