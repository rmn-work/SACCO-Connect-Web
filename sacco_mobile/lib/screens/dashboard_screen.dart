import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../providers/auth_notifier.dart';
import 'groupe_screen.dart';
import 'validation_prets_screen.dart';
import 'rapports_financiers_screen.dart';
import 'profil_screen.dart';
import 'portefeuille_pret_screen.dart';
import 'saisie_hebdomadaire_screen.dart';
import 'tableau_groupe_screen.dart';
import 'scanner_presence_screen.dart';
import 'inscription_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int membreId;
  final String role;

  const DashboardScreen({
    Key? key,
    required this.membreId,
    required this.role,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;

  late int _effectiveMembreId;
  late String _effectiveRole;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _initialiserSession();
  }

  Future<void> _initialiserSession() async {
    final storedId = await _storage.read(key: 'user_id');
    final storedRole = await _storage.read(key: 'user_role');

    setState(() {
      _effectiveMembreId = int.tryParse(storedId ?? '') ?? widget.membreId;
      _effectiveRole = storedRole ?? widget.role;
    });

    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    try {
      // L'appel redevient simple, le token est géré automatiquement par ApiService
      final data = await ApiService.getDashboardData(_effectiveMembreId);

      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint("Erreur de chargement du dashboard: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF1A56A3);
    final Color secondaryColor = const Color(0xFFF3811F);

    final int userGroupId = _dashboardData?['groupe_id'] ?? 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'SACCO CONNECT',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              authNotifier.logout();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Stack(
              children: [
                Center(
                  child: Opacity(
                    opacity: 0.06,
                    child: Image.asset(
                      'assets/images/la_confiance.png',
                      width: MediaQuery.of(context).size.width * 0.85,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _chargerDonnees,
                  color: primaryColor,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bienvenue dans votre espace',
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rôle : ${_effectiveRole.toUpperCase()}',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Identifiant Membre : #$_effectiveMembreId',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildSectionTitle('Mon Portefeuille Personnel'),
                        _buildSoldeCard(primaryColor, secondaryColor),
                        const SizedBox(height: 20),

                        _buildMenuCard(
                          Icons.account_balance_wallet,
                          'Mon Compte',
                          'Solde épargne, caisse sociale et demandes de prêts',
                          primaryColor,
                          PortefeuillePretScreen(membreId: _effectiveMembreId),
                        ),
                        _buildMenuCard(
                          Icons.groups,
                          'Groupe',
                          'Informations sur votre groupe Sacco',
                          primaryColor,
                          GroupeScreen(membreId: _effectiveMembreId),
                        ),
                        _buildMenuCard(
                          Icons.person,
                          'Mon Profil',
                          'Consulter vos informations personnelles et votre badge QR',
                          primaryColor,
                          ProfilScreen(membreId: _effectiveMembreId),
                        ),

                        if (_effectiveRole.toLowerCase() == 'admin') ...[
                          const Divider(height: 32),
                          _buildSectionTitle('Administration du Système'),
                          _buildMenuCard(
                            Icons.supervisor_account,
                            'Gérer les utilisateurs',
                            'Approuver les nouveaux comptes',
                            Colors.redAccent,
                            const ActionsPlaceholderScreen(title: 'Gestion des Utilisateurs'),
                          ),
                          _buildMenuCard(
                            Icons.settings,
                            'Configuration SACCO',
                            'Modifier les taux et paramètres généraux',
                            Colors.redAccent,
                            const ActionsPlaceholderScreen(title: 'Configuration Globale'),
                          ),
                        ] else if (_effectiveRole.toLowerCase() == 'president' || _effectiveRole.toLowerCase() == 'secretaire') ...[
                          const Divider(height: 32),
                          _buildSectionTitle('Espace Bureau Exécutif'),
                          _buildMenuCard(
                            Icons.gavel,
                            'Validation des Prêts',
                            'Valider ou rejeter les demandes en attente',
                            secondaryColor,
                            ValidationPretsScreen(membreId: _effectiveMembreId),
                          ),
                          _buildMenuCard(
                            Icons.bar_chart,
                            'Rapports Financiers',
                            'Voir la santé globale de la coopérative',
                            secondaryColor,
                            RapportsFinanciersScreen(membreId: _effectiveMembreId),
                          ),
                          _buildMenuCard(
                            Icons.assignment_turned_in,
                            'Saisie Hebdomadaire',
                            "Gérer la présence, l'épargne et les amendes du groupe",
                            secondaryColor,
                            SaisieHebdomadaireScreen(groupId: userGroupId),
                          ),
                          _buildMenuCard(
                            Icons.qr_code_scanner,
                            'Scanner Présences',
                            "Scanner les badges QR des membres pour l'émargement rapide",
                            secondaryColor,
                            ScannerPresenceScreen(adminId: _effectiveMembreId),
                          ),

                          const Divider(height: 32),
                          _buildSectionTitle('Espace Secrétariat'),
                          _buildMenuCard(
                            Icons.table_chart,
                            'Tableau du Groupe',
                            'Consulter l\'état général et l\'épargne de tous les membres',
                            primaryColor,
                            TableauGroupeScreen(groupId: userGroupId),
                          ),

                          _buildMenuCard(
                            Icons.edit_document,
                            'Enregistrer un membre',
                            'Ajouter un nouveau dossier au système',
                            primaryColor,
                            const InscriptionScreen(),
                          ),

                          _buildMenuCard(
                            Icons.list_alt,
                            'Registre des réunions',
                            'Gérer les procès-verbaux et présences',
                            primaryColor,
                            const ActionsPlaceholderScreen(title: 'Registre de Réunion'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildSoldeCard(Color primaryColor, Color secondaryColor) {
    double solde = _dashboardData?['solde_epargne']?.toDouble() ?? 0.0;
    double pret = _dashboardData?['pret_a_rembourser']?.toDouble() ?? 0.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, primaryColor.withOpacity(0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Solde Total Épargné', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              '$solde FBU',
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const Divider(color: Colors.white24, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Prêt à rembourser', style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text(
                  '$pret BIF',
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(IconData icon, String title, String subtitle, Color color, Widget destination) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade100, width: 1),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
        },
      ),
    );
  }
}

class ActionsPlaceholderScreen extends StatelessWidget {
  final String title;
  const ActionsPlaceholderScreen({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A56A3),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Interface "$title"',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Le module backend et mobile est prêt à être connecté ici.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}