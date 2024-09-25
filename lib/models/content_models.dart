import 'dart:math';

class Word {
  final String text;
  final int crystalValue;

  Word(this.text) : crystalValue = text.length;
}

class Sentence {
  final List<Word> words;
  final int crystalValue;

  Sentence(this.words) : crystalValue = words.fold(0, (sum, word) => sum + word.crystalValue);
}

class Paragraph {
  final List<Sentence> sentences;
  final int crystalValue;

  Paragraph(this.sentences) : crystalValue = sentences.fold(0, (sum, sentence) => sum + sentence.crystalValue);
}

class Page {
  final List<Paragraph> paragraphs;
  final int crystalValue;

  Page(this.paragraphs) : crystalValue = paragraphs.fold(0, (sum, paragraph) => sum + paragraph.crystalValue);
}

class ContentSet {
  final List<Word> dictionary;
  final List<Sentence> sentences;
  final List<Paragraph> paragraphs;
  final List<Page> pages;

  ContentSet({
    required this.dictionary,
    required this.sentences,
    required this.paragraphs,
    required this.pages,
  });

  Word getRandomWord() {
    final random = Random();
    return dictionary[random.nextInt(dictionary.length)];
  }

  Sentence getRandomSentence() {
    final random = Random();
    return sentences[random.nextInt(sentences.length)];
  }

  Paragraph getRandomParagraph() {
    final random = Random();
    return paragraphs[random.nextInt(paragraphs.length)];
  }

  Page getRandomPage() {
    final random = Random();
    return pages[random.nextInt(pages.length)];
  }
}