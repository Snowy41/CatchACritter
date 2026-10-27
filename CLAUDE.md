# Catch a Critter – Project Context

Roblox kids' game (target 100–200 CCU). Full game design document: `GDD.md` in this folder
(online version: https://claude.ai/artifact/7XTVRhyH7qwZs7PsyosoMf).

## Core decisions (already agreed)
- Loop: run down a linear path → chase and catch fleeing critters → carry home → base earns coins → upgrade/rebirth → go deeper.
- NO stealing between players. Tension comes from guarded nests: sleeping zone guardians wake up (wake-up meter) and chase you; if they bump you, you drop the critter. Bases are always safe.
- Rarities: Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret, Forgotten. Mutations (Shiny, Giant, Tiny, Golden, plus weather mutations Rainbow, Frozen, Lava, Ghost) and a size roll.
- Zones: Meadow, Swamp, Volcano (launch), Crystal Cave (week 1), Sky Isles (later).
- Weather mutates critters in your base only while you're online (FOMO through rewards, never penalties for being offline).
- Weekly updates on Friday evening (EU time). Launch late Nov / early Dec 2026, first to 16+ players, then Kids/Select after 100 Highly Engaged Players.
- Compliance: no watch-to-earn feeds, no rewarded ads for under-13s, content rating Minimal/Mild, everything works without chat.

## Art and modeling rules
- Parts-only again (decided 2026-10-27 after comparing a Blender mesh bunny with a parts bunny in the Critter Lab — user preferred parts): critters, guardians and props are built from Roblox parts in Studio. Blender is no longer used for critters.
- Critter style ("cool but kid-friendly", reference: `CritterLab.Import.CloverBun_Cool`): chamfered blocks (3 overlapping boxes), big head, low sprint-ready pose, big disc eyes with coloured iris + half lids + angled brows, smirk with one tooth (no gaping mouth), angular swept ears/fins with dark tips, dark contrast markings (chevrons, stripes, emblem on forehead), small spiky crest. Cute-only designs read as boring.
- Every species gets its OWN face and personality — never reuse one face template. Clover Bun = cool/determined (half lids, angled brows, smirk); Buzzpup (`CritterLab.Import.Buzzpup`, Meadow bee-pup) = hyper/cheerful (glossy black bug eyes with amber rim, brow dots, open grin with fangs, tongue out, fluttering wings in its idle).
- Studs: Roblox stud surfaces are 1 stud and invisible at critter scale — use mini studs (tiny cylinders, ~0.13 diameter) on top faces of head and back.
- Rig: anchored invisible RootPart, Motor6D joints named Body, Head, EarL, EarR, Sprout (crest/antennae), Tail (+ extra joints like WingL/WingR), WeldConstraints inside each group, KeyframeSequence "Idle" inside the model (DevLabAnimator plays it in the lab).
- Neon = rarity signal: none on Common, glow lines from Epic upward.
- Budgets: critter body mesh ~500–1,500 triangles + 10–30 parts; guardian mesh ~2,000–5,000 triangles + 20–60 parts; zone props built once as reusable templates.
- Each model: one Model, welded, with a PrimaryPart. Small detail parts: CanCollide off, CastShadow off.

## Current status
- Roblox Studio MCP works in Claude Code (verified 2026-10-26). Place "Catch a Critter" (placeId 130712981203933).
- Map v1 built 2026-10-27 in `Workspace.Map` (path runs toward -Z, 1 stud = 1 unit): StartHub (spawn plaza z≈52), Avenue + 8 Bases (z 0..-240, x ±50), Meadow (-240..-680), Swamp (-680..-1120, gate Speed 1), Volcano (-1120..-1600, gate Speed 2), Crystal Cave gate at -1600 (locked, Rebirth 1). Prop templates in `ServerStorage.MapTemplates` (part-built; user decided 2026-10-27 they stay parts, no Blender needed for props). Players will later spawn in their own plot (not at the plaza). Gameplay hooks via CollectionService tags: BasePlot, CritterSlot, CoinPad, ZoneGate, NestSpot, GuardianSpot, Hazard, CritterSpawnArea, SafeZone, ShopStall, ScheduleBoard. `StarterPlayerScripts.ZoneAmbience` blends atmosphere per zone. Lighting.Technology can't be set via MCP (set manually).
- Critter Lab (Studio-only test area) at X=2500: `Workspace.CritterLab` (8 spinning display pedestals, scale refs, base-slot replica, fenced TestMeadow). Drop models into `CritterLab.Import` → placed on pedestals in Play. Workspace attribute `DevStartInLab` spawns you there; blue/green pads teleport map↔lab. `ServerScriptService.DevLab` destroys the lab in live servers.
- Clover Bun comparison (2026-10-27): Blender version rigged (bones Root/Body/Head/EarL/EarR/Sprout/Tail, rigid skinning, palette texture, 3 s "Idle" action) → `models/export/CloverBun.fbx` via `tools/clover_bun_rig.py`; must be imported by hand (Import 3D) into `CritterLab.Import` for a permanent mesh asset. Lab shortcut (no Import 3D): `tools/export_rig_to_luau.py` → `tools/cloverbun_data.lua` → `ReplicatedStorage.DevLabData.CloverBunData` (fetched once via localhost with HttpEnabled toggled on/off in the same call); `DevLabData.SkinnedMeshBuilder` builds a skinned EditableMesh MeshPart + Bones + KeyframeSequence "Idle"; `StarterPlayerScripts.DevLabMeshCritters` rebuilds it on Display2 in Play (needs Game Settings → Security → "Allow Mesh / Image APIs"). `AssetService:CreateAssetAsync` is not available yet (can't upload meshes from scripts). Studio version `CritterLab.Import.CloverBun_Studio` (75 parts, Motor6D rig with the same joint names, KeyframeSequence "Idle"). `StarterPlayerScripts.DevLabAnimator` plays KeyframeSequence/AnimationClip found in lab models (Studio only).
- Lighting: high-saturation kid grade (ColorCorrection sat 0.38, contrast 0.14, Brightness 2.8); ZoneAmbience presets match. Perf: 53 active PointLights, ~2.1k shadow casters, landscape/landmark models Persistent; set StreamingTargetRadius 600 / MinRadius 200 manually (not scriptable).
- Blender: official Blender Lab MCP (Blender 5.2, bridge on localhost:9876). Clover Bun v2 in `models/clover_bun.blend`; build scripts in `tools/`.
- Reference images go in `refs/` in this folder; Gemini prompts for them are in `refs/PROMPTS.md`.
- Style-test characters: Clover Bun (Common Meadow critter), Bramblebear (Meadow guardian).
- Next step: style test in Studio — one Meadow critter, the Meadow guardian, one nest, a slice of the path with the base row. User reviews, then build the full roster and map zone by zone.
- User will provide AI-generated reference images: style sheet, turnarounds per critter/guardian, rarity variants, zone mood images.
