import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';

class ProfilScreen extends StatefulWidget {
  final int membreId;

  const ProfilScreen({super.key, required this.membreId});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profilData;
  final Color primaryColor = const Color(0xFF1A529B);
  Timer? _qrTimer;

  @override
  void initState() {
    super.initState();
    _chargerProfil();

    // Actualise l'écran (et donc le QR code dynamique) toutes les 15 secondes
    _qrTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    super.dispose();
  }

  void _chargerProfil() async {
    try {
      final data = await ApiService.getProfilComplet(widget.membreId);
      if (mounted) {
        setState(() {
          _profilData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement profil : $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (_profilData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text("profil_title".tr()),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.orange),
              const SizedBox(height: 16),
              Text("error_loading_profil".tr()),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _chargerProfil();
                },
                child: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    }

    // --- CORRECTION : Extraction robuste multi-niveaux ---
    final Map<String, dynamic> rootData = _profilData!.containsKey('data')
        ? _profilData!['data']
        : _profilData!;

    String getVal(List<String> keys, {String fallback = '-'}) {
      for (String k in keys) {
        if (rootData[k] != null && rootData[k].toString().trim().isNotEmpty) {
          return rootData[k].toString();
        }
        if (rootData['membre'] is Map<String, dynamic> && rootData['membre'][k] != null && rootData['membre'][k].toString().trim().isNotEmpty) {
          return rootData['membre'][k].toString();
        }
        if (rootData['user'] is Map<String, dynamic> && rootData['user'][k] != null && rootData['user'][k].toString().trim().isNotEmpty) {
          return rootData['user'][k].toString();
        }
        if (rootData['profile'] is Map<String, dynamic> && rootData['profile'][k] != null && rootData['profile'][k].toString().trim().isNotEmpty) {
          return rootData['profile'][k].toString();
        }
        if (rootData['profil'] is Map<String, dynamic> && rootData['profil'][k] != null && rootData['profil'][k].toString().trim().isNotEmpty) {
          return rootData['profil'][k].toString();
        }
      }
      return fallback;
    }

    final nom = getVal(['nom', 'last_name', 'name'], fallback: '');
    final prenom = getVal(['prenom', 'first_name'], fallback: '');
    final fullName = "$prenom $nom".trim();

    final telephone = getVal(['telephone', 'phone']);
    final userIdStr = getVal(['id', 'membre_id'], fallback: widget.membreId.toString());
    final groupeId = getVal(['groupe_id', 'group_id']);
    final cni = getVal(['cni']);
    final age = getVal(['age']);
    final sexe = getVal(['sexe', 'gender']);
    final colline = getVal(['colline']);
    final quartier = getVal(['quartier']);
    final avenue = getVal(['avenue']);
    final maison = getVal(['maison']);
    final role = getVal(['role', 'is_superuser'], fallback: 'MEMBRE').toUpperCase();
    final lastLogin = getVal(['last_login', 'derniere_connexion'], fallback: 'first_session'.tr());

    final groupe = rootData['groupe'] ?? rootData['group'] ?? {};

    // --- GÉNÉRATION DU TOKEN QR DYNAMIQUE ---
    // Change toutes les 30 secondes pour éviter la réutilisation de captures d'écran
    final int timeWindow = DateTime.now().millisecondsSinceEpoch ~/ 30000;
    final String dynamicQrData = "SACCO_MEMBER_${userIdStr}_T$timeWindow";

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
              margin: EdgeInsets.zero,
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
                          value: Locale('fr'),
                          child: Text("🇫🇷 Français"),
                        ),
                        DropdownMenuItem(
                          value: Locale('rn'),
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
                    fullName.isEmpty ? "Nom non spécifié" : fullName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                  ),
                  const SizedBox(height: 8),

                  Text("${'member_id'.tr()} : #00$userIdStr"),
                  Text("${'group_id'.tr()} : #00$groupeId"),
                  const Divider(height: 30),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("🪪 ${'cni'.tr()} : $cni"),
                            Text("🎂 ${'age'.tr()} : $age ${age != '-' ? 'years'.tr() : ''}"),
                            Text("👫 ${'sexe'.tr()} : $sexe"),
                            Text("📞 ${'phone'.tr()} : $telephone"),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("📍 ${'colline'.tr()} : $colline"),
                            Text("🏠 ${'quartier'.tr()} : $quartier"),
                            Text("🛣️ ${'avenue'.tr()} : $avenue"),
                            Text("🚪 ${'maison'.tr()} : $maison"),
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
                        role,
                        style: const TextStyle(color: Color(0xFF3498DB), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text("🕒 ${'last_login'.tr()} : $lastLogin"),
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
                          Text(groupe['date_reunion_derniere']?.toString() ?? 'not_defined'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("next_meeting".tr(), style: const TextStyle(color: Colors.grey)),
                          Text(groupe['date_reunion_prochaine']?.toString() ?? 'to_determine'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
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

            // --- BADGE DE PRÉSENCE NUMÉRIQUE DYNAMIQUE ---
            Text("📲 ${'digital_badge'.tr()}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text("badge_instruction".tr(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  QrImageView(
                    data: dynamicQrData, // Utilisation du token dynamique rafraîchi
                    version: QrVersions.auto,
                    size: 180.0,
                    gapless: false,
                  ),
                  const SizedBox(height: 4),
                  Text("${'badge_of'.tr()} ${fullName.isEmpty ? 'Membre' : fullName}", style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
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
                Expanded(child: Text("${'president'.tr()} : \n${groupe['president'] ?? 'not_defined_leader'.tr()}", style: const TextStyle(fontWeight: FontWeight.w500))),
                Expanded(child: Text("${'secretaire'.tr()} : \n${groupe['secretaire'] ?? 'not_defined_leader'.tr()}", style: const TextStyle(fontWeight: FontWeight.w500), textAlign: TextAlign.center,)),
                Expanded(child: Text("${'admin_sys'.tr()} : \n${groupe['admin_sys'] ?? 'not_defined_leader'.tr()}", style: const TextStyle(fontWeight: FontWeight.w500), textAlign: TextAlign.end,)),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}