import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // Importation de easy_localization
import '../services/cotisation_service.dart';

class SaisieHebdomadaireScreen extends StatefulWidget {
  final int groupId;
  const SaisieHebdomadaireScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  State<SaisieHebdomadaireScreen> createState() => _SaisieHebdomadaireScreenState();
}

class _SaisieHebdomadaireScreenState extends State<SaisieHebdomadaireScreen> {
  DateTime dateReunion = DateTime.now();
  DateTime dateProchaineReunion = DateTime.now().add(const Duration(days: 7));

  // Exemple de données membres locales (à remplacer plus tard par l'appel API)
  List<Map<String, dynamic>> membres = [
    {"id": 1, "nom": "Officiel SECRETAIRE", "presence": "P", "epargne": 5000.0, "caisse": 500.0, "amende": false},
    {"id": 2, "nom": "Officiel PRESIDENT", "presence": "P", "epargne": 5000.0, "caisse": 500.0, "amende": false},
    {"id": 3, "nom": "Raphael NKURUNZIZA", "presence": "P", "epargne": 5000.0, "caisse": 500.0, "amende": false},
  ];

  bool _isSaving = false;

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

            // --- SECTION 2: LISTE DES MEMBRES (ACCORDIONS) ---
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
                            // Présence (P / A)
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
                            // Champ Épargne
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
                            // Champ Caisse Sociale
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
                            // Amende Checkbox
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
                        String dateStr = dateReunion.toIso8601String();
                        bool globalSuccess = true;

                        // Boucle pour enregistrer les cotisations de chaque membre présent/actif
                        for (var membre in membres) {
                          bool success = await CotisationService.enregistrerCotisation(
                            membreId: membre['id'],
                            montant: membre['epargne'],
                            date: dateStr,
                          );
                          if (!success) globalSuccess = false;
                        }

                        setState(() => _isSaving = false);

                        if (globalSuccess && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("meeting_save_success".tr()),
                              backgroundColor: Colors.green,
                            ),
                          );
                          setState(() {});
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
                    ElevatedButton(
                      onPressed: () {
                        // Mettre à jour calendrier API
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
}