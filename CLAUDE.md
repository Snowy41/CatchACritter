# Catch a Critter – Project Context

Roblox kids' game (target 100–200 CCU). Full game design document: `Catch a Critter – Game Design Document.md` in this folder
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
- Everything is designed and built in Roblox Studio from parts (decided 2026-10-27 after comparing a Blender mesh bunny with a parts bunny — user preferred parts). No Blender, no meshes: critters, guardians and props are parts only.
- Critter style ("cool but kid-friendly", reference: `CritterLab.Import.CloverBun_Cool`): chamfered blocks (3 overlapping boxes), big head, low sprint-ready pose, big disc eyes, angular swept ears/fins with dark tips, dark contrast markings (chevrons, stripes, emblem on forehead), small spiky crest. Cute-only designs read as boring.
- Every species gets its OWN face and personality — never reuse one face template. Clover Bun = cool/determined (half lids, angled brows, teal iris, smirk with one tooth); Buzzpup (`CritterLab.Import.Buzzpup`, Meadow bee-pup) = hyper/cheerful (glossy black bug eyes with amber rim, brow dots, open grin with fangs, tongue out, fluttering wings in its idle).
- Studs: Roblox stud surfaces are 1 stud and invisible at critter scale — use mini studs (tiny cylinders, ~0.13 diameter) on top faces of head and back.
- Rig: anchored invisible RootPart, Motor6D joints named Body, Head, EarL, EarR, Sprout (crest/antennae), Tail (+ extra joints like WingL/WingR), WeldConstraints inside each group, KeyframeSequence "Idle" inside the model (DevLabAnimator plays it in the lab). When moving welded parts afterwards, build pieces at their final place first and weld last (moving a weld's Part0 drags its welded parts).
- Neon = rarity signal: none on Common, glow lines from Epic upward.
- Budgets: critters ~80–120 parts, guardians ~150–250 parts; zone props built once as reusable templates.
- Each model: one Model, welded, with a PrimaryPart. Small detail parts: CanCollide off, CastShadow off.

## Code workflow (Rojo + git)
- Git repo in this folder (branch `main`). Rojo 7.7.0-rc.1 via Aftman (`aftman.toml`); start with `rojo serve default.project.json` (port 34872), user connects with the Rojo plugin in Studio.
- Rojo manages only code: `src/server` → ServerScriptService, `src/client` → StarterPlayerScripts, `src/shared` → ReplicatedStorage.Shared. All service nodes use `$ignoreUnknownInstances`, so map, lab, critter models and MapTemplates stay in the place file and are never touched.
- Edit synced scripts as files in `src/` (never in Studio — Rojo overwrites them). Map, critters and other geometry are built in Studio via the MCP.
- Naming: `*.server.luau` = Script, `*.client.luau` = LocalScript, `*.luau` = ModuleScript.
- Editing `default.project.json` while Rojo is connected duplicates synced instances (old copies survive because of `$ignoreUnknownInstances`). After a project-file change: delete the synced scripts in Studio, have the user disconnect + reconnect Rojo, then check for duplicates.
- `tools/receive_sources.py`: one-shot localhost receiver to export script sources from Studio into `src/` (Studio POSTs with HttpEnabled toggled on/off in the same call).

## Current status
- Roblox Studio MCP works in Claude Code (verified 2026-10-26). Place "Catch a Critter" (placeId 130712981203933).
- Map v1 built 2026-10-27 in `Workspace.Map` (path runs toward -Z, 1 stud = 1 unit): StartHub (spawn plaza z≈52), Avenue + 8 Bases (z 0..-240, x ±50), Meadow (-240..-680), Swamp (-680..-1120, gate Speed 1), Volcano (-1120..-1600, gate Speed 2), Crystal Cave gate at -1600 (locked, Rebirth 1). Prop templates in `ServerStorage.MapTemplates`. Players will later spawn in their own plot (not at the plaza). Gameplay hooks via CollectionService tags: BasePlot, CritterSlot, CoinPad, ZoneGate, NestSpot, GuardianSpot, Hazard, CritterSpawnArea, SafeZone, ShopStall, ScheduleBoard. `ZoneAmbience` (client) blends atmosphere per zone. Lighting.Technology can't be set via MCP (set manually).
- Critter Lab (Studio-only test area) at X=2500: `Workspace.CritterLab` (8 spinning display pedestals, scale refs, base-slot replica, fenced TestMeadow). Drop models into `CritterLab.Import` → placed on pedestals in Play. Workspace attribute `DevStartInLab` spawns you there; blue/green pads teleport map↔lab. `DevLab` (server) destroys the lab in live servers. Current models: CloverBun_Studio (first parts version), CloverBun_Cool (style reference), Buzzpup.
- Lighting: high-saturation kid grade (ColorCorrection sat 0.38, contrast 0.14, Brightness 2.8); ZoneAmbience presets match. Perf: 53 active PointLights, ~2.1k shadow casters, landscape/landmark models Persistent; set StreamingTargetRadius 600 / MinRadius 200 manually (not scriptable).
- Core loop prototype done 2026-10-27 (tested in Play): Main.server + Services (DataService, PlotService, CritterService, CritterModels, BaseService, ShopService), shared Config/CritterDefs/Icons, client Hud + UIKit + Gates + CritterAnimator, Remotes defined in default.project.json. Critter templates in `ServerStorage.CritterTemplates` (CloverBun = copy of CloverBun_Cool, Buzzpup). Player state replicated via player attributes (Coins, IncomePerSecond, SpeedLevel, Carrying, CarryingRarity, PlotId, TotalCatches).
- UI icons: licensed "Free Icon Pack v3.1 (Basic)" in this folder (gitignored, never commit/redistribute); used icons are uploaded to Roblox, ids in `src/shared/Icons.luau`. HUD style: UIKit (3D buttons, dark gradient pills with overlapping icon, LuckiestGuy for numbers/buttons, FredokaOne for text, per-area UIScale).
- Idle animations play via KeyframeSequenceProvider (Studio only) — before launch upload each Idle and set model attribute IdleAnimationId.
- Next step: Meadow guardian Bramblebear with nest + wake-up meter (snatching from NestSpot, chase, drop on bump), then rarer spawns/announcements and the first-60-seconds onboarding.
