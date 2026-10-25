import '../domain/models.dart';

/// Built-in professional starter content.
///
/// These are templates, not fixed app categories. A user can install a copy,
/// rename it, add lessons, publish a single lesson, or delete everything.
class StarterCatalog {
  const StarterCatalog._();

  static const List<StarterDeck> decks = <StarterDeck>[
    StarterDeck(
      id: 'physics',
      titleAr: 'الفيزياء',
      titleEn: 'Physics',
      descriptionAr:
          'أساسيات الحركة والقوى والطاقة والكهرباء والموجات، منظمة في دروس قصيرة قابلة للمراجعة.',
      descriptionEn:
          'Motion, forces, energy, electricity and waves, organized into focused lessons.',
      colorHex: '#1D6FD1',
      iconKey: 'bolt',
      tags: <String>['فيزياء', 'علوم', 'Physics'],
      rating: 4.9,
      lessons: <StarterLesson>[
        StarterLesson(
          id: 'motion',
          titleAr: 'الحركة والقوى',
          titleEn: 'Motion & Forces',
          cards: <StarterCard>[
            StarterCard(
              front: 'ما نص قانون نيوتن الثاني؟',
              back: 'القوة المحصلة تساوي الكتلة مضروبة في التسارع: F = ma.',
              hint: 'اربط القوة بالتسارع والكتلة.',
              notes: 'وحدة القوة هي النيوتن، ووحدة الكتلة الكيلوغرام.',
              tags: <String>['نيوتن', 'القوة'],
            ),
            StarterCard(
              front: 'ما الفرق بين السرعة والتسارع؟',
              back:
                  'السرعة معدل تغير الموقع، أما التسارع فهو معدل تغير السرعة مع الزمن.',
              notes: 'يمكن أن يكون التسارع سالباً عند التباطؤ.',
              tags: <String>['السرعة', 'التسارع'],
            ),
            StarterCard(
              front: 'ما هي وحدة قياس التسارع في النظام الدولي؟',
              back: 'متر لكل ثانية مربعة (m/s²).',
              tags: <String>['وحدات'],
            ),
            StarterCard(
              front: 'لماذا يصل الجسم الساقط حراً إلى تسارع ثابت قرب سطح الأرض؟',
              back:
                  'بسبب الجاذبية الأرضية، ويكون التسارع نحو 9.8 m/s² بإهمال مقاومة الهواء.',
              hint: 'قيمة g قريبة من 10 للتبسيط.',
              tags: <String>['الجاذبية', 'السقوط الحر'],
            ),
          ],
        ),
        StarterLesson(
          id: 'energy',
          titleAr: 'الطاقة والكهرباء',
          titleEn: 'Energy & Electricity',
          cards: <StarterCard>[
            StarterCard(
              front: 'ما مبدأ حفظ الطاقة؟',
              back:
                  'الطاقة لا تفنى ولا تُستحدث من العدم، بل تتحول من شكل إلى آخر.',
              tags: <String>['الطاقة'],
            ),
            StarterCard(
              front: 'اكتب قانون أوم.',
              back: 'الجهد = التيار × المقاومة، أي V = IR.',
              notes: 'الوحدة: فولت = أمبير × أوم.',
              tags: <String>['أوم', 'الدوائر'],
            ),
            StarterCard(
              front: 'ما الفرق بين طاقة الوضع والطاقة الحركية؟',
              back:
                  'طاقة الوضع تعتمد على الموقع أو الحالة، والطاقة الحركية تعتمد على الحركة والكتلة والسرعة.',
              tags: <String>['طاقة الوضع', 'الطاقة الحركية'],
            ),
            StarterCard(
              front: 'كيف تُحسب القدرة الكهربائية؟',
              back: 'القدرة = الجهد × التيار، أي P = VI.',
              notes: 'تُقاس القدرة بالواط.',
              tags: <String>['القدرة'],
            ),
          ],
        ),
        StarterLesson(
          id: 'waves',
          titleAr: 'الموجات والبصريات',
          titleEn: 'Waves & Optics',
          cards: <StarterCard>[
            StarterCard(
              front: 'ما العلاقة بين سرعة الموجة وترددها وطولها الموجي؟',
              back: 'السرعة = التردد × الطول الموجي، أي v = fλ.',
              tags: <String>['الموجات'],
            ),
            StarterCard(
              front: 'ماذا يحدث للضوء عند انتقاله من الهواء إلى الماء؟',
              back: 'ينكسر ويقترب من العمود المقام بسبب تغير سرعته.',
              tags: <String>['الانكسار', 'البصريات'],
            ),
            StarterCard(
              front: 'ما وظيفة العدسة المحدبة؟',
              back: 'تجميع الأشعة الضوئية المتوازية في نقطة البؤرة.',
              tags: <String>['العدسات'],
            ),
            StarterCard(
              front: 'ما الفرق بين الانعكاس والانكسار؟',
              back:
                  'الانعكاس ارتداد الموجة عن سطح، والانكسار تغير اتجاهها عند دخول وسط جديد.',
              tags: <String>['الانعكاس', 'الانكسار'],
            ),
          ],
        ),
      ],
    ),
    StarterDeck(
      id: 'chemistry',
      titleAr: 'الكيمياء',
      titleEn: 'Chemistry',
      descriptionAr:
          'من بنية الذرة إلى الروابط والتفاعلات والعضوية، بطاقات مختصرة للمراجعة السريعة.',
      descriptionEn:
          'Atomic structure, bonding, reactions and organic chemistry in concise cards.',
      colorHex: '#0B7A5A',
      iconKey: 'science',
      tags: <String>['كيمياء', 'علوم', 'Chemistry'],
      rating: 4.8,
      lessons: <StarterLesson>[
        StarterLesson(
          id: 'atomic',
          titleAr: 'البنية الذرية',
          titleEn: 'Atomic Structure',
          cards: <StarterCard>[
            StarterCard(
              front: 'ما هو العدد الذري؟',
              back: 'عدد البروتونات في نواة الذرة، ويحدد هوية العنصر.',
              tags: <String>['الذرة', 'البروتون'],
            ),
            StarterCard(
              front: 'ما الفرق بين النظائر؟',
              back:
                  'ذرات للعنصر نفسه تختلف في عدد النيوترونات، وبالتالي في الكتلة الذرية.',
              tags: <String>['النظائر'],
            ),
            StarterCard(
              front: 'ما ترتيب الإلكترونات في المستوى الثاني؟',
              back: 'يتسع المستوى الثاني لثمانية إلكترونات كحد أقصى.',
              tags: <String>['الإلكترونات'],
            ),
            StarterCard(
              front: 'لماذا يزداد الجذب النووي نحو اليمين في الدورة؟',
              back:
                  'لأن عدد البروتونات يزداد مع بقاء مستوى الطاقة الرئيسي نفسه تقريباً.',
              tags: <String>['الجدول الدوري'],
            ),
          ],
        ),
        StarterLesson(
          id: 'bonding',
          titleAr: 'الروابط والتفاعلات',
          titleEn: 'Bonding & Reactions',
          cards: <StarterCard>[
            StarterCard(
              front: 'ما الفرق بين الرابطة الأيونية والتساهمية؟',
              back:
                  'الأيونية انتقال إلكترونات بين ذرتين، والتساهمية مشاركة إلكترونات.',
              tags: <String>['الروابط'],
            ),
            StarterCard(
              front: 'ما هو المول؟',
              back:
                  'كمية المادة التي تحتوي على 6.022 × 10²³ جسيماً (عدد أفوجادرو).',
              tags: <String>['المول'],
            ),
            StarterCard(
              front: 'لماذا يجب موازنة المعادلة الكيميائية؟',
              back: 'لتحقيق قانون حفظ المادة: عدد ذرات كل عنصر متساوٍ في الطرفين.',
              tags: <String>['موازنة المعادلات'],
            ),
            StarterCard(
              front: 'ما ناتج تفاعل حمض مع قاعدة؟',
              back: 'ملح وماء، ويُسمى تفاعل التعادل.',
              tags: <String>['الأحماض', 'القواعد'],
            ),
          ],
        ),
        StarterLesson(
          id: 'organic',
          titleAr: 'الكيمياء العضوية',
          titleEn: 'Organic Chemistry',
          cards: <StarterCard>[
            StarterCard(
              front: 'ما الصيغة العامة للألكانات؟',
              back: 'CnH2n+2.',
              notes: 'الميثان CH4 والإيثان C2H6 مثالان.',
              tags: <String>['الألكانات'],
            ),
            StarterCard(
              front: 'ما نوع الرابطة في الألكينات؟',
              back: 'رابطة مزدوجة بين ذرتي كربون.',
              tags: <String>['الألكينات'],
            ),
            StarterCard(
              front: 'ما هي المجموعة الوظيفية في الكحولات؟',
              back: 'مجموعة الهيدروكسيل –OH.',
              tags: <String>['الكحولات'],
            ),
            StarterCard(
              front: 'ما المقصود بالمتشكلات؟',
              back:
                  'مركبات لها الصيغة الجزيئية نفسها لكن ترتيب الذرات أو الفراغي مختلف.',
              tags: <String>['المتشكلات'],
            ),
          ],
        ),
      ],
    ),
    StarterDeck(
      id: 'biology',
      titleAr: 'البيولوجيا',
      titleEn: 'Biology',
      descriptionAr:
          'الخلية والوراثة والأجهزة الحيوية، مع تركيز على المفاهيم التي تتكرر في الاختبارات.',
      descriptionEn:
          'Cells, genetics and body systems with a focus on high-yield concepts.',
      colorHex: '#3B7A1F',
      iconKey: 'biotech',
      tags: <String>['بيولوجيا', 'علوم', 'Biology'],
      rating: 4.9,
      lessons: <StarterLesson>[
        StarterLesson(
          id: 'cell',
          titleAr: 'الخلية',
          titleEn: 'The Cell',
          cards: <StarterCard>[
            StarterCard(
              front: 'ما وظيفة الميتوكوندريا؟',
              back: 'إنتاج الطاقة على شكل ATP عبر التنفس الخلوي.',
              hint: 'تُسمى بيت الطاقة.',
              notes: 'تكثر في خلايا العضلات لاحتياجها الكبير للطاقة.',
              tags: <String>['الميتوكوندريا', 'ATP'],
            ),
            StarterCard(
              front: 'أين تحدث الغلكزة؟',
              back: 'في السيتوبلازم.',
              tags: <String>['الغلكزة'],
            ),
            StarterCard(
              front: 'ما وظيفة الريبوسوم؟',
              back: 'تصنيع البروتين.',
              tags: <String>['الريبوسوم'],
            ),
            StarterCard(
              front: 'ما الفرق بين الانقسام المتساوي والمنصف؟',
              back:
                  'المتساوي ينتج خلايا متماثلة، والمنصف ينتج أمشاجاً بنصف عدد الكروموسومات.',
              tags: <String>['الانقسام'],
            ),
          ],
        ),
        StarterLesson(
          id: 'genetics',
          titleAr: 'الوراثة',
          titleEn: 'Genetics',
          cards: <StarterCard>[
            StarterCard(
              front: 'ما هو الحمض النووي DNA؟',
              back:
                  'جزيء يحمل المعلومات الوراثية على شكل تسلسل من القواعد النيتروجينية.',
              tags: <String>['DNA'],
            ),
            StarterCard(
              front: 'ما الفرق بين الجين والكروموسوم؟',
              back:
                  'الجين قطعة من DNA تصف بروتيناً أو وظيفة، والكروموسوم حزمة من DNA والبروتين.',
              tags: <String>['الجينات'],
            ),
            StarterCard(
              front: 'ما نسبة الأفراد الظاهرين للصفة السائدة في تهجين Aa × Aa؟',
              back: '75% للصفة السائدة و25% للصفة المتنحية.',
              tags: <String>['مندل'],
            ),
            StarterCard(
              front: 'ما هو الطفرة الجينية؟',
              back: 'تغير دائم في تسلسل DNA قد يكون مفيداً أو ضاراً أو محايداً.',
              tags: <String>['الطفرات'],
            ),
          ],
        ),
        StarterLesson(
          id: 'systems',
          titleAr: 'الأجهزة الحيوية',
          titleEn: 'Body Systems',
          cards: <StarterCard>[
            StarterCard(
              front: 'ما وظيفة الجهاز الدوري؟',
              back: 'نقل الدم والأكسجين والمواد الغذائية وثاني أكسيد الكربون.',
              tags: <String>['الجهاز الدوري'],
            ),
            StarterCard(
              front: 'أين يحدث تبادل الغازات في الرئتين؟',
              back: 'في الحويصلات الهوائية.',
              tags: <String>['التنفس'],
            ),
            StarterCard(
              front: 'ما وظيفة الخلايا العصبية؟',
              back: 'استقبال ونقل الإشارات الكهربائية والكيميائية.',
              tags: <String>['الجهاز العصبي'],
            ),
            StarterCard(
              front: 'ما دور الخلايا التائية المساعدة؟',
              back: 'تنشيط استجابة المناعة الخلطية والخلوية.',
              tags: <String>['المناعة'],
            ),
          ],
        ),
      ],
    ),
    StarterDeck(
      id: 'history_of_medicine',
      titleAr: 'تاريخ الطب',
      titleEn: 'History of Medicine',
      descriptionAr:
          'محطات الطب من اليونان إلى الطب الإسلامي والثورة الجراحية والمضادات الحيوية.',
      descriptionEn:
          'Medicine from ancient Greece to Islamic hospitals, surgical asepsis and antibiotics.',
      colorHex: '#A65A3A',
      iconKey: 'history_edu',
      tags: <String>['تاريخ الطب', 'طب', 'History'],
      rating: 4.8,
      lessons: <StarterLesson>[
        StarterLesson(
          id: 'ancient',
          titleAr: 'الطب القديم',
          titleEn: 'Ancient Medicine',
          cards: <StarterCard>[
            StarterCard(
              front: 'من يُعد أب الطب الغربي؟',
              back: 'أبقراط، صاحب قسم أبقراط.',
              tags: <String>['أبقراط'],
            ),
            StarterCard(
              front: 'ما إسهام ابن سينا في الطب؟',
              back: 'كتاب القانون في الطب، الذي بقي مرجعاً لقرون.',
              tags: <String>['ابن سينا'],
            ),
            StarterCard(
              front: 'ما دور البيمارستانات في الحضارة الإسلامية؟',
              back: 'كانت مستشفيات متكاملة للعلاج والتعليم والرعاية.',
              tags: <String>['البيمارستان'],
            ),
            StarterCard(
              front: 'من هو جالينوس؟',
              back:
                  'طبيب يوناني أثّرت نظرياته في التشريح والفسيولوجيا لقرون.',
              tags: <String>['جالينوس'],
            ),
          ],
        ),
        StarterLesson(
          id: 'surgery',
          titleAr: 'الثورة الجراحية',
          titleEn: 'Surgical Revolution',
          cards: <StarterCard>[
            StarterCard(
              front: 'ما أهمية التخدير في الجراحة؟',
              back: 'مكّن الجراحين من إجراء عمليات طويلة دون ألم شديد للمريض.',
              tags: <String>['التخدير'],
            ),
            StarterCard(
              front: 'من أدخل التعقيم بالمطهرات في الجراحة؟',
              back: 'جوزيف ليستر.',
              tags: <String>['ليستر', 'التعقيم'],
            ),
            StarterCard(
              front: 'كيف غيّرت الأشعة السينية الطب؟',
              back: 'أتاحت تصوير العظام والأعضاء الداخلية دون جراحة.',
              tags: <String>['الأشعة'],
            ),
            StarterCard(
              front: 'ما الفرق بين التعقيم والأسلوب المعقم؟',
              back:
                  'التعقيم قتل الجراثيم، والأسلوب المعقم منع وصولها إلى الجرح.',
              tags: <String>['التعقيم'],
            ),
          ],
        ),
        StarterLesson(
          id: 'antibiotics',
          titleAr: 'المضادات الحيوية',
          titleEn: 'Antibiotics',
          cards: <StarterCard>[
            StarterCard(
              front: 'من اكتشف البنسلين؟',
              back: 'ألكسندر فلمنج عام 1928.',
              tags: <String>['البنسلين', 'فلمنج'],
            ),
            StarterCard(
              front: 'لماذا تُعد مقاومة المضادات الحيوية مشكلة صحية عالمية؟',
              back:
                  'لأن البكتيريا تتطور وتصبح غير قابلة للعلاج بالمضادات المعروفة.',
              tags: <String>['المقاومة'],
            ),
            StarterCard(
              front: 'ما مبدأ عمل اللقاحات؟',
              back:
                  'تحفيز الجهاز المناعي للتعرف على مسبب المرض دون الإصابة به.',
              tags: <String>['اللقاحات'],
            ),
            StarterCard(
              front: 'من أول من استخدم التطعيم ضد الجدري بشكل منظم؟',
              back: 'إدوارد جينر.',
              tags: <String>['الجدري'],
            ),
          ],
        ),
      ],
    ),
    StarterDeck(
      id: 'english_1',
      titleAr: 'الانكليزية 1',
      titleEn: 'English 1',
      descriptionAr:
          'قواعد ومفردات أكاديمية ومهارات قراءة للمستوى الجامعي الأول.',
      descriptionEn:
          'Grammar, academic vocabulary and reading skills for first-year university English.',
      colorHex: '#6B5BC9',
      iconKey: 'translate',
      tags: <String>['انكليزية', 'English', 'لغة'],
      rating: 4.7,
      lessons: <StarterLesson>[
        StarterLesson(
          id: 'grammar',
          titleAr: 'Grammar Essentials',
          titleEn: 'Grammar Essentials',
          cards: <StarterCard>[
            StarterCard(
              front: 'Complete: She ____ to university every day.',
              back: 'goes',
              hint: 'Third person singular.',
              notes: 'Add -es to verbs ending in -o, -ch, -sh, -ss, -x, -z.',
              tags: <String>['present simple'],
            ),
            StarterCard(
              front: 'What is the past tense of "study"?',
              back: 'studied',
              tags: <String>['past simple'],
            ),
            StarterCard(
              front: 'Choose: I saw ___ apple on the table.',
              back: 'an',
              notes: 'Use "an" before a vowel sound.',
              tags: <String>['articles'],
            ),
            StarterCard(
              front: 'Complete: The book is ___ the table.',
              back: 'on',
              tags: <String>['prepositions'],
            ),
          ],
        ),
        StarterLesson(
          id: 'academic_vocabulary',
          titleAr: 'Academic Vocabulary',
          titleEn: 'Academic Vocabulary',
          cards: <StarterCard>[
            StarterCard(
              front: 'Define "analyze".',
              back: 'To examine something in detail in order to understand it.',
              tags: <String>['academic'],
            ),
            StarterCard(
              front: 'What does "significant" mean in academic writing?',
              back: 'Important or large enough to be worth attention.',
              tags: <String>['academic'],
            ),
            StarterCard(
              front: 'Define "evidence".',
              back: 'Facts or information that support a claim or conclusion.',
              tags: <String>['research'],
            ),
            StarterCard(
              front: 'What is a "hypothesis"?',
              back:
                  'A testable explanation for an observation, proposed before research.',
              tags: <String>['research'],
            ),
          ],
        ),
        StarterLesson(
          id: 'reading',
          titleAr: 'Reading Skills',
          titleEn: 'Reading Skills',
          cards: <StarterCard>[
            StarterCard(
              front: 'What is skimming?',
              back: 'Reading quickly to get the general idea of a text.',
              tags: <String>['reading'],
            ),
            StarterCard(
              front: 'What is scanning?',
              back: 'Looking quickly for a specific piece of information.',
              tags: <String>['reading'],
            ),
            StarterCard(
              front: 'What is an inference?',
              back: 'A conclusion based on evidence and reasoning, not stated directly.',
              tags: <String>['inference'],
            ),
            StarterCard(
              front: 'How do you identify the main idea of a paragraph?',
              back: 'Look for the topic sentence and the idea supported by most details.',
              tags: <String>['main idea'],
            ),
          ],
        ),
      ],
    ),
  ];

