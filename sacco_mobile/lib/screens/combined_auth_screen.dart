import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'inscription_screen.dart';
import '../services/api_service.dart';
import '../services/local_database.dart';
import '../providers/auth_notifier.dart';

class CombinedAuthScreen extends StatefulWidget {
  const CombinedAuthScreen({super.key});

  @override
  State<CombinedAuthScreen> createState() => _CombinedAuthScreenState();
}

class _CombinedAuthScreenState extends State<CombinedAuthScreen> {
  bool _showOnboarding = true;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  final _storage = const FlutterSecureStorage();

  List<Map<String, String>> get _onboardingData => [
    {
      "title": "",
      "subtitle": "onboarding_sub_0",
      "description": "onboarding_desc_0",
    },
    {
      "title": "onboarding_title_1",
      "subtitle": "onboarding_sub_1",
      "description": "onboarding_desc_1",
    },
    {
      "title": "onboarding_title_2",
      "subtitle": "onboarding_sub_2",
      "description": "onboarding_desc_2",
    },
    {
      "title": "onboarding_title_3",
      "subtitle": "onboarding_sub_3",
      "description": "onboarding_desc_3",
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1];
      switch (payload.length % 4) {
        case 2: payload += '=='; break;
        case 3: payload += '='; break;
      }
      final decodedBytes = base64Url.decode(payload);
      final decodedString = utf8.decode(decodedBytes);
      return jsonDecode(decodedString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Erreur lors du décodage du JWT : $e");
      return null;
    }
  }

  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();

    if (phone.isEmpty || pin.isEmpty) {
      setState(() {
        _errorMessage = "Veuillez remplir tous les champs.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final responseData = await ApiService.login(phone, pin);

      if (responseData != null) {
        final token = responseData['access_token'] ?? responseData['token'] ?? '';
        dynamic membreId = responseData['membre_id'] ?? responseData['id'];
        String role = responseData['role'] ?? 'membre';

        if ((membreId == null || membreId == 1) && token.isNotEmpty) {
          final jwtData = _decodeJwt(token);
          if (jwtData != null) {
            membreId = jwtData['membre_id'] ?? jwtData['id'] ?? jwtData['sub'];
            role = jwtData['role'] ?? role;
          }
        }

        if (membreId == null) {
          setState(() {
            _errorMessage = "Impossible de récupérer l'identifiant de l'utilisateur.";
          });
          return;
        }

        await _storage.write(key: 'user_id', value: membreId.toString());
        await _storage.write(key: 'user_role', value: role.toString());
        if (token.isNotEmpty) {
          await _storage.write(key: 'auth_token', value: token);
        }

        await authNotifier.checkAuthStatus();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Connexion réussie !"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );

        context.go('/dashboard', extra: {
          'membre_id': int.parse(membreId.toString()),
          'role': role,
        });
      } else {
        setState(() {
          _errorMessage = "Identifiants incorrects ou erreur serveur.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur de connexion : $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;

    return Scaffold(
      appBar: AppBar(
        title: Text("app_title".tr(context: context), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A529B),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          _buildLanguageMenu(context, currentLocale, Colors.white),
        ],
      ),
      body: Stack(
        children: [
          _buildLoginInterface(context),
          if (_showOnboarding) _buildOnboardingOverlay(context, currentLocale),
        ],
      ),
    );
  }

  Widget _buildLanguageMenu(BuildContext context, Locale currentLocale, Color iconColor) {
    return PopupMenuButton<Locale>(
      icon: Icon(Icons.language, color: iconColor),
      tooltip: 'language_label'.tr(context: context),
      position: PopupMenuPosition.under,
      onSelected: (Locale locale) async {
        await context.setLocale(locale);
        if (mounted) {
          setState(() {});
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<Locale>>[
        PopupMenuItem<Locale>(
          value: const Locale('fr'),
          child: Row(
            children: [
              const Text('🇫🇷 '),
              Text('Français', style: TextStyle(fontWeight: currentLocale.languageCode == 'fr' ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
        PopupMenuItem<Locale>(
          value: const Locale('rn'),
          child: Row(
            children: [
              const Text('🇧🇮 '),
              Text('Kirundi', style: TextStyle(fontWeight: currentLocale.languageCode == 'rn' ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginInterface(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF1A529B),
            child: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(icon: const Icon(Icons.lock), text: "secure_login".tr(context: context)),
                Tab(icon: const Icon(Icons.person_add), text: "become_member".tr(context: context)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.account_balance, size: 80, color: Color(0xFF1A529B)),
                          const SizedBox(height: 30),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.phone),
                              labelText: "phone_identifier".tr(context: context),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _pinController,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock),
                              labelText: "pin_code".tr(context: context),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: 4),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: const Color(0xFF1A529B),
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text("access_system".tr(context: context)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const InscriptionScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingOverlay(BuildContext context, Locale currentLocale) {
    return Container(
      color: Colors.black.withOpacity(0.65),
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 24.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 10,
          child: Container(
            height: 480,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildLanguageMenu(context, currentLocale, const Color(0xFF1A529B)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showOnboarding = false;
                        });
                      },
                      child: Text("skip".tr(context: context), style: const TextStyle(color: Color(0xFF1A529B), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _onboardingData.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final page = _onboardingData[index];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (page["title"] != null && page["title"]!.isNotEmpty) ...[
                            Text(
                              page["title"]!.tr(context: context),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A529B),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text(
                            page["subtitle"]!.tr(context: context),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            page["description"]!.tr(context: context),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _onboardingData.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      width: _currentPage == index ? 24.0 : 8.0,
                      height: 8.0,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? const Color(0xFF1A529B) : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _onboardingData.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      setState(() {
                        _showOnboarding = false;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: const Color(0xFF1A529B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    _currentPage == _onboardingData.length - 1
                        ? "start".tr(context: context)
                        : "next".tr(context: context),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}