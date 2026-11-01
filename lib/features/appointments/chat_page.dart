import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';

/// Secure text chat: messages live under the appointment, rules allow only its patient and doctor.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.appointmentId});
  final String appointmentId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    final fs = ref.read(fsProvider);
    _text.clear();
    await act(context, () => fs.db.collection('appointments').doc(widget.appointmentId).collection('messages').add({'text': t, 'senderId': fs.uid, 'createdAt': FieldValue.serverTimestamp()}));
  }

  @override
  Widget build(BuildContext context) {
    final fs = ref.read(fsProvider);
    final stream = fs.db.collection('appointments').doc(widget.appointmentId).collection('messages').orderBy('createdAt').limitToLast(100).snapshots();
    return Scaffold(
      appBar: AppBar(title: const Text('Consultation chat')),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (c, s) {
              if (s.hasError) return const Center(child: Text('Chat unavailable.'));
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final docs = s.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('No messages yet.'));
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final m = docs[i].data();
                  final mine = m['senderId'] == fs.uid;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: mine ? const Color(0xFFD9ECF8) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE3EAF2))),
                      child: Text('${m['text']}'),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(child: TextField(controller: _text, maxLength: 1000, decoration: const InputDecoration(hintText: 'Message', counterText: ''), onSubmitted: (_) => _send())),
              IconButton(onPressed: _send, icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}
