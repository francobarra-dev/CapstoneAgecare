import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:health/health.dart';

import '../../features/health/data/vitals_repository.dart';
import '../../features/health/domain/models.dart';

/// Resultado de una sincronización con Health Connect.
class HealthSyncResult {
  const HealthSyncResult({required this.read, required this.accepted});

  /// Lecturas encontradas en Health Connect dentro de la ventana.
  final int read;

  /// Lecturas nuevas que guardó el backend (las repetidas se descartan allá).
  final int accepted;
}

/// Lee pulso y oxígeno desde Health Connect (Android) y los envía al backend.
///
/// Sirve para cualquier reloj cuya app escriba en Health Connect: Samsung,
/// Xiaomi, o Huawei a través de una app puente como Health Sync.
/// El backend descarta las lecturas repetidas, así que reenviar la misma
/// ventana es seguro.
class HealthConnectSync {
  HealthConnectSync(this._vitals);

  final VitalsRepository _vitals;
  final Health _health = Health();
  bool _configured = false;
  DateTime? _lastAutoSync;

  static const _storage = FlutterSecureStorage();
  static const _patientKey = 'health_connect_patient_id';
  static const _autoSyncMinInterval = Duration(minutes: 2);

  static const _types = [HealthDataType.HEART_RATE, HealthDataType.BLOOD_OXYGEN];
  static const _batchSize = 500; // máximo que acepta POST /vitals/batch

  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// true si Health Connect está instalado y disponible en el equipo.
  Future<bool> isAvailable() async {
    if (!isSupported) return false;
    await _configure();
    return await _health.getHealthConnectSdkStatus() == HealthConnectSdkStatus.sdkAvailable;
  }

  /// Abre la tienda para instalar o actualizar Health Connect.
  Future<void> installHealthConnect() async {
    await _configure();
    await _health.installHealthConnect();
  }

  /// Pide permiso de lectura (muestra el diálogo de Health Connect si falta).
  Future<bool> requestPermissions() async {
    await _configure();
    final access = List.filled(_types.length, HealthDataAccess.READ);
    final has = await _health.hasPermissions(_types, permissions: access) ?? false;
    if (has) return true;
    return _health.requestAuthorization(_types, permissions: access);
  }

  /// Recuerda a qué paciente pertenece el reloj de este equipo, para que la
  /// sincronización automática sepa a quién enviar las lecturas.
  Future<void> rememberPatient(String patientId) =>
      _storage.write(key: _patientKey, value: patientId);

  /// Sincronización silenciosa al abrir la app o volver a ella.
  ///
  /// Solo corre si el usuario ya sincronizó una vez a mano en este equipo
  /// (paciente recordado y permiso concedido): nunca muestra diálogos.
  /// Devuelve null si no corresponde sincronizar.
  Future<HealthSyncResult?> autoSync() async {
    if (!isSupported) return null;
    final now = DateTime.now();
    if (_lastAutoSync != null && now.difference(_lastAutoSync!) < _autoSyncMinInterval) {
      return null;
    }
    _lastAutoSync = now;
    final patientId = await _storage.read(key: _patientKey);
    if (patientId == null || !await isAvailable()) return null;
    final access = List.filled(_types.length, HealthDataAccess.READ);
    if (!(await _health.hasPermissions(_types, permissions: access) ?? false)) return null;
    return sync(patientId);
  }

  /// Envía al paciente las lecturas de las últimas [window] horas.
  Future<HealthSyncResult> sync(String patientId, {Duration window = const Duration(hours: 24)}) async {
    await _configure();
    final now = DateTime.now();
    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: now.subtract(window),
      endTime: now,
    );
    final readings = _health
        .removeDuplicates(points)
        .map(_toReading)
        .whereType<VitalReading>()
        .toList();

    var accepted = 0;
    for (var i = 0; i < readings.length; i += _batchSize) {
      final end = (i + _batchSize).clamp(0, readings.length);
      accepted += await _vitals.uploadBatch(patientId, readings.sublist(i, end));
    }
    return HealthSyncResult(read: readings.length, accepted: accepted);
  }

  VitalReading? _toReading(HealthDataPoint p) {
    final v = p.value;
    if (v is! NumericHealthValue) return null;
    var value = v.numericValue.toDouble();
    final VitalType type;
    switch (p.type) {
      case HealthDataType.HEART_RATE:
        type = VitalType.heartRate;
      case HealthDataType.BLOOD_OXYGEN:
        type = VitalType.spo2;
        if (value <= 1) value *= 100; // algunas fuentes lo guardan como fracción
      default:
        return null;
    }
    return VitalReading(
      type: type,
      value: value,
      measuredAt: p.dateFrom,
      meta: {'origin': 'health_connect', 'source_app': p.sourceName},
    );
  }
}

final healthConnectSyncProvider = Provider<HealthConnectSync>(
    (ref) => HealthConnectSync(ref.watch(vitalsRepositoryProvider)));
