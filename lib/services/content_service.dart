import 'dart:math';
import '../models/content_models.dart';

class ContentService {
  late ContentSet _contentSet;
  final Random _random = Random();

  // Inizializza il servizio caricando i dati
  Future<void> initialize() async {
    // In un'app reale, qui caricheresti i dati da un file o da un database
    // Per ora, useremo dati di esempio
    _contentSet = await _loadMockData();
  }

  Future<ContentSet> _loadMockData() async {
    // Simula il caricamento dei dati con un ritardo
    await Future.delayed(Duration(seconds: 2));

    return ContentSet(
      dictionary: List.generate(1000, (index) => Word('parola$index')),
      sentences: List.generate(100, (index) =>
          Sentence(List.generate(5, (wordIndex) => Word('parola${index * 5 + wordIndex}')))),
      paragraphs: List.generate(50, (index) =>
          Paragraph(List.generate(3, (sentenceIndex) =>
              Sentence(List.generate(5, (wordIndex) => Word('parola${index * 15 + sentenceIndex * 5 + wordIndex}')))))),
      pages: List.generate(10, (index) =>
          Page(List.generate(5, (paragraphIndex) =>
              Paragraph(List.generate(3, (sentenceIndex) =>
                  Sentence(List.generate(5, (wordIndex) => Word('parola${index * 75 + paragraphIndex * 15 + sentenceIndex * 5 + wordIndex}')))))))),
    );
  }

  // Metodi per ottenere contenuti casuali per ciascun livello
  Word getRandomWordForLevel1() => _contentSet.getRandomWord();

  Sentence getRandomSentenceForLevel2() => _contentSet.getRandomSentence();

  Paragraph getRandomParagraphForLevel3() => _contentSet.getRandomParagraph();

  Page getRandomPageForLevel4() => _contentSet.getRandomPage();

  // Metodo per ottenere un set di parole per il Livello 1
  List<Word> getWordsForLevel1(int count) {
    return List.generate(count, (_) => getRandomWordForLevel1());
  }

  // Metodo per ottenere un set di frasi per il Livello 2
  List<Sentence> getSentencesForLevel2(int count) {
    return List.generate(count, (_) => getRandomSentenceForLevel2());
  }

  // Metodo per ottenere un set di paragrafi per il Livello 3
  List<Paragraph> getParagraphsForLevel3(int count) {
    return List.generate(count, (_) => getRandomParagraphForLevel3());
  }

  // Metodo per ottenere un set di pagine per il Livello 4
  List<Page> getPagesForLevel4(int count) {
    return List.generate(count, (_) => getRandomPageForLevel4());
  }

  // Metodo per calcolare il punteggio in cristalli per un dato contenuto
  int calculateCrystals(dynamic content) {
    if (content is Word) return content.crystalValue;
    if (content is Sentence) return content.crystalValue;
    if (content is Paragraph) return content.crystalValue;
    if (content is Page) return content.crystalValue;
    return 0;
  }
}