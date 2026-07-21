import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      "subtitle": "Solutions Financières Intelligentes",
      "description": "Maximisez vos rendements et atteignez vos objectifs financiers grâce à notre accompagnement expert.",
    },
    {
      "title": "Planification Financière",
      "subtitle": "Gestion et Investissement",
      "description": "Nous vous aidons à bâtir un portefeuille diversifié qui s'aligne sur vos objectifs financiers et votre tolérance au risque.",
    },
    {
      "title": "Consolidation & Fiscalité",
      "subtitle": "Simplifiez vos finances",
      "description": "Réduisez votre charge de dette et minimisez vos obligations fiscales avec nos stratégies expertes.",
    },
    {
      "title": "Vers le Succès Financier",
      "subtitle": "Guider Votre Avenir",
      "description": "Nous croyons que chacun mérite la sécurité financière et la paix d'esprit pour bâtir un avenir meilleur.",
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Image d'arrière-plan sur tout l'écran
          Positioned.fill(
            child: Image.asset(
              'assets/images/logo_2.png',
              fit: BoxFit.cover,
            ),
          ),

          // 2. Voile semi-transparent pour assurer la lisibilité du texte
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.85),
            ),
          ),

          // 3. Contenu de l'application par-dessus
          SafeArea(
            child: Column(
              children: [
                // Bouton Passer (Skip) en haut à droite
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_currentPage < _pages.length - 1)
                        TextButton(
                          onPressed: () {
                            _pageController.animateToPage(
                              _pages.length - 1,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: const Text(
                            "Passer",
                            style: TextStyle(color: Color(0xFF1A56A3), fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                // Carrousel des pages
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            if (page["title"] != null && page["title"]!.isNotEmpty) ...[
                              Text(
                                page["title"]!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A56A3),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Text(
                              page["subtitle"] ?? "",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              page["description"] ?? "",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black54,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Indicateurs de page (Points)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      width: _currentPage == index ? 24.0 : 8.0,
                      height: 8.0,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? const Color(0xFF1A56A3) : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Bouton Suivant / Commencer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        // Redirection vers l'écran de connexion / inscription
                        context.go('/login');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      backgroundColor: const Color(0xFF1A56A3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1 ? "Commencer" : "Suivant",
                      style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}