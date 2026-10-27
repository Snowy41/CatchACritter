# Catch a Critter – Game Design Document

Oct 26, 2026 · @t

## Overview

Catch a Critter is a kids' Roblox game where players chase fleeing critters down a linear path, snatch rare ones from under the nose of sleeping zone guardians, and carry them home to earn coins. There is no stealing between players. The target is a steady 100–200 CCU, reached through a first session that hooks within 60 seconds and weekly updates that bring players back.

**One-line pitch:** Run deeper, catch rarer critters, protect your collection, and never miss a Legendary spawn.

**Target audience:** kids aged 5–15 on Roblox Kids and Select accounts. At launch the game is limited to players 16+, who are the first audience until the game qualifies (see Roblox platform rules).

### Design pillars

| Pillar | What it means in practice |
| --- | --- |
| Understood in 10 seconds | One verb (catch), one direction (deeper = rarer), one goal (fill your base) |
| Hooked in 60 seconds | First catch, first coins, first upgrade and first Rare spawn all happen inside the first minute |
| Every run is a gamble | Rarity, mutation and size rolls on every critter; server-wide announcements for big spawns |
| Something is always about to happen | Weather, scheduled spawns, admin events and a weekly update create anticipation |
| Social, even without chat | Summoning rituals, trading, base showcases and shared Legendary chases work through actions, emotes and pings |
| Built for 28-day retention | Long-term goals (Critterdex, rebirth, eggs, pass) instead of one-session burnout |

### Inspiration and difference

The game takes the snatch-and-run structure of Steal An Egg (grabbing eggs from guarded spots on the map), the collect-and-earn base of Steal a Brainrot, the weather-mutation system of Grow a Garden 2, and the admin events of Fish It. The new core is that critters run away and fight back: catching is an active chase whose difficulty rises with rarity. We deliberately leave out stealing from other players, so nobody loses what they caught.

## Market research (October 2026)

