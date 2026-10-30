# Category bank: notes

`categories.csv` has 139 categories (65 tier 1, 47 tier 2, 27 tier 3), 958 unique words, and 183 crossing words
(40 of them in 3 or more categories). Every category from `data/levels/*.json` is harvested with its label and key.

## 1. Deliberate crossings

Every word listed in more than one category, with its categories, generated from the CSV. All are intentional.
The generator should treat each one as a herring between those categories.

- **Accordion**: instruments, things_with_keys
- **Amber**: gems, shades_of_yellow
- **Bacon**: breakfast_foods, meats
- **Bagel**: breakfast_foods, breads
- **Ball**: things_you_can_catch, words_after_fire
- **Balloon**: things_that_fly, toys, things_that_pop
- **Banana**: fruit, tropical_fruit, shades_of_yellow
- **Bank**: places_in_a_town, parts_of_a_river
- **Bark**: things_in_a_forest, animal_sounds
- **Basil**: herbs, pizza_toppings
- **Bed**: furniture, parts_of_a_river
- **Bee**: insects, things_with_stripes
- **Breath**: things_you_can_catch, things_you_can_draw
- **Bridge**: card_games, ways_across_a_river
- **Brush**: cleaning_kit, art_supplies
- **Bucket**: things_at_the_beach, cleaning_kit
- **Bun**: breads, hairstyles
- **Bus**: ways_to_travel, things_you_can_catch
- **Butter**: dairy, shades_of_yellow, words_before_fly
- **Button**: sewing_kit, things_that_pop
- **Calf**: body_parts, baby_animals
- **Canvas**: fabrics, art_supplies
- **Caramel**: sweets, shades_of_brown, ice_cream
- **Card**: things_in_a_wallet, things_you_can_draw, words_before_board
- **Carrot**: vegetables, things_with_roots, words_before_cake
- **Cat**: pets, words_before_fish
- **Chalk**: rocks, art_supplies
- **Cheese**: dairy, words_before_cake
- **Cherry**: fruit, shades_of_red
- **Chestnut**: nuts, shades_of_brown
- **Chicken**: farm_animals, birds, meats
- **Chin**: body_parts, parts_of_the_face
- **Chocolate**: shades_of_brown, ice_cream
- **Clam**: sea_creatures, things_with_shells
- **Cliff**: landforms, things_with_faces
- **Clock**: things_that_tell_time, things_with_faces, things_that_run
- **Cobalt**: metals, shades_of_blue
- **Cocoa**: drinks, shades_of_brown
- **Code**: things_you_can_crack, things_you_can_break
- **Coffee**: drinks, ice_cream
- **Coin**: things_in_a_wallet, things_with_faces, things_with_tails
- **Comet**: things_in_space, things_with_tails
- **Crab**: sea_creatures, things_at_the_beach, things_with_shells, words_before_cake
- **Cricket**: sports, insects
- **Crocodile**: reptiles, things_with_teeth
- **Cup**: on_the_table, words_before_cake, words_before_board
- **Date**: fruit, dried_fruit
- **Day**: units_of_time, words_after_sun
- **Delta**: landforms, phonetic_alphabet, parts_of_a_river
- **Denim**: fabrics, shades_of_blue
- **Disco**: dances, music_genres
- **Dog**: pets, words_before_house
- **Doll**: toys, words_before_house
- **Dragon**: mythical_creatures, words_before_fly
- **Eagle**: birds, golf_terms
- **Egg**: breakfast_foods, things_with_shells, things_you_can_crack, things_you_can_break
- **Elbow**: joints_in_the_body, body_parts
- **Emerald**: gems, shades_of_green
- **Eye**: parts_of_the_face, words_before_ball
- **Ferry**: boats, ways_across_a_river
- **Fig**: fruit, dried_fruit
- **Fire**: words_before_ball, things_you_can_catch, words_before_fly
- **Fly**: insects, words_after_fire
- **Foot**: body_parts, units_of_measure, words_before_ball
- **Fork**: on_the_table, garden_tools
- **Fudge**: sweet_treats, sweets
- **Garnet**: gems, shades_of_red
- **Ginger**: spices, things_with_roots
- **Giraffe**: safari_animals, things_with_necks
- **Glass**: on_the_table, words_before_house
- **Gold**: metals, shades_of_yellow, words_before_fish
- **Goldfish**: pets, fish
- **Golf**: sports, phonetic_alphabet
- **Green**: in_a_rainbow, golf_terms, kinds_of_tea, words_before_house
- **Guitar**: string_instruments, things_with_necks
- **Ham**: meats, pizza_toppings
- **Hat**: things_you_wear, things_with_crowns
- **Hearts**: card_suits, card_games
- **Horse**: farm_animals, words_before_fly
- **Indigo**: in_a_rainbow, shades_of_blue
- **Iris**: flowers, parts_of_the_eye
- **Iron**: metals, golf_terms
- **Jade**: gems, shades_of_green
- **Jasmine**: flowers, kinds_of_tea
- **Keyboard**: on_a_desk, things_with_keys
- **Kilo**: units_of_measure, phonetic_alphabet
- **King**: chess_pieces, royal_titles, things_with_crowns
- **Kite**: things_that_fly, toys, things_with_tails
- **Kiwi**: fruit, birds
- **Knee**: joints_in_the_body, body_parts
- **Knuckle**: joints_in_the_body, things_you_can_crack
- **Lamb**: farm_animals, meats, baby_animals
- **Laptop**: on_a_desk, things_with_keys
- **Lemon**: citrus_fruit, shades_of_yellow
- **Light**: words_before_house, words_after_fire, words_after_sun
- **Lima**: capital_cities, phonetic_alphabet
- **Lime**: citrus_fruit, shades_of_green
- **Lion**: big_cats, safari_animals, words_before_fish
- **Lobster**: sea_creatures, things_with_shells
- **Mango**: fruit, tropical_fruit, ice_cream
- **Marble**: toys, rocks
- **Mercury**: planets, metals, things_in_space
- **Milk**: drinks, dairy
- **Mint**: herbs, shades_of_green, ice_cream, kinds_of_tea
- **Mocha**: coffee_drinks, shades_of_brown
- **Moss**: things_in_a_forest, shades_of_green
- **Mountain**: landforms, things_with_faces
- **Mouse**: pets, on_a_desk
- **Mouth**: parts_of_the_face, parts_of_a_river
- **Mushroom**: pizza_toppings, things_in_a_forest
- **Mustard**: shades_of_yellow, sauces
- **Net**: sports_gear, words_before_ball
- **Nose**: parts_of_the_face, things_that_run
- **Olive**: pizza_toppings, shades_of_green
- **Onion**: vegetables, pizza_toppings, things_with_rings
- **Orange**: in_a_rainbow, citrus_fruit
- **Organ**: instruments, things_with_keys
- **Paint**: art_supplies, things_that_run
- **Palm**: trees, body_parts
- **Pan**: kitchen_tools, words_before_cake
- **Panama**: hats, countries
- **Paneer**: cheeses, dairy
- **Parrot**: pets, birds, words_before_fish
- **Peach**: fruit, shades_of_pink
- **Pen**: on_a_desk, animal_homes
- **Pepper**: pizza_toppings, spices
- **Piano**: instruments, things_with_keys
- **Pilot**: jobs, at_the_airport
- **Pin**: sewing_kit, words_before_ball
- **Pineapple**: pizza_toppings, tropical_fruit, things_with_crowns
- **Pistachio**: nuts, shades_of_green, ice_cream
- **Pixie**: hairstyles, mythical_creatures
- **Plane**: ways_to_travel, things_that_fly, things_with_tails
- **Poppy**: flowers, shades_of_red
- **Pound**: units_of_measure, currencies
- **Queen**: chess_pieces, royal_titles, things_with_crowns
- **Raft**: boats, ways_across_a_river
- **Rake**: garden_tools, things_with_teeth
- **Ribbon**: sewing_kit, things_you_can_tie
- **Rocket**: things_that_fly, things_in_space
- **Rose**: flowers, shades_of_pink
- **Ruby**: gems, shades_of_red
- **Saffron**: spices, shades_of_yellow
- **Sage**: herbs, shades_of_green
- **Salami**: meats, pizza_toppings
- **Salmon**: fish, shades_of_pink
- **Salsa**: dances, sauces
- **Sapphire**: gems, shades_of_blue
- **Saturn**: planets, things_with_rings
- **Saw**: things_in_a_toolbox, things_with_teeth
- **Scarf**: things_you_wear, things_you_can_tie
- **Shark**: sea_creatures, fish, things_with_teeth
- **Shell**: things_at_the_beach, words_before_fish
- **Shirt**: things_you_wear, things_with_necks, things_with_tails
- **Shower**: weather, in_the_bathroom
- **Skiing**: sports, winter_sports
- **Snow**: weather, words_before_ball, words_before_board
- **Sponge**: in_the_bathroom, cleaning_kit, words_before_cake
- **Squash**: sports, vegetables
- **Star**: shapes, things_in_space, words_before_fish
- **Sun**: things_in_space, words_before_fish
- **Swan**: birds, things_with_necks
- **Taco**: street_food, things_with_shells
- **Tadpole**: baby_animals, things_with_tails
- **Tango**: dances, phonetic_alphabet
- **Ticket**: at_the_airport, things_in_a_wallet
- **Tiger**: big_cats, things_with_stripes
- **Toffee**: sweet_treats, sweets, ice_cream
- **Tooth**: body_parts, things_with_roots, things_with_crowns
- **Tortoise**: reptiles, things_with_shells
- **Towel**: in_the_bathroom, things_at_the_beach
- **Tree**: things_with_rings, things_with_roots, things_with_crowns, words_before_house
- **Triangle**: instruments, shapes
- **Turnip**: vegetables, things_with_roots
- **Turquoise**: gems, shades_of_blue
- **Turtle**: reptiles, things_with_shells
- **Violet**: in_a_rainbow, flowers
- **Violin**: instruments, string_instruments
- **Waffle**: sweet_treats, breakfast_foods
- **Wasp**: insects, things_with_stripes
- **Watch**: things_you_wear, things_that_tell_time, things_with_faces
- **Wave**: things_at_the_beach, things_you_can_catch
- **Zebra**: safari_animals, things_with_stripes

