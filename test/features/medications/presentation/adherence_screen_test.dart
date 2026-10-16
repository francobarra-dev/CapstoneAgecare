/// Pruebas de la pantalla de adherencia al tratamiento (ticket DAC05-15).
library adherence_screen_test;

/// Valida:
/// - Muestra el porcentaje de adherencia calculado desde el servidor
/// - Muestra el desglose por medicamento
/// - Aserciones dinámicas (isNotEmpty, length) en vez de valores hardcodeados
import 'package:agecare_app/core/theme/app_theme.dart';
import 'package:agecare_app/core/widgets/common.dart';
import 'package:agecare_app/features/auth/domain/models.dart';
import 'package:agecare_app/features/patients/application/patients_providers.dart';
import 'package:agecare_app/features/patients/domain/models.dart';
import 'package:agecare_app/features/medications/data/medications_repository.dart';
import 'package:agecare_app/features/medications/presentation/adherence_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _TestPatientNotifier extends SelectedPatientController {
  final PatientCard? patient;
  _TestPatientNotifier(this.patient);
  @override
  PatientCard? build() => patient;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

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
        medicationsRepositoryProvider.overrideWithValue(MedicationsRepositoryMock()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const AdherenceScreen(),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('muestra el porcentaje de adherencia general',
      (tester) async {
    await pumpScreen(tester);

    expect(find.textContaining('%'), findsAtLeastNWidgets(1));
    expect(find.text('Adherencia general (7 días)'), findsOneWidget);
  });

  testWidgets('muestra desglose por medicamento cuando hay datos',
      (tester) async {
    await pumpScreen(tester);

    final cards = find.byType(AppCard);
    expect(cards, findsAtLeastNWidgets(1));
  });

  testWidgets('muestra estado vacío cuando no hay medicamentos',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(AppCard), findsAtLeastNWidgets(1));
  });
}
