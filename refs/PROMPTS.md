# Reference Image Prompts (for Gemini)

Pipeline: critter and guardian **bodies are low-poly meshes**; **eyes, neon rarity lines and accessories are Roblox parts** on top. The images are references for modeling the meshes, so they need clean, readable views, not pretty renders.

## How to use
1. Generate **#1 Style Sheet** first and regenerate until you like it. It sets the look for everything else.
2. Attach the chosen style sheet to every later prompt. For #3 also attach #2; for #5 and #6 also attach #4.
3. Gemini likes to add text labels, and they're often wrong. If it does, add: "No text, no labels, no logo."
4. Don't worry about exact size or colors: I fix those in Studio. What matters is **shape, proportions and silhouette**.
5. Save into this `refs/` folder:
   `01_style_sheet.png`, `02_cloverbun_turnaround.png`, `03_cloverbun_rarities.png`, `04_bramblebear_turnaround.png`, `05_bramblebear_states.png`, `06_nest.png`, `07_meadow_mood.png`, `08_base_plot.png`

**What makes an image usable:**
- One subject, or a few clearly separated ones
- Plain light grey background, flat even lighting, almost no shadows
- Clearly visible flat facets: low-poly, not smooth
- Eyes as separate flat discs, neon as separate thin strips (these become parts)

Characters for the style test:
- **Clover Bun**: Common Meadow critter, a chubby bunny with clover-leaf ears.
- **Bramblebear**: Meadow guardian, a huge sleepy bear made of hedge with a flower crown.

---

## 1. Style Sheet (16:9)

```
3D game asset style sheet for a kids' Roblox game. Five small creature models standing in one row on a plain light grey background, evenly spaced, plus a classic blocky Roblox avatar (yellow head, blue torso, green legs) standing at the far right for scale. No text, no labels, no logo.

Style: low-poly faceted 3D models with clearly visible flat triangular facets and flat shading, crisp hard edges, about 800 triangles each. Chunky and slightly angular, but very cute and kid-friendly: oversized head, small round body, four short stubby legs. Huge eyes made of separate flat round discs stuck onto the face (dark brown iris, black pupil, two white highlight dots). Small pink blush patches. Bright saturated matte colors, no fur, no gradients.

From left to right:
1. A cream-colored bunny (#FFF4D6) with two tall ears shaped like green clover leaves (#A8E65A), brown belly patch.
2. A yellow-and-black striped bee-pup (#FFD23F) with small flat light-blue wings.
3. A hedgehog with spikes made of brown faceted cones and a red mushroom cap with white spots on its head.
4. A red ladybug with black round spots and two small green leaves on its back.
5. The same cream bunny as #1, as the "Epic" version: identical colors and shape, but with thin glowing purple neon strips (#B04BFF) running along the edges of its ears, back and feet. The body itself stays cream, NOT purple, NOT transparent.

Each creature is about half as tall as the avatar. A subtle flat printed Roblox stud pattern (flat, not raised bumps) on the top of each creature's back only. Even soft studio lighting, minimal shadows, slight three-quarter front view. Avoid: smooth sculpted vinyl-toy look, plush, fur, Pixar style, raised LEGO studs, text.
```

---

## 2. Clover Bun – Turnaround (16:9)

```
Match the style of the attached image exactly.

Character turnaround sheet of one low-poly 3D creature model, "Clover Bun". Four views of the same model in one row, same size and same ground line, on a plain light grey background: front view, left side view, back view, and three-quarter front view. Orthographic, no perspective, flat even lighting, no shadows. No text, no labels.

Design: a chubby cream bunny (#FFF4D6) in a neutral standing pose on all four short stubby legs. Head bigger than the body. Two tall ears shaped like three-leaf clover leaves in light green (#A8E65A) with darker green (#6BCB3D) veins. Warm brown (#A0673A) belly patch. Small round puff tail. Huge eyes made of separate flat round discs on the face, tiny pink nose, small happy mouth, pink blush patches.

Low-poly with clearly visible flat facets and hard edges, about 800 triangles. Clean, symmetrical silhouette. A subtle flat printed stud pattern on the top of the back only. No glow (this is the Common version). Avoid: fur, smooth sculpted shapes, raised studs, text.
```

---

## 3. Clover Bun – Rarity Variants (16:9)

```
Match the style of the attached images exactly (style sheet and Clover Bun turnaround).

The same low-poly bunny model "Clover Bun" shown five times in a row, three-quarter front view, same pose and same shape every time, on a plain light grey background. Only colors and small add-ons change. No text, no labels.

1. Common: cream body, green clover ears, no glow, nothing extra.
2. Uncommon: soft mint green body, one small flower on an ear, no glow.
3. Rare: sky blue body (#7FD3FF) with white spots, a small four-leaf clover on its head, no glow.
4. Epic: lavender body with thin glowing purple neon strips (#B04BFF) along the edges of ears, back and feet, glowing purple eye highlights.
5. Legendary: white and gold body with thin glowing gold neon strips (#FFB21F) along the edges, a small floating golden clover crown above its head, a few tiny glowing gold cubes floating around it.

The neon strips are thin separate lines on the surface, never the whole body glowing. Each version must look clearly more special than the previous one from far away. Flat facets, flat shading, even lighting. Avoid: transparent bodies, whole-body glow, fur, text.
```