The "steal and collect" formula leads Roblox in 2026. [Steal An Egg](https://www.player.one/robloxs-steal-egg-beating-some-platforms-biggest-games-164086) launched in July 2026 and reached about 1.3 million concurrent players by September 9, ahead of Brookhaven RP and Blox Fruits. Other 2026 hits include Steal a Brainrot, Grow a Garden 2, Fish It, 99 Nights in the Forest and Kick a Lucky Block.

| Game | What we borrow | Why it works |
| --- | --- | --- |
| [Steal An Egg](https://www.player.one/robloxs-steal-egg-beating-some-platforms-biggest-games-164086) | Linear biome runs, steal → hatch → earn → upgrade, rarer eggs take longer to hatch | Goal understood immediately; stealing adds social tension; suits short sessions |
| [Steal a Brainrot](https://www.eldorado.gg/blog/steal-a-brainrot-en/steal-a-brainrot-update-log/) | Update almost every Saturday; rituals; RNG machine; [grief shields](https://allthings.how/steal-a-brainrot-events-schedule/); rebirth levels | Weekly drops give a fixed reason to return; rituals make players cooperate |
| [Grow a Garden 2](https://esports.gg/guides/roblox/all-mutations-and-multipliers-grow-a-garden-2/) | Weather events that mutate what you already own | Being online when weather hits pays off, so players stay or return |
| [Fish It](https://www.gosugamers.net/entertainment/news/78347-roblox-fish-it-launches-retro-island-update-with-new-forgotten-and-secret-species) | Admin events, limited mutations, tiers above Secret (Forgotten), free battlepass | Rare spawns create stories and clips; a pass supports long-term play |

**Lessons for us**

- A clone with a new skin is not enough: the market is crowded with steal-and-grow games. One core verb has to change, which for us is the chase.
- Weekly updates on a fixed day are the strongest return driver on the platform.
- Mutations and weather turn waiting time into excitement.
- Many top games skip redeem codes and rely on events instead.
- New hits rise and fade quickly, so the update pipeline matters as much as launch.

## Roblox platform rules (2026)

Kids can only find the game once it qualifies for the Roblox Kids and Select catalogs, so these rules shape the whole launch.

| Rule | What it means for us |
| --- | --- |
| [Age-based accounts](https://www.techloy.com/roblox-to-launch-kids-accounts-in-major-pivot-following-child-safety-pressure/): Kids (5–8) and Select (9–15). Kids accounts see only "Minimal" or "Mild" games, with communication off by default | Keep the content rating at Minimal or Mild. Every social feature must work without chat |
| [Creator requirements](https://youthsportsbusinessreport.com/roblox-rolls-out-age-based-accounts-and-expanded-parental-controls-for-users-under-16/): ID verification, two-step verification, Roblox Plus subscription | Set up on the publishing account before launch |
| [Highly Engaged Player (HEP) threshold](https://zehn-studio26.com/news/kids-and-select-hep-threshold-relaxed/): drops from 250 to 100 in November 2026 (announced at RDC26). A HEP is an age-checked 16+ user who [spent money on Roblox](https://x.com/Bloxy_News/status/2074264204337709491) in the last 60 days | Before qualifying, only 16+ players and trusted friends can play. We need 100 of them within 60 days |
| [Maintenance bar](https://devforum.roblox.com/t/highly-engaged-player-threshold-drops-to-250/4820164): 25 HEPs to stay in Kids and Select | Easy to keep once in |
| [Expedited review](https://create.roblox.com/docs/production/publishing/kids-and-select): refundable 100,000 Robux fee skips the HEP requirement | Not needed; organic route is planned |
| [Reward-feed ban](https://shattered.io/roblox-doomscroll-games-ban-kids-select-2026/) (Aug 25, 2026): no media feed + autoplay/scroll + reward for continued viewing. Steal An Egg was pulled for its treadmill video feed | We never build watch-to-earn mechanics of any kind |
| [Ads for under-13s](https://www.dzrh.com.ph/post/roblox-to-overhaul-ad-policies-introduce-revenue-sharing-in-2027): rewarded ad formats prohibited | Monetize with passes and products, not ads |
| [Discovery](https://longportapp.cn/topics/43104889): recommendations moved from 7-day monetization to 28-day retention | Design for players returning over weeks, not just a strong first day |

## Core gameplay loop

The whole game fits in one sentence: run deeper, catch a critter, bring it home, earn coins, get stronger, run deeper again.

&#91;embedded content: core loop · 5 steps\]

1. **Run** down the linear path toward deeper zones.
2. **Chase and catch** a critter; rarer critters flee, hide or teleport.
3. **Snatch from a guarded nest** for the rarest critters, without waking the zone's guardian.
4. **Carry it home**, moving slower with rarer critters, while an awakened guardian chases you.
5. **Place it in your base**, where it earns coins every second. Weather can mutate it while you're online.
6. **Upgrade and rebirth** to run faster, catch better and unlock deeper zones.

A single loop takes about 30–90 seconds early on, so even a short session gives several rewards.

## Map and zones

The map is one straight path: player bases line both sides of the start area, and the path runs away from them through zones that get rarer and more dangerous the deeper you go. Kids need no map screen; forward means better critters, back means home.

**Layout**

- **Base row:** about 8 base plots facing the path, so every base is visible from the start area for showing off collections.
- **The path:** a wide lane with zone gates. Each gate needs a speed or rebirth level to pass, which gives upgrades a clear meaning.
- **Return trip:** carrying a critter slows you down, and if you woke a guardian it chases you home. This is the tense part of every run.
- **Signposting:** a glowing arrow on first join, zone names on big arches, and rarity colors on the ground of each zone.

| Zone | Unlock | Typical rarities | Hazard | Launch? |
| --- | --- | --- | --- | --- |
| 1. Meadow | Start | Common, Uncommon | None | Yes |
| 2. Swamp | Speed upgrade 1 | Uncommon, Rare | Mud slows you | Yes |
| 3. Volcano | Speed upgrade 2 | Rare, Epic | Lava bursts knock you back | Yes |
| 4. Crystal Cave | Rebirth 1 | Epic, Legendary | Dark patches, falling crystals | Week 1 update |
| 5. Sky Isles | Rebirth 2 | Legendary, Mythic | Gaps and wind | Later update |

Events can add a temporary zone (for example a Winter zone at launch week), and Mythic and Secret critters appear only during events, summons or admin spawns.

## Critters

Every critter gets four random rolls when it spawns: species (by zone), rarity, mutation and size. Rarer critters are harder to catch because they behave differently, which turns every Legendary into a chase worth recording.

### Rarity tiers and behavior

Spawn rates and income values are placeholders for balancing.

| Rarity | Behavior when you approach | Carry speed | Where | Spawn share (draft) |
| --- | --- | --- | --- | --- |
| Common | Wanders, easy to catch | Normal | Meadow and up | 55% |
| Uncommon | Hops away a short distance | Normal | Meadow and up | 25% |
| Rare | Flees when you get close | Slightly slower | Swamp and up | 13% |
| Epic | Hides or burrows, pops up nearby | Slower | Volcano and up | 5% |
| Legendary | Teleports around the zone; server-wide announcement | Much slower | Crystal Cave and up | 1.8% |
| Mythic | Event-only; needs a special net | Much slower | Events | 0.2% |
| Secret | Admin events and summons only | Crawl | Events, summons | Special |
| Forgotten | Above Secret; summons and admin events only | Crawl | Summons | Special |

### Mutations

Mutations multiply a critter's income and change its look. A critter can carry one natural mutation plus one weather mutation (Grow a Garden 2 lets weather mutations stack with non-weather ones, which keeps old critters valuable).

| Mutation | Source | Look | Multiplier (draft) |
| --- | --- | --- | --- |
| Shiny | Natural roll | Sparkle | x2 |
| Giant | Natural roll | Double size | x3 |
| Tiny | Natural roll | Half size | x3 |
| Golden | Natural roll, rare | Gold body | x10 |
| Rainbow | Rainbow Storm weather | Cycling colors | x20 |
| Frozen | Snowstorm weather | Ice shell | x8 |
| Lava | Solar Flare weather | Glowing cracks | x12 |
| Ghost | Blood Moon weather | See-through, red eyes | x25 |
| Event-limited (for example Winter, Spooky) | Only during that event | Themed | x15–x40 |

### Size roll

Every critter gets a random size shown as a number on its nameplate (for example "4.7 kg"). It slightly changes income and gives players something to compare and brag about.

### Catching

- Walk up and press the catch button; a 1–2 second timing bar appears.
- Commons have a wide sweet spot; rarer critters have a narrower bar and keep moving.
- Better nets widen the bar and add a second attempt.
- Mythic and higher need event nets.
- Very young players can rely on Commons and Uncommons, whose bars are hard to miss.

### Art direction

Cute, round, bright critters with clear silhouettes, so rarity and mutation read instantly from a distance and in a phone-sized video clip. A few absurd "meme" critters per update (silly names, funny animations) give clip-worthy moments for the teen launch audience.

## Base, income and guardians

The base is a habitat with critter slots; each critter placed there produces coins per second based on rarity, mutation and size. The risk comes from the map, not from other players: zone guardians protect the rarest critters, and nothing in your base can ever be taken.

### Base

- Starts with 6 slots; more slots come from coins and rebirths.
- Critters walk around inside their pen, so the base doubles as a showcase other players can visit.
- Coins collect on a pad and are picked up by walking over it.
- Capped offline earnings: the base keeps producing for a limited time while you're away, so returning feels rewarding. Nothing is ever lost for being offline.

### Guardians and nests

- **Guarded nests:** each zone has nests where its rarest critters sit, watched by a big sleeping guardian (a cartoon beast that fits the zone, such as a giant toad in the Swamp or a lava golem in the Volcano).
- **Snatching:** sneak up and grab a critter from the nest. Running, bumping or staying too long fills a "wake-up" meter above the guardian.
- **The chase:** an awake guardian chases you toward your base. If it bumps you (cartoon knockback, no damage), you drop the critter and it runs back to the nest. Reach the safe zone at the base row and it's yours.
- **Harder deeper:** guardians in deeper zones wake faster and run faster, matching the rarer critters they protect.
- **During events:** special guardians (for example a Winter yeti) protect event-only critters.
- **Play together:** several players can raid one nest at once; while the guardian chases one player, the others can escape, which creates teamwork without chat.

### Helper critters (week 4 update)

Equip one critter from your base to follow you on runs. Each has an ability: Sneaky (guardians wake slower), Lucky (more mutation chance), Speedy (faster while carrying) or Spotter (shows nearby rare critters). This gives old critters a new use and makes collecting matter for runs.

### Why no player stealing

Losing a Legendary to another player is the most common reason young players rage-quit steal games. Without it, the base is a safe place, guardians provide the tension, and all player interaction is positive (racing for spawns, raiding nests together, summoning, trading).

## Events, weather and FOMO

The FOMO goal is that a player who logs off thinks "what if a Legendary spawns or a Rainbow Storm hits right now?" It is built from things that might happen while you're gone, never from losses for being away.

### Habitat weather

Weather rolls on the server every 5–15 minutes and lasts a few minutes. While it's active, critters in your base can roll that weather's mutation, but only if you're in the server. An empty base during a Rainbow Storm is the moment players will remember.

| Weather | Effect | Launch? |
| --- | --- | --- |
| Rain | Faster coin production | Yes |
| Snowstorm | Frozen mutation chance on base critters | Yes |
| Rainbow Storm | Rainbow mutation chance; extra Rare spawns on the path | Yes |
| Solar Flare | Lava mutation chance | Later update |
| Blood Moon | Ghost mutation chance; rare night critters | Later update |

### Spawn announcements

- **Server-wide:** "A LEGENDARY Lava Pup appeared in the Volcano!" with a banner, sound and a light beam over the critter. Everyone races for it.
- **Global feed:** when anyone in any server catches a Secret, every server sees a short ticker message. It shows that it could happen to you.

### Schedule board

A board in the start area, and a small HUD timer, show what's coming: the next weather, the "Critter of the Hour" (a featured critter with boosted spawn chance), and a countdown to the Friday update. Kids plan their return around it.

### Admin events

Admins (the dev team) join servers at announced times, such as during each Friday update, and trigger effects: 5x mutation chance, Secret spawns, special weather or a temporary event zone. Announced in Discord and on the game page.

### Limited critters

Each update adds critters or mutations that only exist during that update's event. Once the event ends, they never return in that form, which gives every update a "get it before it's gone" moment.

### Where the line is

| We do | We don't |
| --- | --- |
| Rare spawns, weather and events that reward being online | Take away critters, coins or streaks for being offline |
| Countdowns to scheduled events | Guilt pop-ups like "your critters miss you" |
| Limited-time critters per event | Watch-to-earn feeds of any kind |
| Capped offline earnings as a welcome-back reward | Push notifications that pressure kids |

## Progression and long-term systems

Short-term upgrades make every run feel faster, while the Critterdex, rebirths, eggs, summoning and the pass give players goals that last weeks, which is what Roblox discovery now rewards.

### Upgrades (coins)

| Upgrade | Effect |
| --- | --- |
| Speed | Run faster; unlocks zone gates |
| Net | Wider timing bar, second catch attempt, later event nets |
| Carry capacity | Carry 2–3 critters per trip |
| Base slots | More critters earning at once |
| Stealth | Guardians' wake-up meter fills slower |

### Rebirth

Reset coins and upgrades for a permanent income multiplier, a new net tier and access to deeper zones. Launch with Rebirth 1–3; add more levels with updates, as Steal a Brainrot does.

### Critterdex

An index of every species, with separate entries per mutation and a "Shiny Dex." Completing a zone or mutation page gives a reward such as a slot, a title or a cosmetic. It's the long goal that keeps collectors returning.

### Critter Eggs (built; release at launch or hold for week 2)

Critters in your base occasionally lay an egg. Each egg has its own rarity roll, a chance to inherit a parent's mutation, and a hatch timer that is longer for rarer eggs. The base stays exciting between runs, and "my egg hatches in 2 hours" brings players back.

### Summoning rituals (built; release at launch or hold for week 3)

Three or four players who each own a specific critter stand on a summoning circle together to spawn a Secret or Forgotten critter for everyone present. Works without chat and creates server-wide moments for clips.

### Critter Pass (week 4 update)

A seasonal pass with a free track for everyone and a paid premium track. Rewards are cosmetics, nets, egg boosts and an exclusive critter. Progress comes from catching and daily quests.

### Daily quests

Three short tasks per day, such as "catch 5 Rares" or "catch during a weather event." Missing a day costs nothing; there are no streak penalties. Finishing all three gives a bonus egg.

### Retention and excitement systems (built 2026-10-27)

The aim is that players always want to come back, through anticipation, surprise and visible progress, never through pressure or losses.

| System | What it does |
| --- | --- |
| Catch reveal | The catch card flickers through the rarities and lands on the result; a mutation stamp slams in, Giant shakes the camera, Rare+ flashes the screen, first finds get a NEW! sticker and the Critterdex count |
| Near misses | A miss right next to the sweet spot shows "SO CLOSE! TRY AGAIN!" and the critter stumbles for a moment instead of fleeing |
| Next-goal bar | Always shows the next target with progress: next speed level and the zone it opens, then rebirth, then the Critterdex |
| Welcome back | The base keeps earning at 50 % while you're away, capped at 3 hours; a welcome-back screen hands the coins over. Nothing is lost for being away |
| Daily quests | 3 per day from a pool (catch, rarity, weather, Critter of the Hour, nest, coin pad); rewards scale with income; all 3 = bonus egg |
| Critterdex | Zone pages and mutation pages, critter previews (silhouettes for missing ones); a completed page gives coins and a title |
| Titles | Earned from Critterdex pages, rebirths and the group; shown under the name on nametags |
| Eggs | Base critters lay eggs while you're online; real-time hatch timers keep running while you're away |
| Rebirth 1–3 | Reset coins and speed; keep critters, Critterdex and eggs; +50 % income and a wider sweet spot per rebirth |
| Selling | Hold F on a base critter to sell it and free the slot |
| Social moments | Legendary+ catches and hatches are announced to the server, Secret+ to every server (global ticker); summoning circle in the Meadow |

## First 60 seconds

A new player catches a critter, earns coins, buys an upgrade and sees a Rare spawn before the first minute ends, with no text to read.

| Time | What happens | Feeling |
| --- | --- | --- |
| 0–10 s | Spawn next to your empty base. A glowing arrow points to the Meadow, where a slow, cute critter is already waiting | "I know what to do" |
| 10–20 s | Catch it with a guaranteed-success timing bar, followed by fireworks | First win |
| 20–30 s | Carry it home a few steps; it hops into the pen and coins start ticking up | "It's mine and it pays" |
| 30–45 s | The shop button pulses; buy the first speed upgrade | Getting stronger |
| 45–60 s | A scripted "RARE SPAWN!" announcement fires a guaranteed Rare near the player | First rarity rush |
| 60 s+ | The schedule board shows the next weather; another player's Legendary catch appears in the feed | "I want that next" |

**Rules for onboarding**

- No tutorial text walls. Use arrows, pulsing buttons and icons only, since many Kids-account players read slowly.
- Meadow guardians stay asleep during the first session, so early runs are safe.
- The first three catches are guaranteed successes.
- Measure it: track how many new players reach each step in the first 60 seconds, and fix any step where many drop off.

## Social without chat

Kids accounts have communication off by default, so every social feature works through actions and preset signals.

- **Quick pings:** a wheel with "Help!", "Legendary here!", "Guardian awake!" and "Follow me" that shows as icons over your head and on the minimap edge.
- **Emotes:** celebrate a catch, dance, wave.
- **Trading:** a trade window with an automatic fair-value hint, so young players can't be tricked easily.
- **Base showcase:** visit other bases and "like" them; the most-liked base on the server gets a crown.
- **Summoning rituals:** cooperation by standing together, no talking needed.
- **Server moments:** Legendary announcements make the whole server chase one critter together.

## Monetization

Revenue comes from game passes and developer products, not ads, since rewarded ad formats are prohibited for users under 13. Everything paid must also be reachable or matched by free play, so the game never feels pay-to-win to a kid.

| Type | Item | Notes |
| --- | --- | --- |
| Game pass | VIP (coin bonus, VIP badge, VIP pen decoration) | One-time |
| Game pass | x2 Coins | One-time |
| Game pass | Auto-collect coins | Convenience |
| Game pass | Extra base slots | Also earnable through rebirths |
| Developer product | Luck boost (15 min) | Stacks with weather; best value during events |
| Developer product | Sleep potion (guardians wake slower for 10 min) | Low price |
| Developer product | Egg hatch skip | Week 2 update |
| Pass | Critter Pass premium track | Week 4 update; free track for everyone |
| Cosmetics | Net skins, pen themes, trails | No gameplay advantage |

**Rules**

- If we ever sell random items (such as paid eggs), show the odds before purchase (Roblox requires this for paid random items; confirm current rules before building).
- No paid item that only exists for a few minutes to pressure kids into buying.
- Prices are tested on the 16+ launch audience before the Kids/Select launch.

## Launch plan and update roadmap

Launch in late November or early December 2026: the HEP threshold drops to 100 in November, and winter holidays start mid-December, when kids have the most free time. Launch lean and hold features back, so every week brings something new.

### Three launch phases

1. **Phase 1 – 16+ launch (late Nov / early Dec):** the game is limited to age-checked 16+ players and trusted friends. Marketing targets teens and young adults with meme-style clips. Goal: 100 Highly Engaged Players within 60 days, ideally within 2–3 weeks.
2. **Phase 2 – Kids and Select unlock:** once 100 HEPs are reached, the game opens to all ages. The kid audience arrives into a polished game with a running update rhythm.
3. **Phase 3 – Weekly updates:** a new update every Friday evening (European time, afternoon in the US), one day ahead of Steal a Brainrot's Saturday drops, with the event running through the weekend.

### Update roadmap

| Update | Content |
| --- | --- |
| Launch | Core loop, zones 1–3, rarities and mutations, guardians and nests, 3 weather types, spawn announcements, schedule board, Critterdex with titles, Rebirth 1–3, daily quests, welcome-back earnings |
| Week 1 | Winter event (limited critters and mutation) and Zone 4: Crystal Cave |
| Week 2 | Critter Eggs (already built – hold back if launch has enough content) |
| Week 3 | Summoning rituals (already built) and the first Secret and Forgotten critters |
| Week 4 | Helper critters and Critter Pass season 1 |
| Ongoing | New critters, mutations and weather every Friday; Zone 5 and more rebirth levels; seasonal events |

### Before launch checklist

- [ ] ID verification, two-step verification and Roblox Plus on the publishing account
- [ ] Content maturity questionnaire filled in, aiming for Minimal or Mild
- [ ] Analytics (see below) – the last thing built before launch
- [ ] Playtest with kids in the target age range (siblings, cousins, friends' kids, with parents' permission)
- [ ] At least 4 weekly updates built or designed before launch day
- [ ] Discord server and Roblox group ready

### Analytics (last step before launch)

Without data, retention work is guesswork. Built as the final task before launch, with Roblox's AnalyticsService (funnel, economy, progression and custom events) plus the creator dashboard's retention charts.

| What | Events |
| --- | --- |
| First 60 seconds (onboarding funnel) | joined, first catch attempt, first catch, first deposit, first coin pad collect, first upgrade, first Rare seen |
| Retention | day-1, day-7 and day-28 return rates and session length (dashboard); sessions per player (data.sessions) |
| Where players quit | last meaningful action before leaving (stuck at a gate, base full, after a guardian bonk, after a near miss) |
| Economy | coin sources (income, pad, quests, Critterdex, sell, welcome back) and sinks (speed, rebirth) |
| Progression | speed level, zone reached, rebirth level, Critterdex count |
| Features | quest claims, egg lays and hatches, summonings, weather mutations, catches by rarity and near misses |

Targets to watch: first catch within 30 seconds for 90 % of new players, day-1 retention above 25 %, day-7 above 8 %.

## Free marketing plan

All marketing is free: short videos on TikTok and YouTube Shorts do most of the work, and small YouTubers are the biggest lever. The first goal is reaching 100 Highly Engaged Players aged 16+, so early content targets teens and young adults.

### TikTok and YouTube Shorts

| Phase | Content |
| --- | --- |
| Before launch (4–6 weeks) | Devlogs ("I'm making a Roblox game where monsters run away from you"), critter reveals, polls letting viewers name critters or pick the next Secret, behind-the-scenes clips of funny bugs |
| Launch week | A 15–20 second trailer that opens with a Legendary announcement and a chase, not a logo; launch-day countdown |
| After launch | Clips of narrow escapes from guardians, god-roll mutations, summons and admin events; "POV" memes; weekly update teasers every Thursday |

**Clip-friendly by design:** catching a Secret triggers a slow-motion zoom, big text and a sound sting, so players record and post it themselves.

### Small YouTubers (1k–50k subscribers)

- Message about 50 Roblox YouTubers before launch and offer early access.
- Offer to name a critter after them or design one that looks like their avatar. It costs nothing and gives them a reason to make a video.
- Invite them to admin events and let them trigger one live.

### Other free channels

- **Discord:** update countdowns, sneak peeks, admin event announcements, critter-naming polls.
- **Roblox group:** a free in-game gift for joining and liking the game.
- **Roblox tools:** thumbnail A/B testing and an event listing for every Friday update.
- **Communities:** r/roblox, r/robloxgamedev and devlog posts on the Roblox DevForum.

Note: social media links on Roblox are only visible to age-checked users 16+, which matches the launch audience.

## What we never build

These would get the game removed from Kids and Select or push away the parents and kids we depend on.

- [ ] No media feed with autoplay or scrolling tied to rewards (the mechanic that got Steal An Egg pulled), including anything players might *believe* they must watch to earn
- [ ] No rewarded ads for players under 13
- [ ] Nothing above a Mild content rating: cartoon knockbacks only, no blood or damage
- [ ] No social feature that depends on chat
- [ ] No penalties for being offline: no lost critters, coins or streaks
- [ ] No guilt or pressure prompts aimed at kids
- [ ] No paid random items without visible odds

## Open questions

- [ ] How hard should guardians be in the Meadow and Swamp for 5–8 year olds?
- [ ] Art style balance: how many "meme" critters versus cute ones per update?
- [ ] Team size and production capacity: can we sustain a weekly update?
- [ ] Exact launch date: late November or early December?
- [ ] Final spawn rates, multipliers and prices, set after playtests

## Sources

- [player.one: Steal An Egg is beating some of the platform's biggest games](https://www.player.one/robloxs-steal-egg-beating-some-platforms-biggest-games-164086)
- [Pocket Gamer: Steal an Egg hands-on](https://www.pocketgamer.com/roblox/steal-an-egg-codes-and-tips/)
- [rowatcher: Most popular Roblox games right now](https://rowatcher.com/news/the-most-popular-roblox-games-right-now-ranked-by-live-players)
- [Eldorado: Steal a Brainrot update log](https://www.eldorado.gg/blog/steal-a-brainrot-en/steal-a-brainrot-update-log/)
- [allthings.how: Steal a Brainrot events schedule](https://allthings.how/steal-a-brainrot-events-schedule/)
- [esports.gg: Grow a Garden 2 mutations](https://esports.gg/guides/roblox/all-mutations-and-multipliers-grow-a-garden-2/)
- [Nerds Chalk: Grow a Garden 2 weather](https://nerdschalk.com/grow-a-garden-2-weather-events-mutations-rich-starfall-weather-in-gr/)
- [GosuGamers: Fish It Retro Island update](https://www.gosugamers.net/entertainment/news/78347-roblox-fish-it-launches-retro-island-update-with-new-forgotten-and-secret-species)
- [shattered.io: Roblox cuts doomscroll games from kids](https://shattered.io/roblox-doomscroll-games-ban-kids-select-2026/)
- [Techloy: Roblox Kids and Select accounts](https://www.techloy.com/roblox-to-launch-kids-accounts-in-major-pivot-following-child-safety-pressure/)
- [Youth Sports Business Report: creator requirements](https://youthsportsbusinessreport.com/roblox-rolls-out-age-based-accounts-and-expanded-parental-controls-for-users-under-16/)
- [Roblox Creator Docs: Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select)
- [Roblox DevForum: Kids and Select global launch](https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717)
- [Roblox DevForum: threshold drops to 250](https://devforum.roblox.com/t/highly-engaged-player-threshold-drops-to-250/4820164)
- [ZehnStudio99: threshold drops to 100 in November](https://zehn-studio26.com/news/kids-and-select-hep-threshold-relaxed/)
- [Bloxy News: definition of a Highly Engaged Player](https://x.com/Bloxy_News/status/2074264204337709491)
- [Dolphin Research: Roblox Q2 2026 and 28-day retention](https://longportapp.cn/topics/43104889)
- [DZRH/Reuters: Roblox ad policy overhaul](https://www.dzrh.com.ph/post/roblox-to-overhaul-ad-policies-introduce-revenue-sharing-in-2027)
