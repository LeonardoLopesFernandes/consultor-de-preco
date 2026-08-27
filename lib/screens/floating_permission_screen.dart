import 'package:flutter/material.dart';
import '../utils/icons.dart';
import '../utils/overlay_service.dart';

/// Equivalente a io.amer.scanner.FloatingButtonPermissionActivity (UI em Flutter).
class FloatingPermissionScreen extends StatelessWidget {
  const FloatingPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFED0030),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcons.asset(AppIcons.cameraWhite, size: 80,
                      color: const Color(0xFFED0030)),
                  const SizedBox(height: 16),
                  const Text('Bolinha Flutuante',
                      style: TextStyle(
                          color: Color(0xFFED0030), fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Ative a bolinha para acessar o scanner rapidamente de qualquer aplicativo',
                    style: TextStyle(color: Color(0xFF666666)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(height: 1, color: const Color(0xFFE0E0E0),
                      margin: const EdgeInsets.symmetric(vertical: 20)),
                  const Text('📌 Como ativar:',
                      style: TextStyle(
                          color: Color(0xFF333333), fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Clique em \'Conceder Permissão\'\n2. Ative a opção \'Permitir sobrepor outros apps\'\n3. Volte e clique em \'Ativar Bolinha\'',
                    style: TextStyle(color: Color(0xFF666666), fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFED0030),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () => OverlayService.openPermission(),
                      child: const Text('Conceder Permissão', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFED0030),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () {
                        OverlayService.start();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bolinha flutuante ativada!')),
                        );
                        Navigator.pop(context);
                      },
                      child: const Text('Ativar Bolinha Flutuante', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '💡 Dica: Você pode arrastar a bolinha para qualquer lugar da tela',
                    style: TextStyle(color: Color(0xFF999999), fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
