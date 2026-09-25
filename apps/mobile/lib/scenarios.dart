/// Everyday Relatable Scenarios for the Renance app.
///
/// Dart port of the web's `apps/web/lib/scenarios.ts` (the contributor
/// feature from Ayoola-tech2024's PR #1): connects abstract scientific,
/// mathematical and social-science principles to everyday physical and
/// social situations, in standard clear English. Zero dependencies,
/// fully offline.
library;

enum ScenarioCategory { physics, chemistry, biology, economics, mathematics, general }

class EverydayScenario {
  const EverydayScenario({
    required this.id,
    required this.category,
    required this.topic,
    required this.keywords,
    required this.concept,
    required this.scenarioTitle,
    required this.scenario,
    required this.takeaway,
  });

  final String id;
  final ScenarioCategory category;
  final String topic;
  final List<String> keywords;
  final String concept;
  final String scenarioTitle;
  final String scenario;
  final String takeaway;
}

const List<EverydayScenario> kScenarioBank = <EverydayScenario>[
  // ---------------- physics ----------------
  EverydayScenario(
    id: 'phys-inertia',
    category: ScenarioCategory.physics,
    topic: "Newton's First Law / Inertia",
    keywords: <String>['inertia', 'first law', 'newton', 'motion', 'rest', 'unbalanced force', 'momentum'],
    concept: 'Objects resist any change to their state of motion unless an external force acts on them.',
    scenarioTitle: 'Standing in a Moving Vehicle That Suddenly Brakes',
    scenario:
        'When you are standing inside a moving bus and the driver abruptly steps on the brakes, your feet stop with the '
        'floor of the vehicle, but your upper body continues moving forward. This is not because an invisible hand pushed '
        'you forward, but because your body was already traveling at the vehicle speed and naturally resists changing that '
        'speed until an external force stops it.',
    takeaway:
        'Inertia is simply matter being stubborn: stationary things stay still, and moving things keep moving until forced otherwise.',
  ),
  EverydayScenario(
    id: 'phys-friction',
    category: ScenarioCategory.physics,
    topic: 'Friction & Traction',
    keywords: <String>['friction', 'rough surface', 'smooth', 'lubricant', 'traction', 'limiting friction', 'resistance to motion'],
    concept: 'Friction is the contact force that opposes the sliding or rolling of one solid object over another.',
    scenarioTitle: 'Walking on Smooth Wet Tiles vs. Rough Concrete',
    scenario:
        'If you try running in rubber slippers across a freshly mopped ceramic tile floor, you easily slip because water '
        'fills the microscopic grooves and reduces resistance. On rough, dry outdoor concrete, the microscopic ridges of '
        'your slippers interlock with the ground, providing the grip needed to push yourself forward without falling.',
    takeaway:
        'Friction is not just an obstacle; without friction between your shoes and the floor, walking forward would be impossible.',
  ),
  EverydayScenario(
    id: 'phys-archimedes',
    category: ScenarioCategory.physics,
    topic: "Archimedes' Principle & Upthrust",
    keywords: <String>['archimedes', 'upthrust', 'buoyancy', 'float', 'density', 'displaced liquid', 'apparent weight'],
    concept: 'An object immersed in a fluid experiences an upward force equal to the weight of the fluid it displaces.',
    scenarioTitle: 'Pushing an Empty Plastic Bucket Down into a Full Drum of Water',
    scenario:
        'Try holding an empty plastic bucket and forcing it straight down into a full drum of water. The deeper you push '
        'it, the harder the water pushes back against your hands. If you let go, it shoots back up to the surface. The '
        'bucket displaces a heavy volume of water, and that displaced water pushes back upward with equivalent force.',
    takeaway: 'Upthrust is the fluid fighting for its space: the more volume you submerge, the stronger the upward push.',
  ),
  EverydayScenario(
    id: 'phys-pressure-area',
    category: ScenarioCategory.physics,
    topic: 'Pressure and Surface Area',
    keywords: <String>['pressure', 'force per unit area', 'surface area', 'sharp', 'blunt knife', 'high heels', 'p = f/a'],
    concept: 'Pressure is force divided by area: a smaller surface area concentrates force and produces much higher pressure.',
    scenarioTitle: 'Cutting with a Sharp Knife vs. a Blunt Knife',
    scenario:
        'When a kitchen knife is sharpened, its cutting edge becomes extremely thin. When you press down, your hand muscle '
        'force is focused onto a tiny fraction of a millimeter, creating immense pressure that slices cleanly through meat '
        'or bread. A blunt knife spreads that exact same muscle force over a wider edge, producing far less pressure.',
    takeaway: 'Smaller contact area means concentrated pressure; larger area spreads the force and lowers pressure.',
  ),
  EverydayScenario(
    id: 'phys-ohm',
    category: ScenarioCategory.physics,
    topic: "Ohm's Law & Resistance",
    keywords: <String>['ohm', 'resistance', 'voltage', 'current', 'resistor', 'v = ir', 'potential difference'],
    concept: 'Current is the flow rate of charge, driven by voltage and opposed by resistance.',
    scenarioTitle: 'Water Flowing Through a Clear Pipe vs. a Clogged Pipe',
    scenario:
        'Think of an overhead water tank connected to a garden hose. Voltage is the water pressure from the tank height '
        'pushing downward. Current is the volume of water gushing out of the tap per second. Resistance is whatever blocks '
        'the flow: if someone pinches the hose or dirt clogs the pipe, less water comes out even though tank pressure '
        'remains unchanged.',
    takeaway: 'Voltage pushes, current flows, and resistance gets in the way.',
  ),
  EverydayScenario(
    id: 'phys-conduction',
    category: ScenarioCategory.physics,
    topic: 'Thermal Conduction & Insulators',
    keywords: <String>['conduction', 'heat transfer', 'insulator', 'conductor', 'metal spoon', 'wooden handle'],
    concept: 'Thermal conductors transfer vibrating kinetic energy between atoms quickly, while insulators transfer it slowly.',
    scenarioTitle: 'Leaving a Metal Spoon vs. a Wooden Ladle in Boiling Soup',
    scenario:
        'If you leave an iron or stainless steel spoon inside a hot pot on fire, within two minutes the handle burns your '
        'fingers because metal atoms pass vibrating heat rapidly up the stem. A wooden or silicone spoon in the exact same '
        'boiling pot stays cool at the top because wood does not easily pass thermal vibrations along its structure.',
    takeaway: 'Conductors pass thermal energy from atom to atom like a rapid relay race; insulators block the pass.',
  ),
  EverydayScenario(
    id: 'phys-doppler',
    category: ScenarioCategory.physics,
    topic: 'Doppler Effect',
    keywords: <String>['doppler', 'frequency', 'pitch', 'approaching', 'receding', 'siren', 'wavelength'],
    concept:
        'The apparent change in frequency or pitch of a wave when the source and observer are moving relative to each other.',
    scenarioTitle: 'An Ambulance or Police Siren Speeding Past You',
    scenario:
        'When an ambulance with a blaring siren speeds toward you, each sound wave is bunched closer together as it '
        'travels, causing your ear to hear a higher-pitched scream. The moment the ambulance speeds away from you, the '
        'sound waves are stretched out behind it, making the siren suddenly drop to a lower, deeper pitch.',
    takeaway:
        'The source produces the exact same sound continuously, but motion bunches waves up in front and stretches them behind.',
  ),

  // ---------------- chemistry ----------------
  EverydayScenario(
    id: 'chem-diffusion',
    category: ScenarioCategory.chemistry,
    topic: 'Diffusion & Kinetic Theory',
    keywords: <String>['diffusion', 'concentration gradient', 'kinetic theory', 'perfume', 'random motion', 'brownian'],
    concept:
        'Particles move spontaneously from an area of higher concentration to an area of lower concentration until evenly mixed.',
    scenarioTitle: 'Spraying Perfume in One Corner of a Closed Room',
    scenario:
        'If someone sprays a burst of fragrance at the doorway of a quiet bedroom, nobody at the far window smells it '
        'immediately. Over the next minute, without any fan blowing, air molecules bounce against the perfume molecules, '
        'knocking them randomly in every direction until the scent spreads evenly across the entire room.',
    takeaway: 'Molecules never sit still: random thermal motion naturally scatters concentrated crowds into open spaces.',
  ),
  EverydayScenario(
    id: 'chem-osmosis',
    category: ScenarioCategory.chemistry,
    topic: 'Osmosis & Semi-Permeable Membranes',
    keywords: <String>['osmosis', 'semi-permeable', 'water potential', 'hypotonic', 'hypertonic', 'turgid', 'flaccid'],
    concept:
        'Water molecules pass across a selectively permeable barrier from a dilute solution into a more concentrated solution.',
    scenarioTitle: 'Soaking Hard Dried Beans in Fresh Water Overnight',
    scenario:
        'When you take rock-hard, wrinkled dry beans and soak them in a bowl of plain tap water overnight, you wake up to '
        'find them swollen, smooth, and double in size. The bean skin acts as a selective filter: it lets water molecules '
        'flow into the concentrated sugars and proteins inside the bean cells, but prevents the starches inside from '
        'leaking out.',
    takeaway: 'Water naturally moves toward the thirstier, more concentrated side of a membrane to dilute it.',
  ),
  EverydayScenario(
    id: 'chem-catalyst',
    category: ScenarioCategory.chemistry,
    topic: 'Catalysts & Activation Energy',
    keywords: <String>['catalyst', 'activation energy', 'rate of reaction', 'speed up', 'enzyme', 'reaction path'],
    concept:
        'A catalyst speeds up a chemical reaction by providing an alternative pathway with lower activation energy without being consumed.',
    scenarioTitle: 'Taking a Shortcut Through a Tunnel vs. Climbing Over a Mountain',
    scenario:
        'Imagine two towns separated by a steep rocky mountain. Travelers can climb over the peak, but it takes immense '
        'energy and few people finish the journey. If engineers carve a level tunnel straight through the mountain, '
        'ordinary travelers walk through easily and quickly. The tunnel does not change the starting town or destination, '
        'nor is the tunnel destroyed by people walking through it.',
    takeaway: 'A catalyst opens a lower-energy shortcut so more molecules have the energy to react.',
  ),
  EverydayScenario(
    id: 'chem-exothermic',
    category: ScenarioCategory.chemistry,
    topic: 'Exothermic vs. Endothermic Reactions',
    keywords: <String>['exothermic', 'endothermic', 'heat absorbed', 'heat released', 'enthalpy', 'combustion'],
    concept:
        'Exothermic reactions release energy into their surroundings (getting hot), while endothermic reactions absorb heat (getting cold).',
    scenarioTitle: 'Lighting Charcoal Fire vs. Mixing Glucose Powder in Water',
    scenario:
        'Burning wood or charcoal breaks chemical bonds and releases stored chemical energy as blazing warmth you can feel '
        'on your face, which is exothermic. In contrast, when you stir cold glucose powder or certain fertilizer salts into '
        'a glass of room-temperature water, the glass immediately feels chilly to the touch because the dissolving process '
        'absorbs heat from the surrounding water.',
    takeaway: 'Exothermic gives out warmth to the room; endothermic pulls warmth from the room.',
  ),
  EverydayScenario(
    id: 'chem-saturation',
    category: ScenarioCategory.chemistry,
    topic: 'Solubility & Saturated Solutions',
    keywords: <String>['solubility', 'saturated', 'solute', 'solvent', 'crystallization', 'dissolve'],
    concept:
        'A solution is saturated when it contains the maximum amount of dissolved solute possible at that specific temperature.',
    scenarioTitle: 'Stirring Sugar into Cold Tea vs. Hot Tea',
    scenario:
        'If you add one teaspoon of sugar to a cup of iced water, it dissolves easily. By the fifth spoon, no matter how '
        'vigorously you stir, grains collect at the bottom because the liquid has reached its holding capacity. If you heat '
        'the water, the excited molecules move apart, opening space to dissolve several more spoonfuls.',
    takeaway:
        'Saturation is a full sponge: once every pocket between liquid molecules is occupied, extra solute simply falls to the bottom.',
  ),

  // ---------------- biology ----------------
  EverydayScenario(
    id: 'bio-homeostasis',
    category: ScenarioCategory.biology,
    topic: 'Homeostasis & Thermoregulation',
    keywords: <String>['homeostasis', 'sweating', 'shivering', 'thermoregulation', 'internal environment', 'negative feedback'],
    concept: 'The ability of an organism to maintain stable internal conditions despite external fluctuations.',
    scenarioTitle: 'Sweating Under the Afternoon Sun',
    scenario:
        'When you walk under midday heat, your body temperature starts to climb above 37 degrees Celsius. Your brain '
        'immediately triggers sweat glands across your skin. As the beads of water evaporate into the air, they carry '
        'excess thermal energy away from your skin, bringing your core temperature right back to normal.',
    takeaway:
        'Homeostasis is your body internal thermostat constantly making micro-adjustments so your cells survive.',
  ),
  EverydayScenario(
    id: 'bio-genetics',
    category: ScenarioCategory.biology,
    topic: 'Dominant vs. Recessive Alleles',
    keywords: <String>['allele', 'dominant', 'recessive', 'heterozygous', 'homozygous', 'phenotype', 'genotype', 'punnett'],
    concept:
        'A dominant trait masks the presence of a recessive trait, but the hidden recessive gene can still pass to the next generation.',
    scenarioTitle: 'Two Dark-Eyed Parents Having a Light-Eyed Child',
    scenario:
        'Imagine two parents who both have dark eyes, but both carry one hidden light-eye gene inherited from a '
        'grandparent. Neither parent looks light-eyed because the dark allele overpowers it. But if both parents happen to '
        'pass their hidden quiet gene to their baby, that child will display the light trait, seemingly out of nowhere.',
    takeaway:
        'A recessive trait is like a whisper: you will not hear it if a dominant voice is shouting, but two whispers together are heard clearly.',
  ),

  // ---------------- economics ----------------
  EverydayScenario(
    id: 'econ-opportunity-cost',
    category: ScenarioCategory.economics,
    topic: 'Opportunity Cost & Scarcity',
    keywords: <String>['opportunity cost', 'scarcity', 'alternative forgone', 'scale of preference', 'choice'],
    concept: 'Opportunity cost is the real value of the next best alternative that you must give up when making a choice.',
    scenarioTitle: 'Deciding Between Buying Data or Having a Plate of Rice',
    scenario:
        'Suppose you have only 1,500 naira in your pocket. You can either buy an internet data bundle to watch study '
        'videos, or buy a plate of jollof rice at the cafeteria. If you choose the data bundle, the true economic cost is '
        'not just the 1,500 naira cash, it is the satisfaction and energy of the plate of food you had to sacrifice.',
    takeaway: 'Opportunity cost is not what you spent; it is the best thing you had to say "no" to.',
  ),
  EverydayScenario(
    id: 'econ-demand-supply',
    category: ScenarioCategory.economics,
    topic: 'Law of Supply and Demand',
    keywords: <String>['supply and demand', 'equilibrium price', 'scarcity', 'shortage', 'surplus', 'price mechanism'],
    concept: 'Prices rise when demand exceeds supply, and fall when supply exceeds demand.',
    scenarioTitle: 'Tomato Prices During Rain Scarcity vs. Harvest Season',
    scenario:
        'During dry months when few farmers harvest tomatoes, hundreds of buyers compete for a few baskets in the market, '
        'bidding the price up. When harvest season arrives and truckloads of fresh tomatoes flood the stalls every '
        'morning, sellers slash prices to clear their stock before the fruit spoils.',
    takeaway:
        'When items are rare and everyone wants them, price goes up. When items are everywhere and buyers are few, price drops.',
  ),

  // ---------------- mathematics ----------------
  EverydayScenario(
    id: 'math-probability',
    category: ScenarioCategory.mathematics,
    topic: 'Probability & Independent Events',
    keywords: <String>['probability', 'independent events', 'dice', 'coin', 'sample space', 'outcomes'],
    concept:
        'The likelihood of an outcome is the favorable options divided by total possible outcomes; past independent events do not alter future odds.',
    scenarioTitle: 'Tossing a Coin That Landed on Heads 5 Times in a Row',
    scenario:
        'If you flip a fair coin and it lands on Heads five times straight, someone might shout: "Tails is definitely due '
        'next!" But the coin has no memory, brain, or emotion. On the sixth toss, the chances of getting Tails remain '
        'exactly 1 out of 2 (50%), just as they were on the very first flip.',
    takeaway: 'Random events do not keep grudges or debts: each independent trial starts with a clean slate.',
  ),
];

/// Searches the bank for the closest match to a question's topic, stem
/// or subject. Returns null when nothing scores strongly enough; the
/// caller then simply hides the card.
EverydayScenario? findEverydayScenario({
  String topic = '',
  String stem = '',
  String subject = '',
}) {
  final String query = '$topic $stem $subject'.toLowerCase();
  if (query.trim().isEmpty) return null;

  EverydayScenario? bestMatch;
  int highestScore = 0;

  for (final EverydayScenario item in kScenarioBank) {
    int score = 0;

    if (topic.isNotEmpty && item.topic.toLowerCase().contains(topic.toLowerCase())) {
      score += 15;
    }
    for (final String kw in item.keywords) {
      if (query.contains(kw.toLowerCase())) {
        score += 5;
      }
    }

    if (score > highestScore && score >= 10) {
      highestScore = score;
      bestMatch = item;
    }
  }
  return bestMatch;
}