### Parent and child categories (pair review)

A 10-word cap can't hold every member of a broad category. So for phantom-group and herring checks, treat a
child category's words as members of its parent too, and don't pair the two in a level:
- **Fruit** contains Citrus fruit, Tropical fruit and Dried fruit. Lime, Lemon, Orange, Apricot and others are fruit.
- **Body parts** contains Parts of the face, Joints in the body, Organs, Bones and Parts of the eye. Tooth roots,
  Hair and a toolbox Nail are body-ish too.
- **Things you wear** contains Hats and Footwear.
- **Instruments** contains String instruments.
- **Sports** contains Winter sports, and Golf terms are close.
- **Sweet treats** contains Sweets.
- **Drinks** contains Coffee drinks and Kinds of tea.
- **Dairy** contains Cheeses.
- **Things in space** contains Planets.
- **In a rainbow** and the Shades of red, yellow, green and blue share a hue each.
- **Never pair** because they overlap heavily:
  - Fish / Sea creatures (Cod and Tuna are sea fish)
  - Big cats / Safari animals (Leopard, Cheetah)
  - Boats / Ways to travel
  - Farm animals / Baby animals
  - Things that fly / Birds or Insects
  - Kitchen tools / Kitchen appliances / On the table
  - Rooms in a house / In the bathroom
  - Nuts / Things with shells
  - Things with keys / Instruments (shares Piano, Organ, Accordion)
  - Sea creatures / Things with shells (shares Crab, Lobster, Clam)
