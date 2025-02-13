/// Classe che implementa algoritmi specializzati per il calcolo della similarità
/// tra testi, ottimizzata per le particolari esigenze degli utenti con dislessia.
class TextSimilarity {
  /// Coppie di lettere che vengono spesso confuse nella dislessia.
  /// Questa mappa aiuta a gestire gli errori più comuni in modo più tollerante.
  static const Map<String, List<String>> _commonConfusions = {
    'b': ['d', 'p'],  // Confusione tra b/d/p
    'd': ['b', 'q'],  // Confusione tra d/b/q
    'p': ['q', 'b'],  // Confusione tra p/q/b
    'q': ['p', 'd'],  // Confusione tra q/p/d
    'm': ['n', 'w'],  // Confusione tra m/n/w
    'n': ['m'],       // Confusione tra n/m
    'a': ['e'],       // Confusione tra a/e
    'e': ['a'],       // Confusione tra e/a
    's': ['z'],       // Confusione tra s/z
    'z': ['s'],       // Confusione tra z/s
    'f': ['v'],       // Confusione tra f/v
    'v': ['f'],       // Confusione tra v/f
    'l': ['i'],       // Confusione tra l/i
    'i': ['l'],       // Confusione tra i/l
  };

  /// Sequenze di lettere che spesso causano difficoltà nella lettura
  static const List<String> _commonSequenceErrors = [
    'chi', 'che',     // Suoni chi/che
    'ghi', 'ghe',     // Suoni ghi/ghe
    'gn',             // Suono gn
    'gl',             // Suono gl
    'sc'              // Suono sc
  ];

  /// Calcola la similarità tra il testo riconosciuto e il target.
  /// Utilizza un approccio combinato che considera vari aspetti della lettura.
  static double calculateSimilarity(String recognized, String target) {
    // Normalizza i testi prima del confronto
    final normalizedRecognized = _normalizeText(recognized);
    final normalizedTarget = _normalizeText(target);

    // Calcola diverse metriche di similarità
    double phoneticalSim = _calculatePhoneticSimilarity(
        normalizedRecognized,
        normalizedTarget
    );

    double levenshteinSim = _calculateLevenshteinSimilarity(
        normalizedRecognized,
        normalizedTarget,
        considerConfusions: true
    );

    double sequenceSim = _calculateSequenceSimilarity(
        normalizedRecognized,
        normalizedTarget
    );

    // Pesi per le diverse metriche
    const double PHONETIC_WEIGHT = 0.4;    // 40% similarità fonetica
    const double LEVENSHTEIN_WEIGHT = 0.4;  // 40% similarità di editing
    const double SEQUENCE_WEIGHT = 0.2;     // 20% similarità di sequenza

    // Combina le metriche con i loro pesi
    return (phoneticalSim * PHONETIC_WEIGHT) +
        (levenshteinSim * LEVENSHTEIN_WEIGHT) +
        (sequenceSim * SEQUENCE_WEIGHT);
  }

