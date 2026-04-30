
import 'package:flutter/material.dart';
import 'package:diasm_front_endv2/core/api_client.dart';

class ChatbotScreen extends StatefulWidget {
  static const routeName = '/tools/chatbot';

  final bool isEnglish;

  const ChatbotScreen({
    super.key,
    required this.isEnglish,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _messages = <ChatMessage>[];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isSending = false;

  List<String> get _suggestions {
    if (widget.isEnglish) {
      return const [
        'What foods are good for diabetes?',
        'How much should I walk every day?',
        'How does diabetes affect my eyes?',
      ];
    } else {
      return const [
        'ডায়াবেটিসে কী খাবো?',
        'প্রতিদিন কত হাঁটব?',
        'চোখে কী সমস্যা হতে পারে?',
      ];
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _isSending) return;

    final isEn = widget.isEnglish;

    setState(() {
      _messages.add(ChatMessage(isUser: true, text: text));
      _isSending = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final api = ApiClient();
      final lang = isEn ? 'en' : 'bn';

      final response = await api.dio.post(
        '/chatbot/ask',
        data: {
          'message': text,
          'lang': lang,
        },
      );

      String answer;
      String? sourceLabel;

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        answer = (data['answer'] ?? '').toString();

        final source = data['source'];
        if (source is Map<String, dynamic>) {
          final file = source['file'] as String?;
          if (file != null) {
            sourceLabel = _mapFileToLabel(file, isEnglish: isEn);
          }
        }
      } else {
        answer = isEn
            ? 'Sorry, something went wrong. Please try again.'
            : 'দুঃখিত, কিছু সমস্যা হয়েছে। আবার চেষ্টা করুন।';
      }

      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            text: answer,
            sourceLabel: sourceLabel,
          ),
        );
      });
    } catch (_) {
      final isEn = widget.isEnglish;
      final errorText = isEn
          ? 'Sorry, something went wrong. Please try again.'
          : 'দুঃখিত, কিছু সমস্যা হয়েছে। আবার চেষ্টা করুন।';

      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            text: errorText,
          ),
        );
      });
    } finally {
      setState(() {
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  void _handleSuggestionTap(String suggestion) {
    _sendMessage(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.isEnglish;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'DIAsm Assistant' : 'ডায়াসম সহায়ক'),
      ),
      body: Container(
        decoration: BoxDecoration(
          // Soft background gradient (Step 5)
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primary.withOpacity(0.04),
              cs.surface,
            ],
          ),
        ),
        child: Column(
          children: [
            // Info strip with warning (micro-polish: slight shadow + border)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.primary.withOpacity(0.16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEn
                            ? 'This assistant is for education only. It can make mistakes and is not a substitute for your doctor.'
                            : 'এই সহায়কটি শুধুই শিক্ষা সহায়ক। এটি ভুল করতে পারে এবং কখনোই আপনার ডাক্তারের বিকল্প নয়।',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Messages list
            Expanded(
              child: Padding(
                // micro-polish: small horizontal padding wrapper
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: _messages.length + (_isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isSending && index == _messages.length) {
                      // Typing bubble
                      final thinkingText = isEn
                          ? 'DIAsm Assistant is thinking...'
                          : 'ডায়াসম সহায়ক ভাবছে...';
                      return _MessageBubble(
                        isUser: false,
                        text: thinkingText,
                        sourceLabel: null,
                      );
                    }

                    final msg = _messages[index];
                    return _MessageBubble(
                      isUser: msg.isUser,
                      text: msg.text,
                      sourceLabel: msg.sourceLabel,
                    );
                  },
                ),
              ),
            ),

            const Divider(height: 1),

            // Suggestions + input
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Suggestion chips
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final s = _suggestions[index];
                        return _SuggestionChip(
                          label: s,
                          onTap: () => _handleSuggestionTap(s),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Improved input bar
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: cs.primary.withOpacity(0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: isEn
                                  ? 'Type your question...'
                                  : 'আপনার প্রশ্ন লিখুন...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                            ),
                            onSubmitted: _sendMessage,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: _isSending
                              ? null
                              : () => _sendMessage(_textController.text),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isSending
                                  ? cs.outline.withOpacity(0.5)
                                  : cs.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.send_rounded,
                              size: 18,
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final bool isUser;
  final String text;
  final String? sourceLabel;

  ChatMessage({
    required this.isUser,
    required this.text,
    this.sourceLabel,
  });
}

class _MessageBubble extends StatelessWidget {
  final bool isUser;
  final String text;
  final String? sourceLabel;

  const _MessageBubble({
    required this.isUser,
    required this.text,
    this.sourceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.of(context).size.width * 0.72;

    // Colors
    final bgColor = isUser ? cs.primary : cs.surface;
    final textColor = isUser ? cs.onPrimary : cs.onSurface;

    // Bubble shape
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isUser ? 18 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 18),
    );

    // ---------- USER MESSAGE ----------
    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: radius,
              ),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),
        ),
      );
    }

    // ---------- BOT MESSAGE WITH AVATAR ----------
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy_outlined,
              color: cs.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),

          // Bubble
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: radius,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: textColor.withOpacity(0.95),
                          ),
                    ),
                    if (sourceLabel != null && sourceLabel!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Source: $sourceLabel',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: textColor.withOpacity(0.8),
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: cs.primary.withOpacity(0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 14,
              color: cs.primary.withOpacity(0.9),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.9),
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// Map backend file name -> small label for chip
String _mapFileToLabel(String file, {required bool isEnglish}) {
  switch (file) {
    case 'diabetes_basics.txt':
      return isEnglish ? 'Diabetes Basics' : 'ডায়াবেটিসের তথ্য';
    case 'diabetes_bn_knowledge.txt':
      return 'ডায়াবেটিসের তথ্য';
    case 'food_diabetes.txt':
      return isEnglish ? 'Food & Diet' : 'খাদ্য ও ডায়েট';
    case 'glucose.insulin.txt':
      return isEnglish ? 'Insulin & Glucose' : 'ইনসুলিন ও গ্লুকোজ';
    case 'complications.txt':
      return isEnglish ? 'Complications' : 'জটিলতা';
    case 'complication_bn.txt':
      return 'জটিলতা';
    case 'diabetes_excercise.txt':
      return isEnglish ? 'Exercise for Diabetes' : 'ডায়াবেটিসে ব্যায়াম';
    case 'exercise_tips_bn.txt':
      return 'ব্যায়ামের টিপস';
    case 'mental_health.txt':
      return isEnglish ? 'Mental Health' : 'মানসিক স্বাস্থ্য';
    case 'mental_health_bn.txt':
      return 'মানসিক স্বাস্থ্য';
    case 'medication_awareness.txt':
      return isEnglish ? 'Medication Awareness' : 'ওষুধ সম্পর্কে সচেতনতা';
    case 'medication_awareness_bn.txt':
      return 'ওষুধ সম্পর্কে সচেতনতা';
    default:
      return isEnglish ? 'Knowledge Base' : 'তথ্যসূত্র';
  }
}
