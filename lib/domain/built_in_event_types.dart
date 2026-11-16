import 'event_type.dart';

const _lasted = DurationQuestion(id: 'duration', label: 'How long it lasted');

/// The common pet medical events offered first, in the order shown.
///
/// Question and option ids are stored with events, so they never change and
/// are never reused; labels can change.
final List<EventType> builtInEventTypes = List.unmodifiable(const [
  EventType(
    id: 'vomiting',
    name: 'Vomiting',
    builtIn: true,
    questions: [
      ChoiceQuestion(
        id: 'what_came_up',
        label: 'What came up',
        options: [
          (id: 'food', label: 'Food'),
          (id: 'bile', label: 'Yellow liquid or bile'),
          (id: 'foam', label: 'Foam'),
          (id: 'hairball', label: 'Hairball'),
          (id: 'blood', label: 'Blood'),
          (id: 'something_else', label: 'Something else'),
        ],
      ),
    ],
  ),
  EventType(
    id: 'diarrhea',
    name: 'Diarrhea',
    builtIn: true,
    questions: [
      ChoiceQuestion(
        id: 'consistency',
        label: 'Consistency',
        options: [(id: 'soft', label: 'Soft'), (id: 'watery', label: 'Watery')],
      ),
      ChoiceQuestion(
        id: 'blood_seen',
        label: 'Blood seen',
        options: [(id: 'yes', label: 'Yes'), (id: 'no', label: 'No')],
      ),
    ],
  ),
  EventType(
    id: 'seizure',
    name: 'Seizure',
    builtIn: true,
    questions: [
      ChoiceQuestion(
        id: 'kind',
        label: 'Kind',
        options: [(id: 'focal', label: 'Focal'), (id: 'grand_mal', label: 'Grand mal')],
      ),
      _lasted,
    ],
  ),
  EventType(id: 'coughing', name: 'Coughing', builtIn: true, questions: [_lasted]),
  EventType(id: 'sneezing', name: 'Sneezing', builtIn: true),
  EventType(
    id: 'limping',
    name: 'Limping',
    builtIn: true,
    questions: [
      ChoiceQuestion(
        id: 'leg',
        label: 'Which leg',
        options: [
          (id: 'front_left', label: 'Front left'),
          (id: 'front_right', label: 'Front right'),
          (id: 'back_left', label: 'Back left'),
          (id: 'back_right', label: 'Back right'),
        ],
      ),
    ],
  ),
  EventType(
    id: 'not_eating',
    name: 'Not eating',
    builtIn: true,
    questions: [
      ChoiceQuestion(
        id: 'meals_missed',
        label: 'Meals missed',
        options: [
          (id: 'one', label: '1'),
          (id: 'two', label: '2'),
          (id: 'three_or_more', label: '3 or more'),
        ],
      ),
    ],
  ),
  EventType(id: 'lethargy', name: 'Lethargy', builtIn: true),
  EventType(id: 'scratching', name: 'Scratching', builtIn: true),
  EventType(
    id: 'accident',
    name: 'Accident in the house',
    builtIn: true,
    questions: [
      ChoiceQuestion(
        id: 'what',
        label: 'What',
        options: [
          (id: 'urine', label: 'Urine'),
          (id: 'stool', label: 'Stool'),
          (id: 'both', label: 'Both'),
        ],
      ),
    ],
  ),
  EventType(id: 'wound', name: 'Wound', builtIn: true),
]);
