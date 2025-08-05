    import 'package:flutter/material.dart';
    import 'package:flutter_riverpod/flutter_riverpod.dart';
    import 'package:bloom/data/services/eco_backend.dart';
    import 'package:bloom/ui/screens/learn/quiz_screen.dart';

    class LessonDetailScreen extends ConsumerStatefulWidget {
      final int lessonId;
      final String lessonTitle;

      const LessonDetailScreen({
        super.key,
        required this.lessonId,
        required this.lessonTitle,
      });

      @override
      ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
    }

    class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
      int _currentStep = 0;
      bool _isCompleted = false;
      late List<LessonStep> _lessonSteps;

      @override
      void initState() {
        super.initState();
        _lessonSteps = _getLessonSteps(widget.lessonId);
      }

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          backgroundColor: Colors.green.shade50,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              widget.lessonTitle,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentStep + 1}/${_lessonSteps.length}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // 진행률 바
              _buildProgressBar(),

              // 학습 내용
              Expanded(
                child: _buildLessonContent(),
              ),

              // 하단 버튼들
              _buildBottomButtons(),
            ],
          ),
        );
      }

      Widget _buildProgressBar() {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Learning Progress',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${((_currentStep + 1) / _lessonSteps.length * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_currentStep + 1) / _lessonSteps.length,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                minHeight: 6,
              ),
            ],
          ),
        );
      }

      Widget _buildLessonContent() {
        if (_isCompleted) {
          return _buildCompletionScreen();
        }

        final currentLesson = _lessonSteps[_currentStep];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 단계 제목
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            currentLesson.icon,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            currentLesson.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      currentLesson.content,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 이미지 또는 다이어그램 (있는 경우)
              if (currentLesson.imageUrl != null)
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      currentLesson.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // 핵심 포인트
              if (currentLesson.keyPoints.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Key Points',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...currentLesson.keyPoints.map((point) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 8, right: 12),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                point,
                                style: const TextStyle(fontSize: 14, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
            ],
          ),
        );
      }

      Widget _buildCompletionScreen() {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Learning Complete!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You have completed the ${widget.lessonTitle} lesson.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.stars, color: Colors.amber, size: 24),
                          SizedBox(width: 8),
                          Text(
                            '+50 Points Earned!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      Widget _buildBottomButtons() {
        return Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep--;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Previous',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ),

              if (_currentStep > 0) const SizedBox(width: 12),

              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isCompleted ? _completeLesson : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isCompleted
                      ? 'Take Quiz'
                      : _currentStep == _lessonSteps.length - 1
                        ? 'Finish Learning'
                        : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      void _nextStep() {
        if (_currentStep < _lessonSteps.length - 1) {
          setState(() {
            _currentStep++;
          });
        } else {
          setState(() {
            _isCompleted = true;
          });
        }
      }

      void _completeLesson() async {
        // 퀴즈 화면으로 이동
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => QuizScreen(
              lessonId: widget.lessonId,
              lessonTitle: widget.lessonTitle,
            ),
          ),
        );
      }

      List<LessonStep> _getLessonSteps(int lessonId) {
        // SDGs 13 기후변화 관련 학습 내용
        switch (lessonId) {
          case 1: // Climate Change Science
            return [
              LessonStep(
                title: 'What is Climate Change?',
                icon: Icons.science,
                content: '''Climate change refers to long-term changes in Earth's average temperature and weather patterns.
    
    Since the Industrial Revolution, human activities have caused atmospheric greenhouse gas concentrations to increase rapidly, leading to rising global average temperatures.
    
    These changes go beyond simple temperature increases, affecting the frequency and intensity of extreme weather events, sea level rise, and ecosystem changes.''',
                keyPoints: [
                  'Global average temperature has risen 1.1℃ since Industrial Revolution',
                  'Human activities are the main cause of climate change',
                  'Greenhouse gas concentrations continue to increase',
                ],
              ),
              LessonStep(
                title: 'Types of Greenhouse Gases',
                icon: Icons.cloud,
                content: '''Major greenhouse gases include carbon dioxide (CO₂), methane (CH₄), nitrous oxide (N₂O), and fluorinated gases.
    
    Carbon dioxide is the most important greenhouse gas, accounting for about 76% of total greenhouse gas emissions. It primarily comes from burning fossil fuels and deforestation.
    
    Methane has a warming effect 25 times stronger than carbon dioxide and is produced from livestock, agriculture, and waste treatment processes.''',
                keyPoints: [
                  'CO₂: Accounts for 76% of total emissions',
                  'CH₄: 25 times stronger warming effect than CO₂',
                  'N₂O: Mainly produced from agriculture and industry',
                ],
              ),
              LessonStep(
                title: 'Evidence of Climate Change',
                icon: Icons.trending_up,
                content: '''Climate change is proven through various scientific evidence.
    
    We observe melting glaciers and ice sheets, rising sea levels, declining Arctic sea ice, and changing wildlife habitats.
    
    Weather observation data also shows increasing extreme weather events and changing seasonal patterns.''',
                keyPoints: [
                  'Arctic sea ice area declining 13% annually',
                  'Sea level rising 3.3mm annually',
                  'Increasing frequency of extreme weather events',
                ],
              ),
            ];

          case 2: // Greenhouse Gas Effects
            return [
              LessonStep(
                title: 'Principles of the Greenhouse Effect',
                icon: Icons.wb_sunny,
                content: '''The greenhouse effect is a natural phenomenon that allows Earth to maintain appropriate temperatures.
    
    Energy from the sun warms Earth's surface, and Earth releases this energy back into space as infrared radiation. Greenhouse gases in the atmosphere absorb and re-emit this infrared radiation, keeping Earth warm.
    
    However, when greenhouse gas concentrations increase, more heat becomes trapped in the atmosphere, causing Earth's temperature to rise.''',
                keyPoints: [
                  'Natural greenhouse effect raises Earth temperature by 33℃',
                  'Greenhouse gases absorb infrared radiation',
                  'Increased concentrations cause additional warming',
                ],
              ),
              LessonStep(
                title: 'Human-Enhanced Greenhouse Effect',
                icon: Icons.factory,
                content: '''Human activities that emit greenhouse gases are enhancing the natural greenhouse effect.
    
    Major emission sources include burning fossil fuels, industrial processes, agriculture, and deforestation. Energy production and use account for 75% of total emissions.
    
    Due to these human emissions, atmospheric carbon dioxide concentrations have increased 47% compared to pre-industrial levels.''',
                keyPoints: [
                  'Energy sector accounts for 75% of greenhouse gas emissions',
                  'CO₂ concentration increased 47% (280→415ppm)',
                  'Human activities are the main cause of warming',
                ],
              ),
              LessonStep(
                title: 'Greenhouse Gas Monitoring',
                icon: Icons.sensors,
                content: '''Greenhouse gas concentrations are continuously monitored worldwide.
    
    The Mauna Loa Observatory in Hawaii has been measuring atmospheric carbon dioxide concentrations since 1958, showing a continuous increasing trend.
    
    Satellites, ground-based observatories, and aircraft track global greenhouse gas distribution and changes.''',
                keyPoints: [
                  'Mauna Loa Observatory: 65 years of continuous measurement',
                  'Current CO₂ concentration exceeds 415ppm',
                  'Satellite and ground-based observation networks operate',
                ],
              ),
            ];

          case 3: // Climate Impact Analysis
            return [
              LessonStep(
                title: 'Impacts of Temperature Rise',
                icon: Icons.thermostat,
                content: '''Rising global average temperatures are causing various environmental changes.
    
    Extreme weather events like heat waves, droughts, and floods are occurring more frequently and intensely. These directly affect agricultural productivity, water supply, and human health.
    
    Ecosystem changes are also causing many plants and animals to lose their habitats or face extinction.''',
                keyPoints: [
                  'Extreme weather events increased 3x in frequency',
                  'Crop yields expected to decrease 10-25%',
                  'Species extinction rate accelerated 100-1000x',
                ],
              ),
              LessonStep(
                title: 'Sea Level Rise and Ocean Changes',
                icon: Icons.waves,
                content: '''Sea level rise due to climate change poses serious threats to coastal areas.
    
    Sea levels are continuously rising due to melting glaciers and ice sheets, and thermal expansion of seawater. Currently rising 3.3mm annually, and this rate is accelerating.
    
    Ocean acidification is also progressing, significantly impacting marine ecosystems and fisheries.''',
                keyPoints: [
                  'Sea level rising 3.3mm annually',
                  'Expected to rise 0.43-2.84m by 2100',
                  'Ocean pH decreased 0.1 units (acidification)',
                ],
              ),
              LessonStep(
                title: 'Economic and Social Impacts',
                icon: Icons.business,
                content: '''Climate change is having widespread impacts on the economy and society as a whole.
    
    Economic losses from natural disasters are increasing, causing hundreds of billions of dollars in damage annually.
    
    Environmental refugees due to climate change are increasing, and food security and water security are under threat.''',
                keyPoints: [
                  'Annual natural disaster damage: \$300 billion',
                  '1 billion climate refugees expected by 2050',
                  'Food prices projected to rise 20-50%',
                ],
              ),
            ];

          case 4: // Energy Conservation
            return [
              LessonStep(
                title: 'Importance of Energy Conservation',
                icon: Icons.energy_savings_leaf,
                content: '''Energy conservation is one of the most effective ways to reduce greenhouse gas emissions.
    
    Most of the electricity we use is produced from fossil fuels, which emit large amounts of carbon dioxide in the process.
    
    Reducing household energy consumption can significantly decrease an individual's carbon footprint.''',
                keyPoints: [
                  'Household energy accounts for 16% of total emissions',
                  '20% energy efficiency improvement can reduce emissions by 10%',
                  'Can save 30% on annual energy costs',
                ],
              ),
              LessonStep(
                title: 'Daily Energy Conservation Methods',
                icon: Icons.lightbulb,
                content: '''There are various energy conservation methods you can practice in daily life.
    
    Replace lighting with LEDs, turn off or unplug electronic devices when not in use. Adjust heating and cooling temperatures appropriately, and choose energy-efficient appliances.
    
    These small practices can create big changes when combined.''',
                keyPoints: [
                  'LED lighting saves 80% on electricity usage',
                  'Cutting standby power saves 10% on electricity',
                  'Appropriate heating/cooling saves 30%',
                ],
              ),
              LessonStep(
                title: 'Utilizing Renewable Energy',
                icon: Icons.solar_power,
                content: '''Renewable energy is a sustainable energy source that can produce energy without greenhouse gas emissions.
    
    It generates electricity using natural forces like solar, wind, and hydroelectric power. Recent technological advances have significantly reduced costs, making it economically viable.
    
    Individuals can also utilize renewable energy through solar panel installation and choosing green energy rate plans.''',
                keyPoints: [
                  'Renewable energy costs fell 85% (2010-2020)',
                  'Accounts for 30% of global electricity production',
                  'Personal solar can achieve energy self-sufficiency',
                ],
              ),
            ];

          case 5: // Sustainable Transportation
            return [
              LessonStep(
                title: 'Transportation Sector Greenhouse Gas Emissions',
                icon: Icons.directions_car,
                content: '''The transportation sector is a major emission source, accounting for about 16% of global greenhouse gas emissions.
    
    Cars, trucks, aircraft, ships, and most transportation modes use fossil fuels and emit carbon dioxide.
    
    Personal car use accounts for about 45% of transportation sector emissions, making individual transportation choices very important.''',
                keyPoints: [
                  'Transportation sector emits 16% of total greenhouse gases',
                  'Personal cars account for 45% of transport emissions',
                  'Air travel causes individual emissions to spike',
                ],
              ),
              LessonStep(
                title: 'Eco-Friendly Transportation',
                icon: Icons.electric_bike,
                content: '''Various eco-friendly transportation options can reduce carbon emissions.
    
    Public transportation has significantly lower per-person greenhouse gas emissions compared to personal cars. Bicycles and walking are completely emission-free eco-friendly transportation.
    
    Electric vehicles and hybrid cars are also good low-emission alternatives.''',
                keyPoints: [
                  'Public transport reduces emissions by 50%',
                  'Bicycle use achieves zero emissions',
                  'Electric vehicles reduce emissions by 70%',
                ],
              ),
              LessonStep(
                title: 'Smart Travel Planning',
                icon: Icons.route,
                content: '''Efficient travel planning can reduce unnecessary transportation use.
    
    Combine multiple errands into one trip, or develop habits of walking for short distances. Use remote work or video conferencing to reduce business travel.
    
    Car sharing and bicycle sharing services are also good options.''',
                keyPoints: [
                  '20% reduction in trips saves 20% emissions',
                  'Remote work reduces transport emissions by 30%',
                  'Car sharing reduces need for car ownership',
                ],
              ),
            ];

          case 6: // Personal Carbon Footprint Management
            return [
              LessonStep(
                title: 'What is a Carbon Footprint?',
                icon: Icons.eco,
                content: '''A carbon footprint refers to the total amount of greenhouse gases emitted directly and indirectly by an individual or organization's activities.
    
    All activities in daily life including energy use, transportation, food, and consumer goods are included in your carbon footprint.
    
    Understanding your carbon footprint is the first step in climate action.''',
                keyPoints: [
                  'Global average personal carbon footprint: 4 tons annually',
                  'Developed country average: 10-20 tons annually',
                  'Paris Agreement target: 2.3 tons per person annually',
                ],
              ),
              LessonStep(
                title: 'Measuring Your Carbon Footprint',
                icon: Icons.calculate,
                content: '''You can measure your personal carbon footprint through various online calculators.
    
    Enter your energy usage, transportation patterns, diet, and consumption habits to calculate your annual carbon emissions.
    
    Regular measurement to track changes and verify improvement effects is important.''',
                keyPoints: [
                  'Divided into 4 areas: energy, transport, food, consumption',
                  'Monthly or quarterly regular measurements recommended',
                  'Set goals and monitor progress',
                ],
              ),
              LessonStep(
                title: 'Practical Ways to Reduce Carbon Footprint',
                icon: Icons.trending_down,
                content: '''You can effectively reduce your carbon footprint through systematic approaches.
    
    Prioritize and improve areas with the highest emissions first. Start with small changes and gradually expand.
    
    Practicing together with family and friends can achieve greater effects.''',
                keyPoints: [
                  'Energy efficiency improvements: 30% emission reduction',
                  'Dietary changes: 20% emission reduction',
                  'Transportation changes: 25% emission reduction',
                ],
              ),
            ];

          default:
            return [
              LessonStep(
                title: 'Learning in Preparation',
                icon: Icons.construction,
                content: 'This learning content is currently being prepared. It will be updated soon.',
                keyPoints: [],
              ),
            ];
        }
      }
    }

    class LessonStep {
      final String title;
      final IconData icon;
      final String content;
      final List<String> keyPoints;
      final String? imageUrl;

      LessonStep({
        required this.title,
        required this.icon,
        required this.content,
        required this.keyPoints,
        this.imageUrl,
      });
    }