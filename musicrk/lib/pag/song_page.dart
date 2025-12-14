import 'package:flutter/material.dart';

class SongPage extends StatelessWidget {
  const SongPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ------------------------- TOP BAR -----------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Botón atrás
                  _circleButton(Icons.arrow_back),

                  const Text(
                    "Now Playing",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  // Favorito
                  _circleButton(Icons.favorite_border),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ------------------------- IMAGEN REDONDA -----------------------------
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: AssetImage("https://images.unsplash.com/photo-1506157786151-b8491531f063?auto=format&fit=crop&w=800&q=60"), 
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 25),

            // ------------------------- TÍTULO -----------------------------
            const Text(
              "Starlit Reverie",
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            // ------------------------- ARTISTA -----------------------------
            const Text(
              "Budiarti x Lil magrib",
              style: TextStyle(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),

            const SizedBox(height: 20),

            // ------------------------- LETRA (OPACIDAD DESDE ARRIBA) -----------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: const [
                  Text(
                    "Whispers in the midnight breeze,",
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Carrying dreams across the seas,",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    "I close my eyes, let go, and drift away...",
                    style: TextStyle(color: Colors.white30, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ------------------------- SLIDER + TIEMPOS -----------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                children: [
                  Slider(
                    value: 0.3,
                    onChanged: (v) {},
                    activeColor: Colors.greenAccent,
                    inactiveColor: Colors.white24,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "0:28",
                        style: TextStyle(color: Colors.white54),
                      ),
                      Text(
                        "-2:15",
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ------------------------- CONTROLES -----------------------------
            Padding(
              padding: const EdgeInsets.only(bottom: 25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _iconButton(Icons.skip_previous),
                  const SizedBox(width: 20),

                  // PLAY grande
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pause,
                      size: 32,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(width: 20),
                  _iconButton(Icons.skip_next),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Botón redondo pequeño (back - fav)
  Widget _circleButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white12,
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  // Botones pequeños (prev - next)
  Widget _iconButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white12,
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}
