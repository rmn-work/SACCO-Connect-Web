import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
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
      return Scaffold(
        body: Center(child: Text("error_loading_profil".tr())),
      );
    }

    final user = _profilData!['user'] ?? {};
    final groupe = _profilData!['groupe'] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text("profil_title".tr()),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- BANDEAU DE CONNEXION ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                "bujumbura_connexion".tr(),
                style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // --- SECTION SÉLECTEUR DE LANGUE ---
            Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.language, color: Color(0xFF1A529B)),
                        const SizedBox(width: 12),
                        Text(
                          "language_label".tr(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    DropdownButton<Locale>(
                      value: context.locale,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1A529B)),
                      items: const [
                        DropdownMenuItem(
                          value: Locale('fr', 'FR'),
                          child: Text("🇫🇷 Français"),
                        ),
                        DropdownMenuItem(
                          value: Locale('rn', 'BI'),
                          child: Text("🇧🇮 Kirundi"),
                        ),
                      ],
                      onChanged: (Locale? newLocale) {
                        if (newLocale != null) {
                          context.setLocale(newLocale);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- CARTE DE PROFIL ---
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

                  Text("${'member_id'.tr()} : #00${user['id'] ?? ''}"),
                  Text("${'group_id'.tr()} : #00${user['groupe_id'] ?? '-'}"),
                  const Divider(height: 30),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("🪪 ${'cni'.tr()} : ${user['cni'] ?? '-'}"),
                            Text("🎂 ${'age'.tr()} : ${user['age'] ?? '-'} ans"),
                            Text("👫 ${'sexe'.tr()} : ${user['sexe'] ?? '-'}"),
                            Text("📞 ${'phone'.tr()} : ${user['telephone'] ?? '-'}"),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("📍 ${'colline'.tr()} : ${user['colline'] ?? '-'}"),
                            Text("🏠 ${'quartier'.tr()} : ${user['quartier'] ?? '-'}"),
                            Text("🛣️ ${'avenue'.tr()} : ${user['avenue'] ?? '-'}"),
                            Text("🚪 ${'maison'.tr()} : ${user['maison'] ?? '-'}"),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 30),

                  Row(
                    children: [
                      Text("🛡️ ${'role'.tr()} : ", style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        (user['role'] ?? 'MEMBRE').toUpperCase(),
                        style: const TextStyle(color: Color(0xFF3498DB), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text("🕒 ${'last_login'.tr()} : ${user['last_login'] ?? 'first_session'.tr()}"),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- ENCADRÉ CALENDRIER & REUNION ---
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
                  Text(
                    "calendar_config".tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("last_meeting".tr(), style: const TextStyle(color: Colors.grey)),
                          Text(groupe['date_reunion_derniere'] ?? 'not_defined'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("next_meeting".tr(), style: const TextStyle(color: Colors.grey)),
                          Text(groupe['date_reunion_prochaine'] ?? 'to_determine'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${'fixed_contribution'.tr()} : ${groupe['montant_hebdo'] ?? '5 000'} BIF",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- BADGE DE PRÉSENCE NUMÉRIQUE ---
            Text("📲 ${'digital_badge'.tr()}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text("badge_instruction".tr(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                  Text("${'badge_of'.tr()} ${user['prenom'] ?? ''} ${user['nom'] ?? ''}", style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),

            // --- RESPONSABLES DU GROUPE ---
            Text("👥 ${'group_leaders'.tr()}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${'president'.tr()} : ${groupe['president'] ?? 'not_defined_leader'.tr()}", style: const TextStyle(fontWeight: FontWeight.w500)),
                Text("${'secretaire'.tr()} : ${groupe['secretaire'] ?? 'not_defined_leader'.tr()}", style: const TextStyle(fontWeight: FontWeight.w500)),
                Text("${'admin_sys'.tr()} : ${groupe['admin_sys'] ?? 'not_defined_leader'.tr()}", style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}