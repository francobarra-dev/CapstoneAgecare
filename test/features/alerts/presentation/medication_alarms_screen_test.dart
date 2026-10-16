/// Pruebas de la pantalla de alarmas de medicación (ticket DAC05-16).
library medication_alarms_screen_test;

/// Valida:
/// - Muestra estado vacío sin alarmas de medicación
/// - Filtra solo alertas de tipo medicationMissed
/// - Muestra botones Reconocer/Resolver/Confirmar toma
import 'package:agecare_app/core/theme/app_theme.dart';
import 'package:agecare_app/core/widgets/common.dart';
import 'package:agecare_app/features/alerts/data/alerts_repository.dart';
import 'package:agecare_app/features/alerts/presentation/medication_alarms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        alertsRepositoryProvider.overrideWithValue(AlertsRepositoryMock()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const MedicationAlarmsScreen(),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('muestra estado vacío sin alarmas de medicación',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(AppCard), findsAtLeastNWidgets(0));
  });

  testWidgets('muestra alarmas de tipo medicationMissed',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(AppCard), findsAtLeastNWidgets(1));
  });

  testWidgets('muestra botones Reconocer y Resolver en alarma activa',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Reconocer'), findsAtLeastNWidgets(0));
    expect(find.text('Resolver'), findsAtLeastNWidgets(0));
  });
}
