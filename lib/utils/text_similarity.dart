// text_similarity.dart

class TextSimilarity {
  /// Coppie di lettere comunemente confuse nella dislessia
  static const Map<String, List<String>> _commonConfusions = {
    'b': ['d', 'p'],
    'd': ['b', 'q'],
    'p': ['q', 'b'],
    'q': ['p', 'd'],
    'm': ['n', 'w'],
    'n': ['m'],
    'a': ['e'],
    'e': ['a'],
    's': ['z'],
    'z': ['s'],
    'f': ['v'],
    'v': ['f'],
    'l': ['i'],
    'i': ['l'],
  };

  /// Errori comuni di sequenza
  static const List<String> _commonSequenceErrors = [
    'chi', 'che', 'ghi', 'ghe',
    'gn', 'gl', 'sc'
  ];

  /// Calcola la similarità tra il testo riconosciuto e il target
  static double calculateSimilarity(String recognized, String target) {
    // Normalizza i testi prima del confronto
    final normalizedRecognized = _normalizeText(recognized);
    final normalizedTarget = _normalizeText(target);

    // Combina diverse metriche per un risultato più accurato
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
    const double PHONETIC_WEIGHT = 0.4;
    const double LEVENSHTEIN_WEIGHT = 0.4;
    const double SEQUENCE_WEIGHT = 0.2;

    return (phoneticalSim * PHONETIC_WEIGHT) +
        (levenshteinSim * LEVENSHTEIN_WEIGHT) +
        (sequenceSim * SEQUENCE_WEIGHT);
  }

  /// Normalizza il testo per gestire errori comuni della dislessia
  static String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Rimuove punteggiatura
        .replaceAll(RegExp(r'\s+'), ' ')    // Normalizza spazi
        .trim();
  }

  /// Calcola la similarità fonetica
  static double _calculatePhoneticSimilarity(String s1, String s2) {
    // Implementa regole fonetiche italiane
    String phonetic1 = _getPhoneticCode(s1);
    String phonetic2 = _getPhoneticCode(s2);

    return _calculateLevenshteinSimilarity(phonetic1, phonetic2, considerConfusions: false);
  }

  /// Converte il testo in una rappresentazione fonetica semplificata
  static String _getPhoneticCode(String text) {
    String result = text.toLowerCase();

    // Regole fonetiche italiane
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

    List<List<int>> matrix = List.generate(
        s1.length + 1,
            (i) => List.generate(s2.length + 1, (j) => j == 0 ? i : 0)
    );

    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

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

        // Gestisce le trasposizioni (inversioni di lettere adiacenti)
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

    // Analizza inversioni di lettere
    if (_hasLetterInversions(recognized, target)) {
      feedback.add("Attenzione alle inversioni di lettere");
    }

    // Analizza confusioni comuni
    var confusions = _findCommonConfusions(recognized, target);
    if (confusions.isNotEmpty) {
      feedback.add("Fai attenzione a distinguere: ${confusions.join(', ')}");
    }

    // Analizza errori di sequenza
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

  /// Trova le confusioni di lettere comuni
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