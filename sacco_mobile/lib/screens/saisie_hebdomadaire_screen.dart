import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http; // <-- L'importation manquante qui corrige l'erreur
import '../services/api_service.dart';
import '../services/cotisation_service.dart';

class SaisieHebdomadaireScreen extends StatefulWidget {
  final int groupId;
  const SaisieHebdomadaireScreen({super.key, required this.groupId});

  @override
  State<SaisieHebdomadaireScreen> createState() => _SaisieHebdomadaireScreenState();
}

class _SaisieHebdomadaireScreenState extends State<SaisieHebdomadaireScreen> {
  DateTime dateReunion = DateTime.now();
  DateTime dateProchaineReunion = DateTime.now().add(const Duration(days: 7));

  List<Map<String, dynamic>> membres = [
    {"id": 1, "nom": "Officiel SECRETAIRE", "presence": "P", "epargne": 5000.0, "caisse": 500.0, "amende": false},
    {"id": 2, "nom": "Officiel PRESIDENT", "presence": "P", "epargne": 5000.0, "caisse": 500.0, "amende": false},
    {"id": 3, "nom": "Raphael NKURUNZIZA", "presence": "P", "epargne": 5000.0, "caisse": 500.0, "amende": false},
  ];

  bool _isSaving = false;
  bool _isUpdatingCalendar = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${"weekly_entry".tr()} - Groupe #${widget.groupId}"),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: DATE DE LA RÉUNION ---
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.calendar_today, color: Color(0xFF00897B)),
                title: Text("date_meeting".tr()),
                subtitle: Text("${dateReunion.toLocal()}".split(' ')[0]),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: dateReunion,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => dateReunion = picked);
                },
              ),
            ),
            const SizedBox(height: 20),

            // --- SECTION 2: LISTE DES MEMBRES ---
            Text(
              "members_group".tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00897B)),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: membres.length,
              itemBuilder: (context, index) {
                var membre = membres[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ExpansionTile(
                    leading: const Icon(Icons.person, color: Colors.grey),
                    title: Text(membre['nom'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${"savings".tr()} : ${membre['epargne']} BIF"),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text("${"presence".tr()} : ", style: const TextStyle(fontWeight: FontWeight.bold)),
                                Radio<String>(
                                  value: "P",
                                  groupValue: membre['presence'],
                                  onChanged: (val) => setState(() => membre['presence'] = val!),
                                ),
                                const Text("P"),
                                Radio<String>(
                                  value: "A",
                                  groupValue: membre['presence'],
                                  onChanged: (val) => setState(() => membre['presence'] = val!),
                                ),
                                const Text("A"),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(child: Text("${"savings".tr()} (BIF) :")),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => setState(() => membre['epargne'] = (membre['epargne'] - 500).clamp(0.0, 999999.0)),
                                ),
                                Text("${membre['epargne']}"),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => setState(() => membre['epargne'] += 500),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(child: Text("${"social_fund".tr()} (BIF) :")),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => setState(() => membre['caisse'] = (membre['caisse'] - 100).clamp(0.0, 999999.0)),
                                ),
                                Text("${membre['caisse']}"),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => setState(() => membre['caisse'] += 100),
                                ),
                              ],
                            ),
                            CheckboxListTile(
                              title: Text("fine".tr()),
                              value: membre['amende'],
                              onChanged: (val) => setState(() => membre['amende'] = val ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 15),
            Center(
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: () async {
                        setState(() => _isSaving = true);
                        String dateStr = dateReunion.toIso8601String().split('T')[0];
                        bool globalSuccess = true;

                        for (var membre in membres) {
                          bool success = await CotisationService.enregistrerCotisation(
                            membreId: membre['id'],
                            montant: membre['epargne'],
                            date: dateStr,
                          );
                          if (!success) globalSuccess = false;
                        }

                        if (mounted) {
                          setState(() => _isSaving = false);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(globalSuccess ? "meeting_save_success".tr() : "Erreur lors de l'enregistrement"),
                              backgroundColor: globalSuccess ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: Text("save_meeting".tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                      ),
                    ),
            ),
            const Divider(height: 40),

            // --- SECTION 3: CALENDRIER DES RÉUNIONS ---
            Text(
              "calendar_meetings".tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00897B)),
            ),
            const SizedBox(height: 10),
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    ListTile(
                      title: Text("next_meeting_date".tr()),
                      subtitle: Text("${dateProchaineReunion.toLocal()}".split(' ')[0]),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: dateProchaineReunion,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => dateProchaineReunion = picked);
                      },
                    ),
                    const SizedBox(height: 10),
                    _isUpdatingCalendar
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: () async {
                              setState(() => _isUpdatingCalendar = true);
                              String formattedDate = dateProchaineReunion.toIso8601String().split('T')[0];

                              try {
                                final response = await httpPutCall(widget.groupId, formattedDate);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(response ? "Calendrier mis à jour avec succès" : "Échec de la mise à jour"),
                                      backgroundColor: response ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Erreur réseau lors de la mise à jour"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isUpdatingCalendar = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                            child: Text("update_calendar".tr(), style: const TextStyle(color: Colors.white)),
                          )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> httpPutCall(int groupId, String dateProchaine) async {
    try {
      final uri = Uri.parse("${ApiService.baseUrl}/groupes/$groupId/modifier-calendrier");
      final response = await http.put(
        uri,
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({"date_reunion_prochaine": dateProchaine}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}