import 'package:flutter/material.dart';
import 'inicio.dart';
import 'bibliotecas.dart';
import 'buscar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final PageController _pageController = PageController(initialPage: 1); // Start at Inicio

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(), // Prevent overscroll bounce for a cleaner feel
        children: [
          // Page 0: Library
          LibraryPage(
            onBackTap: () => _navigateToPage(1),
          ),
          
          // Page 1: Home (Inicio)
          Inicio(
            onSearchTap: () => _navigateToPage(2),
            onLibraryTap: () => _navigateToPage(0),
          ),
          
          // Page 2: Search (Buscar)
          BuscarPage(
            onBackTap: () => _navigateToPage(1),
          ),
        ],
      ),
    );
  }
}
