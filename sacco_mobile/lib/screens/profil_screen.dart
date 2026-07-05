import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';

class ProfilScreen extends StatefulWidget {
  final int membreId;

  const ProfilScreen({Key? key, required this.membreId}) : super(key: key);

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profilData;
  final Color primaryColor = const Color(0xFF1A529B);

  @override
  void initState() {
    super.initState();
    _chargerProfil();
  }

  void _chargerProfil() async {
    final data = await ApiService.getPortefeuille(widget.membreId);
    setState(() {
      _profilData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profilData == null) {
      return const Scaffold(
        body: Center(child: Text("Impossible de charger les données du profil.")),
      );
    }

    // Extraction sécurisée des données de la réponse API
    final user = _profilData!['user'] ?? {};
    final groupe = _profilData!['groupe'] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text("📄 Résumé de mon profil"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- BANDEAU INFOS LIVE (Météo / Heure) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                "📅 Bujumbura | Connecté au système SACCO",
                style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // --- CARTE DE PROFIL (GRISE) ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFDDDDDD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${user['prenom'] ?? ''} ${user['nom'] ?? ''}",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                  ),
                  const SizedBox(height: 8),
                  Text("Numéro de Membre ID : #00${user['id'] ?? ''}"),
                  Text("Groupe ID : #00${user['groupe_id'] ?? '-'}"),
                  const Divider(height: 30),

                  // Double colonne pour les détails personnels et localisation
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("🪪 CNI : ${user['cni'] ?? '-'}"),
                            Text("🎂 Âge : ${user['age'] ?? '-'} ans"),
                            Text("👫 Sexe : ${user['sexe'] ?? '-'}"),
                            Text("📞 Tél : ${user['telephone'] ?? '-'}"),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("📍 Colline : ${user['colline'] ?? '-'}"),
                            Text("🏠 Quartier : ${user['quartier'] ?? '-'}"),
                            Text("🛣️ Avenue : ${user['avenue'] ?? '-'}"),
                            Text("🚪 Maison : ${user['maison'] ?? '-'}"),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  Text.rich(
                    TextSpan(
                      text: "🛡️ Rôle : ",
                      children: [
                        TextSpan(
                          text: "${user['role'] ?? 'MEMBRE'}".toUpperCase(),
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- ENCADRÉ CALENDRIER & REUNION (ORANGE) ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(15),
                border: const Border(
                  left: BorderSide(color: Colors.orange, width: 5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "📅 Calendrier & Configuration",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Dernière Réunion", style: TextStyle(color: Colors.grey)),
                          Text(groupe['date_reunion_derniere'] ?? 'Non définie', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Prochaine Réunion", style: TextStyle(color: Colors.grey)),
                          Text(groupe['date_reunion_prochaine'] ?? 'À déterminer', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Cotisation Fixée : ${groupe['montant_hebdo'] ?? '5 000'} BIF",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- BADGE DE PRÉSENCE NUMÉRIQUE (QR CODE) ---
            const Text("📲 Votre Badge de Présence Numérique", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text("Présentez ce QR Code pour faire valider votre présence.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  QrImageView(
                    data: "SACCO_MEMBER_${user['id']}",
                    version: QrVersions.auto,
                    size: 180.0,
                    gapless: false,
                  ),
                  Text("Badge de ${user['prenom'] ?? ''} ${user['nom'] ?? ''}", style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),

            // --- RESPONSABLES DU GROUPE ---
            const Text("👥 Responsables du Groupe", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Président : ${groupe['president'] ?? 'Non défini'}", style: const TextStyle(fontWeight: FontWeight.w500)),
                Text("Secrétaire : ${groupe['secretaire'] ?? 'Non défini'}", style: const TextStyle(fontWeight: FontWeight.w500)),
                Text("Administration du Systéme : ${groupe['admin_sys'] ?? 'Non défini'}", style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}