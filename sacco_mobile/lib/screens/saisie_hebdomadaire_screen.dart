import 'package:flutter/material.dart';

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
    {"id": 1, "nom": "Officiel SECRETAIRE", "presence": "P", "epargne": 5000, "caisse": 500, "amende": false},
    {"id": 2, "nom": "Officiel PRESIDENT", "presence": "P", "epargne": 5000, "caisse": 500, "amende": false},
    {"id": 3, "nom": "Raphael NKURUNZIZA", "presence": "P", "epargne": 5000, "caisse": 500, "amende": false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Saisie Hebdomadaire - Groupe #${widget.groupId}"),
        backgroundColor: const Color(0xFF00897B),
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
                title: const Text("Date de la réunion"),
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
            const Text(
              "Membres du groupe",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00897B)),
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
                    subtitle: Text("Épargne : ${membre['epargne']} BIF"),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Présence (P / A)
                            Row(
                              children: [
                                const Text("Présence : ", style: TextStyle(fontWeight: FontWeight.bold)),
                                Radio<String>(
                                  value: "P",
                                  groupValue: membre['presence'],
                                  onChanged: (val) => setState(() => membre['presence'] = val),
                                ),
                                const Text("P"),
                                Radio<String>(
                                  value: "A",
                                  groupValue: membre['presence'],
                                  onChanged: (val) => setState(() => membre['presence'] = val),
                                ),
                                const Text("A"),
                              ],
                            ),
                            // Champ Épargne
                            Row(
                              children: [
                                const Expanded(child: Text("Épargne (BIF) :")),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => setState(() => membre['epargne'] = (membre['epargne'] - 500).clamp(0, 999999)),
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
                                const Expanded(child: Text("Caisse Sociale (BIF) :")),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => setState(() => membre['caisse'] = (membre['caisse'] - 100).clamp(0, 999999)),
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
                              title: const Text("Amende"),
                              value: membre['amende'],
                              onChanged: (val) => setState(() => membre['amende'] = val),
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
              child: ElevatedButton.icon(
                onPressed: () {
                  // Logique de sauvegarde API ici
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Données enregistrées localement !"))
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text("Enregistrer la réunion"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B), foregroundColor: Colors.white),
              ),
            ),
            const Divider(height: 40),

            // --- SECTION 3: CALENDRIER DES RÉUNIONS ---
            const Text(
              "🗓️ Calendrier des réunions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00897B)),
            ),
            const SizedBox(height: 10),
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text("Date de la prochaine réunion"),
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
                      child: const Text("Mettre à jour le calendrier du groupe", style: TextStyle(color: Colors.white)),
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