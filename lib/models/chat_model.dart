class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isMe,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class ChatConversation {
  final String name;
  final String preview;
  final String timeLabel;
  final List<ChatMessage> messages;

  ChatConversation({
    required this.name,
    required this.preview,
    required this.timeLabel,
    required this.messages,
  });
}

final List<ChatConversation> sampleConversations = [
  ChatConversation(
    name: 'Bobs Plumbing',
    preview: 'Good day, I’ll be there soon!',
    timeLabel: '2m ago',
    messages: [
      ChatMessage(
        text: 'Good day!!',
        isMe: false,
        time: DateTime.now(),
      ),
      ChatMessage(
        text: 'I confirmed your booking for 10 AM',
        isMe: false,
      ),
      ChatMessage(text: 'Good day sir!', isMe: true),
      ChatMessage(text: 'Great, thank you!', isMe: true),
      ChatMessage(text: 'I’ll be there on time', isMe: false),
      ChatMessage(text: 'See you', isMe: true),
    ],
  ),
  ChatConversation(
    name: 'Johns Tutoring',
    preview: 'See you tomorrow!',
    timeLabel: '2h ago',
    messages: [
      ChatMessage(
        text: 'Hello! Are we still meeting tomorrow?',
        isMe: false,
      ),
      ChatMessage(
        text: 'Yes, see you tomorrow!',
        isMe: true,
      ),
    ],
  ),
];