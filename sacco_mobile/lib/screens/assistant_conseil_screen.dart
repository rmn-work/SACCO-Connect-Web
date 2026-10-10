import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AssistantConseilScreen extends StatefulWidget {
  final int membreId;
  const AssistantConseilScreen({super.key, required this.membreId});

  @override
  State<AssistantConseilScreen> createState() => _AssistantConseilScreenState();
}

class _AssistantConseilScreenState extends State<AssistantConseilScreen> {
  final Color primaryColor = const Color(0xFF1A56A3);
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  Map<String, dynamic>? _scoringData;
  bool _isLoadingScoring = true;

  @override
  void initState() {
    super.initState();
    _chargerScoring();
    _messages.add({
      "sender": "bot",
      "text": "Mwaramutse ! Je suis votre assistant SACCO. Posez-moi vos questions sur votre solde, vos prêts ou vos réunions."
    });
  }

  Future<void> _chargerScoring() async {
    final data = await ApiService.getCreditScoring(widget.membreId);
    if (mounted) {
      setState(() {
        _scoringData = data;
        _isLoadingScoring = false;
      });
    }
  }

  void _envoyerMessage() async {
    String texte = _messageController.text.trim();
    if (texte.isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": texte});
      _messageController.clear();
      _isLoading = true;
    });

    String reponseBot = await ApiService.poserQuestionAssistant(texte);

    if (mounted) {
      setState(() {
        _messages.add({"sender": "bot", "text": reponseBot});
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assistant & Santé Financière", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          if (!_isLoadingScoring && _scoringData != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Score de Crédit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Chip(
                        label: Text("${_scoringData!['score']} / 100", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: _scoringData!['couleur'] == 'green' ? Colors.green : Colors.orange,
                      ),
                    ],
                  ),
                  Text(_scoringData!['avis'], style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                bool isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? primaryColor : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(color: isUser ? Colors.white : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: "Posez votre question...",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _envoyerMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: primaryColor),
                  onPressed: _envoyerMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}