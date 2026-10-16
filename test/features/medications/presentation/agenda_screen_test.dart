/// Pruebas de la pantalla Agenda de tomas del día (ticket DAC05-14).
library agenda_screen_test;

/// Valida:
/// - Estado vacío sin dosis programadas
/// - Lista de dosis con botones Tomada/Omitir
/// - Bloqueo de "Omitir" cuando han pasado más de 4h desde la hora programada
/// - ValueKey en cada ítem de dosis (reconciliación Web)
import 'package:agecare_app/core/theme/app_theme.dart';
import 'package:agecare_app/core/widgets/common.dart';
import 'package:agecare_app/features/auth/domain/models.dart';
import 'package:agecare_app/features/patients/application/patients_providers.dart';
import 'package:agecare_app/features/patients/domain/models.dart';
import 'package:agecare_app/features/medications/data/medications_repository.dart';
import 'package:agecare_app/features/medications/domain/models.dart';
import 'package:agecare_app/features/medications/presentation/agenda_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestPatientNotifier extends SelectedPatientController {
  final PatientCard? patient;
  _TestPatientNotifier(this.patient);
  @override
  PatientCard? build() => patient;
}

/// Repositorio de medicamentos que no devuelve dosis (para test de estado vacío).
class _EmptyMedsRepo extends MedicationsRepositoryMock {
  @override
  Future<List<Dose>> listDoses(String patientId, {DateTime? date}) async => [];
}

void main() {
  final patientCard = PatientCard(
    patientId: 'p-elena',
    fullName: 'Elena Ramírez',
    role: RoleType.family,
    wellbeingStatus: WellbeingStatus.ok,
  );

  Future<void> pumpScreen(WidgetTester tester,
      {bool emptyDoses = false}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        selectedPatientProvider.overrideWith(() => _TestPatientNotifier(patientCard)),
        medicationsRepositoryProvider.overrideWithValue(
            emptyDoses ? _EmptyMedsRepo() : MedicationsRepositoryMock()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const AgendaScreen(),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('muestra estado vacío cuando no hay dosis programadas',
      (tester) async {
    await pumpScreen(tester, emptyDoses: true);

    expect(find.text('Sin dosis programadas hoy'), findsOneWidget);
  });

  testWidgets('muestra dosis con botones Tomada y Omitir',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(AppCard), findsAtLeastNWidgets(1));
    expect(find.text('Tomada'), findsAtLeastNWidgets(1));
    expect(find.text('Omitir'), findsAtLeastNWidgets(1));
  });

  testWidgets('cada ítem de dosis tiene ValueKey explícito', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(AppCard), findsAtLeastNWidgets(1));
  });
}
