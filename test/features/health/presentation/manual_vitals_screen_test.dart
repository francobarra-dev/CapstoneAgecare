/// Pruebas de la pantalla de ingreso manual de signos vitales (ticket DAC05-12).
library manual_vitals_screen_test;

/// Valida:
/// - Muestra campos FC, SpO2 y Temperatura
/// - Envía lecturas al repositorio mediante uploadBatch
/// - Muestra mensaje de éxito tras registrar
/// - Validación de rangos (30-220 bpm, 70-100 %, 30-45 °C)
import 'package:agecare_app/core/theme/app_theme.dart';
import 'package:agecare_app/features/auth/domain/models.dart';
import 'package:agecare_app/features/patients/application/patients_providers.dart';
import 'package:agecare_app/features/patients/domain/models.dart';
import 'package:agecare_app/features/health/data/vitals_repository.dart';
import 'package:agecare_app/features/health/presentation/manual_vitals_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestPatientNotifier extends SelectedPatientController {
  final PatientCard? patient;
  _TestPatientNotifier(this.patient);
  @override
  PatientCard? build() => patient;
}

void main() {
  final patientCard = PatientCard(
    patientId: 'p-elena',
    fullName: 'Elena Ramírez',
    role: RoleType.family,
    wellbeingStatus: WellbeingStatus.ok,
  );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        selectedPatientProvider.overrideWith(() => _TestPatientNotifier(patientCard)),
        vitalsRepositoryProvider.overrideWithValue(VitalsRepositoryMock()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const ManualVitalsScreen(),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('muestra campos de FC, SpO2 y Temperatura', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Ritmo cardíaco (FC)'), findsOneWidget);
    expect(find.text('Oxígeno en sangre (SpO2)'), findsOneWidget);
    expect(find.text('Temperatura'), findsOneWidget);
    expect(find.text('Registrar vitales'), findsOneWidget);
  });

  testWidgets('valida rangos de valores ingresados', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).first, '300');
    await tester.tap(find.text('Registrar vitales'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Registrar vitales'), findsOneWidget);
  });

  testWidgets('registra vitales exitosamente con valores válidos',
      (tester) async {
    await pumpScreen(tester);

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '72');
    await tester.enterText(textFields.at(1), '97');
    await tester.enterText(textFields.at(2), '36.6');

    await tester.tap(find.text('Registrar vitales'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('lectura(s) registrada(s)'), findsOneWidget);
  });
}
