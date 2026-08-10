import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
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
    super.key,
    required this.membreId,
    required this.role,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  bool _hasError = false;
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

    if (mounted) {
      setState(() {
        _effectiveMembreId = int.tryParse(storedId ?? '') ?? widget.membreId;
        _effectiveRole = storedRole ?? widget.role;
      });
    }

    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final data = await ApiService.getDashboardData(_effectiveMembreId);
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      debugPrint("Erreur de chargement du dashboard: $e");
    }
  }

  String _formaterMontant(double montant) {
    try {
      final lang = context.locale.languageCode == 'rn' ? 'fr' : context.locale.languageCode;
      final format = NumberFormat('#,##0', lang);
      return format.format(montant).replaceAll(',', ' ');
    } catch (e) {
      return montant.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;
    const Color primaryColor = Color(0xFF1A56A3);
    const Color secondaryColor = Color(0xFFF3811F);
    final int userGroupId = _dashboardData?['groupe_id'] ?? 1;

    return Scaffold(
      key: ValueKey(currentLocale.toString()),
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
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language, color: Colors.white),
            tooltip: 'language_label'.tr(),
            onSelected: (Locale locale) async {
              await context.setLocale(locale);
              if (mounted) setState(() {});
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<Locale>>[
              PopupMenuItem<Locale>(
                value: const Locale('fr'),
                child: Text(
                  '🇫🇷 Français',
                  style: TextStyle(
                    fontWeight: currentLocale.languageCode == 'fr' ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              PopupMenuItem<Locale>(
                value: const Locale('rn'),
                child: Text(
                  '🇧🇮 Kirundi',
                  style: TextStyle(
                    fontWeight: currentLocale.languageCode == 'rn' ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => context.read<AuthNotifier>().logout(),
          ),
        ],
      ),
      body: _buildBody(context, primaryColor, secondaryColor, userGroupId),
    );
  }

  Widget _buildBody(BuildContext context, Color primaryColor, Color secondaryColor, int userGroupId) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1A56A3)));
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'network_error'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _chargerDonnees,
                icon: const Icon(Icons.refresh),
                label: Text('retry'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
              )
            ],
          ),
        ),
      );
    }

    String roleKey = 'role_${_effectiveRole.toLowerCase()}';

    return Stack(
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
                    color: const Color(0xE6FFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'welcome_space'.tr(),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF757575)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${'role_label'.tr()} : ${roleKey.tr().toUpperCase()}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor), // 🟢 'const' retiré ici
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${'member_id_label'.tr()} : #$_effectiveMembreId',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF616161)),
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
            colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
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
              'amount_fbu'.tr(namedArgs: {'montant': _formaterMontant(solde)}),
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const Divider(color: Colors.white24, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('loan_to_repay'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                Text(
                  'amount_fbu'.tr(namedArgs: {'montant': _formaterMontant(pret)}),
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
        side: const BorderSide(color: Color(0xFFF5F5F5), width: 1),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF757575))),
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
  const ActionsPlaceholderScreen({super.key, required this.title});

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
            const Icon(Icons.construction, size: 80, color: Color(0xFFBDBDBD)),
            const SizedBox(height: 16),
            Text(
              '${'interface_label'.tr()} "$title"',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'backend_ready_label'.tr(),
              style: const TextStyle(color: Color(0xFF757575)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}