---

## 4. Bramblebear – Turnaround (16:9)

```
Match the style of the attached image exactly.

Character turnaround sheet of one large low-poly 3D creature model, "Bramblebear", the giant guardian of the Meadow zone. Four views in one row, same size and same ground line, on a plain light grey background: front view, left side view, back view, three-quarter front view. Orthographic, no perspective, flat even lighting, no shadows. A classic blocky Roblox avatar stands next to the front view; the bear is about four times as tall. No text, no labels.

Design: a huge, round, grumpy-cute bear standing on all fours in a neutral pose. Its body is a trimmed hedge made of chunky faceted green leaf clusters (#6BCB3D, #A8E65A) over warm brown wood (#A0673A) visible at the paws, snout and belly. Big round head, small round ears, a crown of chunky yellow (#FFD23F) and pink (#FF8FB1) flowers on top. Large sleepy eyes made of separate flat discs with heavy eyelids. Big rounded snout, no visible teeth. Thick stubby legs, big flat paws with no claws.

Low-poly with clearly visible flat facets and hard edges, about 3,000 triangles. Friendly, not scary. Avoid: teeth, claws, angry face, fur, smooth sculpted shapes, text.
```

---

## 5. Bramblebear – Sleep and Wake States (16:9)

```
Match the style of the attached images exactly (style sheet and Bramblebear turnaround).

The same low-poly bear model "Bramblebear" in three poses in one row, three-quarter front view, on a plain light grey background. No text, no labels.

1. Asleep: lying on its belly, head resting on its crossed front paws, eyes closed, flower crown slightly tilted, small blocky "Z" shapes floating above its head.
2. Waking up: sitting up, one eye half open, one ear raised, a big yellow exclamation mark floating above its head.
3. Awake and chasing: running forward on all fours, eyes wide open, cheeks puffed, a few leaves flying off its body. Funny and cartoonish, not scary.

Flat facets, flat shading, even lighting. Avoid: teeth, claws, snarling, text other than the Z shapes.
```

---

## 6. Guarded Nest (16:9)

```
Match the style of the attached images exactly (style sheet and Bramblebear turnaround).

Low-poly 3D game scene: a guarded nest in a sunny meadow, three-quarter view from slightly above. No text, no labels.

A big round nest made of chunky warm brown (#A0673A) wooden sticks and blocks, lined with green leaves and a few pink and yellow flowers, about as wide as two Roblox avatars. Inside sit three small low-poly bunnies: one Epic bunny with thin glowing purple neon strips along its edges and two plain sky blue Rare bunnies. Next to the nest, the giant Bramblebear guardian lies curled up asleep with "Z" shapes above its head. A classic blocky Roblox avatar sneaks toward the nest on tiptoes. A faint circle on the grass around the nest marks the danger zone. Short faceted grass tufts and flowers around.

Flat-shaded low-poly style with visible facets, bright daylight, soft shadows. Avoid: dark mood, scary elements, text.
```

---

## 7. Meadow Zone Mood – Path and Base Row (16:9)

```
Match the style of the attached image.

Low-poly 3D environment concept for the start area and first zone of a kids' Roblox game. High three-quarter view looking down a long, straight, wide path that runs away from the camera toward the horizon. No text, no labels.

Foreground: the start area. Four player base plots on each side of the path, all facing it. Each plot is a square fenced pen with a small cute cabin, a few small critters inside, and a glowing gold coin pad at the front.
Middle: the path becomes a light dirt lane with grey stone edges entering the Meadow zone: rolling faceted green hills (#6BCB3D, #A8E65A), chunky low-poly trees, giant flowers, small round critters wandering. A big wooden arch covered in flowers spans the path at the Meadow entrance.
Background: further down the path, a second darker arch, and behind it a misty purple-green swamp in the distance.

Bright sunny day, sky blue (#7FD3FF) with chunky faceted clouds, warm soft light. Clean, readable, uncluttered, inviting for kids aged 5–12. Avoid: realistic textures, dark mood, text.
```

---

## 8. Base Plot (4:3)

```
Match the style of the attached image.

Low-poly 3D concept of one player base plot in a kids' Roblox game, three-quarter view from slightly above, plain light grey background around it. No text, no labels.

A square grass plot with a low chunky wooden fence (#A0673A) and an open gate at the front. Inside: six round stone pedestals in two rows of three. Four of them have small cute low-poly critters on them (one with thin purple neon strips); two are empty with a faint glowing "+" symbol. At the back, a small cozy cabin with an empty sign board above the door. At the front next to the gate, a round coin pad with a stack of gold coins and a soft yellow glow. A colored banner pole marks the owner. A few flowers and bushes inside the fence.

Simple, chunky shapes, flat-shaded with visible facets, bright even lighting. Avoid: realistic textures, text.
```
