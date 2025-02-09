// Aggiungiamo l'importazione necessaria per ArgParser e ArgResults
import 'package:args/args.dart';
import 'package:build_cli_annotations/build_cli_annotations.dart';
// Modifichiamo il percorso di importazione per essere più flessibile
import './target_os_type.dart';

// Questo file è generato automaticamente dal builder
part 'options.g.dart';

/// Options of the Install command.
/// Questa classe definisce le opzioni accettate dal comando di installazione.
@CliOptions()
class Options {
  /// Target OS type, determines binaries to load.
  /// Questo campo determina per quale sistema operativo verranno caricati i binari.
  @CliOption(
      help: 'The target OS to install binaries for.',
      abbr: 't',
      // Aggiungiamo allowed per definire i valori permessi
      allowed: ['linux', 'windows']
  )
  TargetOsType? targetOsType;

  // Aggiungiamo un costruttore di default
  Options();
}

/// Ottiene la stringa di usage per il parser.
/// Questa proprietà è generata automaticamente dal builder CLI.
String get usage => _$parserForOptions.usage;

/// Popola un parser con le opzioni generate.
/// Questa funzione è utilizzata internamente dal builder CLI.
/// [p] è il parser da popolare con le opzioni.
ArgParser populateOptionsParser(ArgParser p) => _$populateOptionsParser(p);

/// Parse le opzioni dai risultati dell'analisi degli argomenti.
/// [results] contiene i risultati dell'analisi degli argomenti da linea di comando.
Options parseOptionsResult(ArgResults results) => _$parseOptionsResult(results);