- **Animal-feature lateral categories** (teeth, shells, necks, spines, tails) need a pair review before they share a
  level with an animal category, because most animals have these features.

## 2. Contested words avoided

- **Fruit, vegetable or nut disputes:** Tomato, Avocado, Coconut, Peanut, Strawberry, Mushroom (kept only on
  pizza and in the forest, not in Vegetables).
- **Animal pedantry:** Spider, Bat, Koala, Orca, Turkey (also a country). Penguin, Flamingo, Canary, Seagull
  and Albatross were left out because Birds is full and they would sit unflagged elsewhere. Anchovy is out
  because Fish is full. Duck and Goose left Farm animals so it shares only Chicken with Birds.
- **Places:** China and Congo are ambiguous.
- **US/UK words:** Chips/Crisps, Cookie/Biscuit, Jelly, Pants, Jumper, Torch, Trainer/Sneaker, Eraser/Rubber,
  Zip/Zipper, Fringe/Bangs, Plait, Boot or Trunk (as car parts), Yard, Soda, Lemonade, Ladybird/Ladybug,
  Sultana, Prawn/Shrimp. Porridge (US says oatmeal) became Granola.
- **Spelling variants:** Grey, Yoghurt, Doughnut, Lasagne, Chilli, Omelette, Coriander/Cilantro,
  Aubergine/Eggplant, Courgette/Zucchini, Metre, Litre, Tonne, Racket/Racquet, Kebab/Kabob, Caddie/Caddy,
  Chamomile/Camomile, Lychee/Litchi, Liquorice. No label uses "colour" or "flavour".
