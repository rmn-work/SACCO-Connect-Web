import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class RegistreReunionsScreen extends StatefulWidget {
  final int groupId;
  const RegistreReunionsScreen({super.key, required this.groupId});

  @override
  State<RegistreReunionsScreen> createState() => _RegistreReunionsScreenState();
}

class _RegistreReunionsScreenState extends State<RegistreReunionsScreen> {
  bool _isLoading = true;
  List<dynamic> _reunions = [];

  @override
  void initState() {
    super.initState();
    _chargerHistoriqueReunions();
  }

  Future<void> _chargerHistoriqueReunions() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse("${ApiService.baseUrl}/groupes/${widget.groupId}/reunions/");
      final response = await http.get(
        uri,
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> listRaw = (data is List) ? data : (data['data'] ?? []);
        if (mounted) {
          setState(() {
            _reunions = listRaw;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Erreur chargement registre réunions: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF1A56A3);

    return Scaffold(
      appBar: AppBar(
        title: Text('meeting_register_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reunions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      "Aucun historique de réunion enregistré pour ce groupe.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reunions.length,
                  itemBuilder: (context, index) {
                    var reunion = _reunions[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE0F2F1),
                          child: Icon(Icons.event_note, color: Color(0xFF00897B)),
                        ),
                        title: Text("Réunion du : ${reunion['date'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Présents : ${reunion['presents_count'] ?? 0} | Cotisations : ${reunion['total_cotise'] ?? 0} BIF"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        onTap: () {
                          // Détails de la réunion si nécessaire
                        },
                      ),
                    );
                  },
                ),
    );
  }
}