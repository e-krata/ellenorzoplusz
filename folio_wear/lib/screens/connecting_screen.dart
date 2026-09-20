import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wear_data_provider.dart';

class ConnectingScreen extends StatelessWidget {
  const ConnectingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32.0,
                height: 32.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: cs.primary,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              const SizedBox(height: 18.0),
              const Text(
                'eFolio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                'Csatlakozás a telefonhoz...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11.0,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22.0),
              GestureDetector(
                onTap: () =>
                    context.read<WearDataProvider>().requestSync(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22.0, vertical: 9.0),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  child: Text(
                    'Újrapróbálás',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