- **Clue substrings:**
  - Within a category: Butterfly (Fly), Cupcake (Cake), Milkshake (Milk), Dustpan (Duster),
    Stopwatch (Watch), Pencil (Pen), Princess (Prince), Platinum (Tin).
  - Plural clashes across categories: Spade or Diamond vs the suits, Rock vs the Rocks label, Ears vs Ear.
- **Taste:**
  - Alcohol: Gin, Rum, Wine, Burgundy.
  - Weapons: Arrow, Sword, Stiletto, Pike, Knife.
  - Slang or slurs: Cracker, Tart, Bogey, Uranus.
  - Religion: Angel, Monk, Cardinal, Turban, Cross.
  - Trademarks: Frisbee, Velcro, Nylon, Stetson, Visa, and branded board games.

## 3. Unsure

- **Card suits** has only 4 words (Hearts, Spades, Clubs, Diamonds) and breaks the 6–10 rule. Hearts crosses
  Card games, and Heart (Organs) is a deliberate near-duplicate. The same goes for Blue (rainbow) and Blues
  (genre).
- **Fruit** was harvested with 9 words (Apple, Pear, Plum, Mango, Lime, Fig, Date, Banana, plus Kiwi) and needs
  Peach and Cherry for its colour crossings. Lime moved to Citrus fruit, which is a child of Fruit, to stay
  under 10.
- **Tier changes from the level files:**
  - Things with keys moved from 2 to 3, following the brief.
  - Gems, Dog breeds and Spices moved from the default to 2.
  - Coffee drinks and Cheeses stay at 1, but Macchiato, Cortado and Camembert are harder words.
- **Harvested labels and words left as they are, with mild risk:**
  - Sweets ("candy" in the US).
  - Wrench (UK says spanner).
  - Mohawk (the name of an Indigenous nation).
  - Bishop (a religious title).
  - Ford, Amazon, Jaguar, Puma and Lynx (also brands).
  - Keyboard (contains "key").
  - Bee and Beetle (in one category).
  - Joints and crack (also drug slang).
- **Ice cream:** the label avoids "flavours", so its key is "cream". Ice cream desserts such as Sundae were
  kept out of the bank.
- **Phonetic alphabet** is tier 3 as a code rather than a true lateral category. It might be tier 2.
- **Borderline members:**
  - Coral (an animal) in Shades of pink.
  - Urchin in Things with spines (it's also a sea creature).
  - Den (a US room) in Animal homes.
  - Fairy (dated slur).
  - Knight (a rank, not a royal title).
  - Pretzel (could be a bread).
  - Fruit and House as members of Words before fly.
- **Thin domains:** drink, music, people and time have 3 categories each.
