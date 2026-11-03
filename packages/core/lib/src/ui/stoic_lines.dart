/// Public-domain lines shown as chrome. They are not journal entries.
class StoicLine {
  const StoicLine({
    required this.quote,
    required this.author,
    required this.source,
  });

  final String quote;
  final String author;
  final String source;
}

const List<StoicLine> kDailyStoicLines = <StoicLine>[
  StoicLine(
    quote: 'We suffer more often in imagination than in reality.',
    author: 'Seneca',
    source: 'Letters from a Stoic',
  ),
  StoicLine(
    quote: 'Some things are within our power, while others are not.',
    author: 'Epictetus',
    source: 'Enchiridion',
  ),
  StoicLine(
    quote: 'You have power over your mind, not outside events.',
    author: 'Marcus Aurelius',
    source: 'Meditations',
  ),
  StoicLine(
    quote: 'He who fears death will never do anything worthy of a living man.',
    author: 'Seneca',
    source: 'Letters from a Stoic',
  ),
  StoicLine(
    quote:
        'Make the best use of what is in your power, and take the rest as it happens.',
    author: 'Epictetus',
    source: 'Discourses',
  ),
  StoicLine(
    quote:
        'The impediment to action advances action. What stands in the way becomes the way.',
    author: 'Marcus Aurelius',
    source: 'Meditations',
  ),
  StoicLine(
    quote: 'Difficulties strengthen the mind, as labor does the body.',
    author: 'Seneca',
    source: 'Letters from a Stoic',
  ),
  StoicLine(
    quote: 'No person is free who is not master of himself.',
    author: 'Epictetus',
    source: 'Discourses',
  ),
];

StoicLine stoicLineForDay(DateTime day) {
  final int index = day.difference(DateTime(day.year)).inDays;
  final int safe = index < 0 ? 0 : index;
  return kDailyStoicLines[safe % kDailyStoicLines.length];
}
