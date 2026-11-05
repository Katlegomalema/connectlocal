import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../theme/app_theme.dart';
import '../widgets/conversation_tile.dart';
import 'chat_detail_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = sampleConversations.where((chat) {
      return chat.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Search messages',
            onPressed: () {
              showSearch(
                context: context,
                delegate: _MessageSearchDelegate(),
              );
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'New message',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(duration: const Duration(seconds: 3), 
                  content: Text('New message feature coming soon'),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 27),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search conversations',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: conversations.isEmpty
                ? const Center(
              child: Text(
                'No conversations found',
                style: TextStyle(color: AppTheme.muted),
              ),
            )
                : ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 80,
                color: AppTheme.border,
              ),
              itemBuilder: (context, index) {
                final chat = conversations[index];

                return ConversationTile(
                  conversation: chat,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(
                          conversation: chat,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      onPressed: () => query = '',
      icon: const Icon(Icons.clear),
    ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, ''),
    icon: const Icon(Icons.arrow_back),
  );

  @override
  Widget buildResults(BuildContext context) =>
      _buildMatches(context);

  @override
  Widget buildSuggestions(BuildContext context) =>
      _buildMatches(context);

  Widget _buildMatches(BuildContext context) {
    final matches = sampleConversations.where(
          (chat) => chat.name.toLowerCase().contains(query.toLowerCase()),
    );

    return ListView(
      children: matches.map((chat) {
        return ConversationTile(
          conversation: chat,
          onTap: () {
            close(context, chat.name);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatDetailScreen(
                  conversation: chat,
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}