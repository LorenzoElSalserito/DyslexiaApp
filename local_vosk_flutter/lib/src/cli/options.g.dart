// GENERATED CODE - DO NOT MODIFY BY HAND
// Questo file è generato automaticamente da build_runner

part of 'options.dart';

// **************************************************************************
// CliGenerator
// **************************************************************************

/// Helper function per convertire valori di enumerazione.
/// Questa funzione cerca il valore dell'enumerazione corrispondente alla stringa fornita.
T _$enumValueHelper<T>(Map<T, String> enumValues, String source) =>
    enumValues.entries
        .singleWhere(
          (e) => e.value == source,
      orElse: () => throw ArgumentError(
        '`$source` is not one of the supported values: '
            '${enumValues.values.join(', ')}',
      ),
    )
        .key;

/// Helper function per gestire valori di enumerazione nullable.
/// Questa funzione gestisce il caso in cui il valore di origine potrebbe essere null.
T? _$nullableEnumValueHelperNullable<T>(
    Map<T, String> enumValues,
    String? source,
    ) =>
    source == null ? null : _$enumValueHelper(enumValues, source);

/// Funzione per parsare i risultati delle opzioni.
/// Crea una nuova istanza di Options con i valori parsati.
Options _$parseOptionsResult(ArgResults result) => Options()
  ..targetOsType = _$nullableEnumValueHelperNullable(
    _$TargetOsTypeEnumMapBuildCli,
    result['target-os-type'] as String?,
  );

/// Mappa di conversione tra TargetOsType e stringhe.
/// Definisce la corrispondenza tra i valori dell'enum e le loro rappresentazioni testuali.
const _$TargetOsTypeEnumMapBuildCli = <TargetOsType, String>{
  TargetOsType.linux: 'linux',
  TargetOsType.windows: 'windows'
};

/// Popola un parser con le opzioni necessarie.
/// Configura il parser con tutte le opzioni supportate dal comando.
ArgParser _$populateOptionsParser(ArgParser parser) => parser
  ..addOption(
    'target-os-type',
    abbr: 't',
    help: 'The target OS to install binaries for.',
    allowed: ['linux', 'windows'],
  );

/// Parser predefinito con tutte le opzioni configurate.
final _$parserForOptions = _$populateOptionsParser(ArgParser());

/// Funzione di utilità per parsare gli argomenti da linea di comando.
/// [args] sono gli argomenti da linea di comando da parsare.
Options parseOptions(List<String> args) {
  try {
    final result = _$parserForOptions.parse(args);
    return _$parseOptionsResult(result);
  } catch (e) {
    // Aggiungiamo una gestione degli errori più robusta
    throw FormatException(
      'Error parsing command line arguments: ${e.toString()}\n'
          'Usage: ${_$parserForOptions.usage}',
    );
  }
}