import 'package:flutter/material.dart';

class HeaderBar extends StatelessWidget {
  final VoidCallback? onMenuPressed;
  final VoidCallback? onOpenFolderPressed;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onProfilePressed;

  const HeaderBar({
    super.key,
    this.onMenuPressed,
    this.onOpenFolderPressed,
    this.onSearchPressed,
    this.onProfilePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: const Color(0xFF030303),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            // Hamburger menu
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 22),
              onPressed: onMenuPressed,
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),

            // YouTube Music style logo
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF0000),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Music',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // White pill button (matching "Abrir app" from screenshot)
            GestureDetector(
              onTap: onOpenFolderPressed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Abrir app',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Search button
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white, size: 20),
              onPressed: onSearchPressed,
              splashRadius: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 6),

            // User avatar
            GestureDetector(
              onTap: onProfilePressed,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD48B38),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: const Center(
                  child: Text(
                    'Y',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