  static List<LibraryItem> libraryItems({required bool isArabic}) {
    return decks
        .map(
          (StarterDeck deck) => LibraryItem(
            id: 'starter-${deck.id}',
            sourceTemplateId: deck.id,
            title: isArabic ? deck.titleAr : deck.titleEn,
            description: isArabic ? deck.descriptionAr : deck.descriptionEn,
            colorHex: deck.colorHex,
            iconKey: deck.iconKey,
            tags: deck.tags,
            cardCount: deck.cardCount,
            subdeckCount: deck.lessons.length,
            authorName: isArabic ? 'فريق بطاقاتي' : 'Bitaqati Team',
            rating: deck.rating,
            isOfficial: true,
            isInstalled: false,
          ),
        )
        .toList(growable: false);
  }

  static StarterDeck? byId(String id) {
    for (final StarterDeck deck in decks) {
      if (deck.id == id) {
        return deck;
      }
    }
    return null;
  }
}

class StarterDeck {
  const StarterDeck({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.colorHex,
    required this.iconKey,
    required this.tags,
    required this.rating,
    required this.lessons,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final String descriptionEn;
  final String colorHex;
  final String iconKey;
  final List<String> tags;
  final double rating;
  final List<StarterLesson> lessons;

  String title(String languageCode) =>
      languageCode == 'ar' ? titleAr : titleEn;

  String description(String languageCode) =>
      languageCode == 'ar' ? descriptionAr : descriptionEn;

  int get cardCount => lessons.fold<int>(
    0,
    (int value, StarterLesson lesson) => value + lesson.cards.length,
  );
}

class StarterLesson {
  const StarterLesson({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.cards,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final List<StarterCard> cards;

  String title(String languageCode) =>
      languageCode == 'ar' ? titleAr : titleEn;
}

class StarterCard {
  const StarterCard({
    required this.front,
    required this.back,
    required this.tags,
    this.hint = '',
    this.notes = '',
  });

  final String front;
  final String back;
  final String hint;
  final String notes;
  final List<String> tags;
}