  /// Normalizza il testo rimuovendo punteggiatura e uniformando gli spazi
  static String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Rimuove punteggiatura
        .replaceAll(RegExp(r'\s+'), ' ')    // Normalizza spazi
        .trim();
  }

  /// Calcola la similarità fonetica tra due testi
  static double _calculatePhoneticSimilarity(String s1, String s2) {
    // Converte i testi in codici fonetici
    String phonetic1 = _getPhoneticCode(s1);
    String phonetic2 = _getPhoneticCode(s2);

    // Calcola la similarità tra i codici fonetici
    return _calculateLevenshteinSimilarity(phonetic1, phonetic2, considerConfusions: false);
  }

  /// Converte il testo in una rappresentazione fonetica semplificata
  static String _getPhoneticCode(String text) {
    String result = text.toLowerCase();

    // Applica le regole fonetiche italiane
    result = result
        .replaceAll('chi', 'ki')
        .replaceAll('che', 'ke')
        .replaceAll('ghi', 'gi')
        .replaceAll('ghe', 'ge')
        .replaceAll('gn', 'ñ')
        .replaceAll('gl', 'ʎ')
        .replaceAll('sc', 'ʃ');

    return result;
  }

  /// Calcola la similarità usando una versione modificata della distanza di Levenshtein
  static double _calculateLevenshteinSimilarity(
      String s1,
      String s2, {
        bool considerConfusions = true
      }) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // Matrice per la programmazione dinamica
    List<List<int>> matrix = List.generate(
        s1.length + 1,
            (i) => List.generate(s2.length + 1, (j) => j == 0 ? i : 0)
    );

    // Inizializza la prima riga
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    // Calcola la distanza di Levenshtein
    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = _calculateSubstitutionCost(
            s1[i - 1],
            s2[j - 1],
            considerConfusions
        );

        matrix[i][j] = [
          matrix[i - 1][j] + 1,                    // deletion
          matrix[i][j - 1] + 1,                    // insertion
          matrix[i - 1][j - 1] + cost,            // substitution
        ].reduce((curr, next) => curr < next ? curr : next);

        // Gestione delle trasposizioni
        if (i > 1 && j > 1 &&
            s1[i - 1] == s2[j - 2] &&
            s1[i - 2] == s2[j - 1]) {
          matrix[i][j] = [
            matrix[i][j],
            matrix[i - 2][j - 2] + 1  // transposition
          ].reduce((curr, next) => curr < next ? curr : next);
        }
      }
    }

    // Calcola la similarità normalizzata
    int maxLength = s1.length > s2.length ? s1.length : s2.length;
    return 1.0 - (matrix[s1.length][s2.length] / maxLength);
  }

  /// Calcola il costo di sostituzione tra due caratteri
  static int _calculateSubstitutionCost(
      String char1,
      String char2,
      bool considerConfusions
      ) {
    if (char1 == char2) return 0;
    if (!considerConfusions) return 2;

    // Verifica se le lettere sono comunemente confuse
    if (_commonConfusions.containsKey(char1) &&
        _commonConfusions[char1]!.contains(char2)) {
      return 1;  // Costo ridotto per errori comuni
    }

    return 2;  // Costo standard per altre sostituzioni
  }

  /// Calcola la similarità basata sulle sequenze di caratteri
  static double _calculateSequenceSimilarity(String s1, String s2) {
    double totalScore = 0;
    double maxScore = _commonSequenceErrors.length.toDouble();

    for (String sequence in _commonSequenceErrors) {
      bool inS1 = s1.contains(sequence);
      bool inS2 = s2.contains(sequence);

      if (inS1 == inS2) {
        totalScore += 1;
      }
    }

    return totalScore / maxScore;
  }

  /// Fornisce feedback specifici basati sul tipo di errori
  static String getDetailedFeedback(String recognized, String target) {
    List<String> feedback = [];

    // Analizza diversi tipi di errori
    if (_hasLetterInversions(recognized, target)) {
      feedback.add("Attenzione alle inversioni di lettere");
    }

    var confusions = _findCommonConfusions(recognized, target);
    if (confusions.isNotEmpty) {
      feedback.add("Fai attenzione a distinguere: ${confusions.join(', ')}");
    }

    if (_hasSequenceErrors(recognized, target)) {
      feedback.add("Controlla le combinazioni di lettere");
    }

    return feedback.isEmpty
        ? "Continua così!"
        : feedback.join(". ");
  }

  /// Verifica la presenza di inversioni di lettere
  static bool _hasLetterInversions(String s1, String s2) {
    for (int i = 0; i < s1.length - 1; i++) {
      if (i < s2.length - 1 &&
          s1[i] == s2[i + 1] &&
          s1[i + 1] == s2[i]) {
        return true;
      }
    }
    return false;
  }

  /// Trova le confusioni di lettere comuni nel testo
  static Set<String> _findCommonConfusions(String s1, String s2) {
    Set<String> confusions = {};

    for (int i = 0; i < s1.length; i++) {
      if (i < s2.length &&
          _commonConfusions.containsKey(s1[i]) &&
          _commonConfusions[s1[i]]!.contains(s2[i])) {
        confusions.add("${s1[i]}-${s2[i]}");
      }
    }

    return confusions;
  }

  /// Verifica la presenza di errori nelle sequenze comuni
  static bool _hasSequenceErrors(String s1, String s2) {
    for (String sequence in _commonSequenceErrors) {
      if (s1.contains(sequence) != s2.contains(sequence)) {
        return true;
      }
    }
    return false;
  }
}