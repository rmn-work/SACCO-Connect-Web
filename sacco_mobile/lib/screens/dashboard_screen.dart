import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:easy_localization/easy_localization.dart';
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
        title: Text(
          'app_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
                                'welcome_space'.tr(),
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${'role_label'.tr()} : ${_effectiveRole.toUpperCase()}',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${'member_id_label'.tr()} : #$_effectiveMembreId',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildSectionTitle('my_personal_portfolio'.tr()),
                        _buildSoldeCard(primaryColor, secondaryColor),
                        const SizedBox(height: 20),

                        _buildMenuCard(
                          Icons.account_balance_wallet,
                          'my_compte_title'.tr(),
                          'my_compte_desc'.tr(),
                          primaryColor,
                          PortefeuillePretScreen(membreId: _effectiveMembreId),
                        ),
                        _buildMenuCard(
                          Icons.groups,
                          'group_title'.tr(),
                          'group_desc'.tr(),
                          primaryColor,
                          GroupeScreen(membreId: _effectiveMembreId),
                        ),
                        _buildMenuCard(
                          Icons.person,
                          'my_profile_title'.tr(),
                          'my_profile_desc'.tr(),
                          primaryColor,
                          ProfilScreen(membreId: _effectiveMembreId),
                        ),

                        if (_effectiveRole.toLowerCase() == 'admin') ...[
                          const Divider(height: 32),
                          _buildSectionTitle('system_admin_title'.tr()),
                          _buildMenuCard(
                            Icons.supervisor_account,
                            'manage_users_title'.tr(),
                            'manage_users_desc'.tr(),
                            Colors.redAccent,
                            ActionsPlaceholderScreen(title: 'manage_users_title'.tr()),
                          ),
                          _buildMenuCard(
                            Icons.settings,
                            'sacco_config_title'.tr(),
                            'sacco_config_desc'.tr(),
                            Colors.redAccent,
                            ActionsPlaceholderScreen(title: 'sacco_config_title'.tr()),
                          ),
                        ] else if (_effectiveRole.toLowerCase() == 'president' || _effectiveRole.toLowerCase() == 'secretaire') ...[
                          const Divider(height: 32),
                          _buildSectionTitle('executive_space_title'.tr()),
                          _buildMenuCard(
                            Icons.gavel,
                            'loan_validation_title'.tr(),
                            'loan_validation_desc'.tr(),
                            secondaryColor,
                            ValidationPretsScreen(membreId: _effectiveMembreId),
                          ),
                          _buildMenuCard(
                            Icons.bar_chart,
                            'financial_reports_title'.tr(),
                            'financial_reports_desc'.tr(),
                            secondaryColor,
                            RapportsFinanciersScreen(membreId: _effectiveMembreId),
                          ),
                          _buildMenuCard(
                            Icons.assignment_turned_in,
                            'weekly_entry'.tr(),
                            'weekly_entry_desc'.tr(),
                            secondaryColor,
                            SaisieHebdomadaireScreen(groupId: userGroupId),
                          ),
                          _buildMenuCard(
                            Icons.qr_code_scanner,
                            'scan_attendance_title'.tr(),
                            'scan_attendance_desc'.tr(),
                            secondaryColor,
                            ScannerPresenceScreen(adminId: _effectiveMembreId),
                          ),

                          const Divider(height: 32),
                          _buildSectionTitle('secretariat_space_title'.tr()),
                          _buildMenuCard(
                            Icons.table_chart,
                            'group_table_title'.tr(),
                            'group_table_desc'.tr(),
                            primaryColor,
                            TableauGroupeScreen(groupId: userGroupId),
                          ),

                          _buildMenuCard(
                            Icons.edit_document,
                            'register_member_title'.tr(),
                            'register_member_desc'.tr(),
                            primaryColor,
                            const InscriptionScreen(),
                          ),

                          _buildMenuCard(
                            Icons.list_alt,
                            'meeting_register_title'.tr(),
                            'meeting_register_desc'.tr(),
                            primaryColor,
                            ActionsPlaceholderScreen(title: 'meeting_register_title'.tr()),
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
            Text('total_savings_balance'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              '$solde FBU',
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const Divider(color: Colors.white24, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('loan_to_repay'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
              '${'interface_label'.tr()} "$title"',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'backend_ready_label'.tr(),
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}