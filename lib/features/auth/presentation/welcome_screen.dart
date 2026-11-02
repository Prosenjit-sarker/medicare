import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medicare_bd/app/theme.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimary, kTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.16),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.32)),
                      ),
                      child: const Icon(Icons.health_and_safety_outlined, size: 62, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'MediCare BD',
                      style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your health, closer every day.',
                      style: TextStyle(color: Color.fromRGBO(255, 255, 255, 0.86), fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Care that fits your life',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find doctors and manage your care in one place.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Get started'),
                    style: FilledButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
