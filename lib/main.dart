import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _forestGreen = Color(0xFF2E6F40);
const _surfaceGreen = Color(0xFFF4F7F4);
const _adminEmail = 'admin@enchante.com';
const _roomId = 'general';
const _messageRetention = Duration(hours: 24);
const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://virbtdpmxmhdyhypoycy.supabase.co',
);
const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpcmJ0ZHBteG1oZXloeXBveWN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQzMTUzNzAsImV4cCI6MjEwOTg5MTM3MH0.Epvr5fx0Amgi_SBM8_DFzKr_rKO8LX4fZ68ok1xZP2E',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseAnonKey,
  );
  runApp(const EnchanteApp());
}

class EnchanteApp extends StatelessWidget {
  const EnchanteApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _forestGreen,
      surface: Colors.white,
    );
    return MaterialApp(
      title: 'Enchanté',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme.copyWith(
          primary: _forestGreen,
          onPrimary: Colors.white,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: _surfaceGreen,
        appBarTheme: const AppBarTheme(
          backgroundColor: _forestGreen,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surfaceGreen,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _forestGreen, width: 1.5),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      routes: {'/admin': (_) => const AdminRoute()},
      home: home ?? const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return const AuthScreen();
        return const ChatScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _notice = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (_isSignUp) {
        final response = await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (response.session == null && mounted) {
          setState(() {
            _notice = 'Check your email to confirm your account, then sign in.';
          });
        }
      } else {
        await auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to authenticate: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              color: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: _BrandMark(size: 60)),
                      const SizedBox(height: 18),
                      Text(
                        _isSignUp ? 'Join the conversation' : 'Welcome back',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A little more connection, a little less permanence.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (!email.contains('@') || !email.contains('.')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: [
                          _isSignUp
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) {
                          if ((value ?? '').length < 6) {
                            return 'Use at least 6 characters';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        _InlineMessage(text: _error!, isError: true),
                      ],
                      if (_notice != null) ...[
                        const SizedBox(height: 14),
                        _InlineMessage(text: _notice!, isError: false),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isSignUp ? 'Create account' : 'Sign in'),
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() {
                                _isSignUp = !_isSignUp;
                                _error = null;
                                _notice = null;
                              }),
                        child: Text(
                          _isSignUp
                              ? 'Already have an account? Sign in'
                              : 'New here? Create an account',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late Stream<List<Map<String, dynamic>>> _messageStream;
  Timer? _retentionTimer;
  bool _sending = false;
  String? _sendError;

  User get _user => Supabase.instance.client.auth.currentUser!;
  bool get _isAdmin => _user.email?.toLowerCase() == _adminEmail;

  @override
  void initState() {
    super.initState();
    _messageStream = _messagesStream(recentOnly: true);
    _retentionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _retentionTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await Supabase.instance.client.from('messages').insert({
        'text': text,
        'sender_id': _user.id,
        'sender_email': _user.email,
        'room_id': _roomId,
      });
      _textController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      if (mounted) setState(() => _sendError = 'Message not sent: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 760;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: wide ? 28 : 16,
        title: Row(
          children: [
            const _BrandMark(size: 38, inverse: true),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enchanté',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                Text(
                  'General · messages disappear after 24 hours',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: 'Admin archive',
              onPressed: () => Navigator.pushNamed(context, '/admin'),
              icon: const Icon(Icons.archive_outlined),
            ),
          PopupMenuButton<String>(
            tooltip: 'Account menu',
            onSelected: (value) {
              if (value == 'signout') _signOut();
              if (value == 'archive') Navigator.pushNamed(context, '/admin');
            },
            itemBuilder: (context) => [
              PopupMenuItem(enabled: false, child: Text(_user.email ?? '')),
              if (_isAdmin)
                const PopupMenuItem(
                  value: 'archive',
                  child: Text('Open archive'),
                ),
              const PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 22 : 0,
              vertical: wide ? 22 : 0,
            ),
            child: Card(
              clipBehavior: Clip.antiAlias,
              color: Colors.white,
              elevation: wide ? 2 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(wide ? 22 : 0),
              ),
              child: Column(
                children: [
                  _ConversationHeader(isWide: wide),
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF8FAF8),
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _messageStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _StreamError(
                              error: snapshot.error!,
                              onRetry: () => setState(() {
                                _messageStream = _messagesStream(
                                  recentOnly: true,
                                );
                              }),
                            );
                          }
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final cutoff = DateTime.now().toUtc().subtract(
                            _messageRetention,
                          );
                          final messages =
                              (snapshot.data ?? []).where((message) {
                                final createdAt = DateTime.tryParse(
                                  message['created_at'] as String? ?? '',
                                )?.toUtc();
                                return createdAt != null &&
                                    createdAt.isAfter(cutoff);
                              }).toList()..sort((a, b) {
                                final aTime = DateTime.parse(
                                  a['created_at'] as String,
                                );
                                final bTime = DateTime.parse(
                                  b['created_at'] as String,
                                );
                                return aTime.compareTo(bTime);
                              });
                          if (messages.isEmpty) {
                            return const _EmptyConversation();
                          }
                          return ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.symmetric(
                              horizontal: wide ? 42 : 16,
                              vertical: 24,
                            ),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              return _MessageBubble(
                                key: ValueKey(message['id']),
                                message: message,
                                isMine: message['sender_id'] == _user.id,
                                showSender: _isAdmin,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  if (_sendError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _InlineMessage(text: _sendError!, isError: true),
                    ),
                  _Composer(
                    controller: _textController,
                    isSending: _sending,
                    onSend: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Stream<List<Map<String, dynamic>>> _messagesStream({required bool recentOnly}) {
  final query = Supabase.instance.client
      .from('messages')
      .stream(primaryKey: ['id']);
  if (!recentOnly) return query.order('created_at');
  return query
      .eq('room_id', _roomId)
      .gt(
        'created_at',
        DateTime.now().toUtc().subtract(_messageRetention).toIso8601String(),
      )
      .order('created_at');
}

class AdminRoute extends StatelessWidget {
  const AdminRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const AuthScreen();
    if (user.email?.toLowerCase() != _adminEmail) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access denied')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This account is not authorized to view the archive.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return const AdminArchiveScreen();
  }
}

class AdminArchiveScreen extends StatefulWidget {
  const AdminArchiveScreen({super.key});

  @override
  State<AdminArchiveScreen> createState() => _AdminArchiveScreenState();
}

class _AdminArchiveScreenState extends State<AdminArchiveScreen> {
  late Stream<List<Map<String, dynamic>>> _archiveStream;

  @override
  void initState() {
    super.initState();
    _archiveStream = _messagesStream(recentOnly: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Permanent archive'),
            Text(
              'All messages · no expiration filter',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Return to chat',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _archiveStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _StreamError(
                  error: snapshot.error!,
                  onRetry: () => setState(
                    () => _archiveStream = _messagesStream(recentOnly: false),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = (snapshot.data ?? []).toList()
                ..sort((a, b) {
                  return DateTime.parse(b['created_at'] as String)
                      .compareTo(DateTime.parse(a['created_at'] as String));
                });
              if (messages.isEmpty) {
                return const _EmptyConversation(
                  title: 'No archived messages yet',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return _ArchiveEntry(message: message);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ArchiveEntry extends StatelessWidget {
  const _ArchiveEntry({required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(message['created_at'] as String? ?? '');
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _surfaceGreen,
                  child: const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: _forestGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message['sender_email'] as String? ?? 'Unknown sender',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  date == null ? 'Unknown date' : _formatTimestamp(date),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(message['text'] as String? ?? ''),
            const SizedBox(height: 8),
            Text(
              'Room: ${message['room_id'] as String? ?? 'unknown'}',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 26 : 16, vertical: 14),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: _surfaceGreen,
            child: Icon(Icons.groups_2_outlined, color: _forestGreen),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'General chat',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'Messages are available for 24 hours',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Icon(Icons.circle, color: Colors.green.shade600, size: 9),
          const SizedBox(width: 6),
          const Text(
            'Live',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Write a message',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 50,
              width: 50,
              child: FilledButton(
                onPressed: isSending ? null : onSend,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: isSending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required super.key,
    required this.message,
    required this.isMine,
    required this.showSender,
  });

  final Map<String, dynamic> message;
  final bool isMine;
  final bool showSender;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = DateTime.tryParse(
      widget.message['created_at'] as String? ?? '',
    );
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(widget.isMine ? 0.04 : -0.04, 0.02),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
        child: Align(
          alignment: widget.isMine
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width > 700 ? 520 : 300,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
              decoration: BoxDecoration(
                color: widget.isMine ? _forestGreen : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(17),
                  topRight: const Radius.circular(17),
                  bottomLeft: Radius.circular(widget.isMine ? 17 : 5),
                  bottomRight: Radius.circular(widget.isMine ? 5 : 17),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showSender && !widget.isMine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        widget.message['sender_email'] as String? ??
                            'Unknown sender',
                        style: const TextStyle(
                          color: _forestGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Text(
                    widget.message['text'] as String? ?? '',
                    style: TextStyle(
                      color: widget.isMine ? Colors.white : Colors.black87,
                      height: 1.35,
                    ),
                  ),
                  if (timestamp != null)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(
                            color: widget.isMine
                                ? Colors.white70
                                : Colors.black45,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({this.title = 'Your conversation starts here'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF2EA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF46624B)),
        ),
      ),
    );
  }
}

class _StreamError extends StatelessWidget {
  const _StreamError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 36, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Could not load messages',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size, this.inverse = false});

  final double size;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: inverse ? Colors.white.withValues(alpha: 0.16) : _forestGreen,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(Icons.forum_rounded, color: Colors.white, size: size * 0.55),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red.shade50 : Colors.green.shade50;
    final foreground = isError ? Colors.red.shade800 : Colors.green.shade800;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: foreground, fontSize: 13)),
    );
  }
}

String _formatTimestamp(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}
