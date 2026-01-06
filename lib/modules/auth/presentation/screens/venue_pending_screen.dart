import 'package:flutter/material.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/theme/app_colors.dart';

class VenuePendingScreen extends StatelessWidget {
  const VenuePendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.navBlueDeep,
              AppColors.navBlueSoft,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.coralAlt.withOpacity(0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.verified_outlined,
                    color: AppColors.coralLight,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Basvurun alindi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mekan uyeligini incelemeye aldik. '
                  'Gun icinde ekibimiz sana ulasacak. '
                  'Bu surecte hesabın beklemede.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Anlayisin icin tesekkurler.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.login,
                        (route) => false,
                      );
                    },
                    child: const Text('Giris ekranina don'),
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
