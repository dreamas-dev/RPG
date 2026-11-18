# Endless Road

A browser RPG with idle skilling, combat, crafting, PvP and online hiscores. It runs on phone and PC and can be installed as an app.

**Play:** https://endless-road.cocomelionas.workers.dev/

Created by **dreamas**.

## My role

- **Game design:** core loop, progression, 15 skills, combat, economy, retention and social features.
- **Balancing:** XP curves, gold income and gold sinks, weapon speeds, drop rates; several full balance passes.
- **AI-driven development:** turned design specs into working features with Claude, reviewed the results and iterated until they played right.
- **Design reviews with AI:** ran structured balance, art and design reviews with AI advisors, then picked which findings to act on.
- **Playtesting and QA:** tested every release on iPhone and PC, found soft locks and balance holes, and set fix priorities.
- **Live operations:** release process, hosting moves (Netlify → GitHub Pages → Cloudflare) without losing player saves, server rules.

## What's in the game

**Skills and progression**
- 15 skills: six combat skills (attack, strength, defence, hitpoints, ranged, magic) and nine gathering and production skills (woodcutting, mining, fishing, thieving, smithing, cooking, fletching, runecrafting, firemaking).
- Smithing from ore to bars to Bronze-to-Rune gear, mastery levels, a prestige loop (New Journey) and achievements.
- Agility with 11 courses, Construction rooms, Farming patches, Herblore potions and summoning familiars.
- Features unlock step by step, so new players aren't overwhelmed.

**Combat**
- Combat triangle (melee, ranged, magic), prayer, a spellbook with runes and elemental staffs.
- Three special attacks per weapon class (blades, heavy weapons, bows, magic), elite monsters, zone bosses, quest-gated boss lairs and a world boss arena.
- Slayer tasks, clue scrolls and pets.

**Economy**
- Grand Exchange between players.
- Gold sinks: enchanting, luxury boosts, cosmetics, home levels and a clan treasury.
- House builder: 37 craftable pieces of furniture to place in your house and yard.

**Retention**
- Daily and weekly tasks, a login streak with streak freezes, a 28-day reward track, a daily bonus chest and a 7-day "Road to Adventure" path.
- Weekly road events and a weekly clan goal.

**Social and PvP**
- Accounts with cloud saves, friends, private messages and live chat.
- Clans, weekly XP hiscores and a collection log with titles.
- PvP against other players' heroes, monthly PvP seasons and a Wilderness-style area with player killers.

**Presentation**
- 3D world with three.js, plus first-person and 2D modes; hitsplats, XP drops and animations for every skill.
- Character customisation (hair, beards, hats, capes, walking trails) that other players see.
- Portrait play on phones, keyboard shortcuts on PC, installable as an app (PWA).

## Design highlights

- **Fixed an exploit in the economy:** a balance review found a gold loop through runes; it was removed and gold and XP were rebalanced.
- **Weapon balance:** slow weapons and bows were falling behind, so their damage was evened out.
- **Better first session:** reworked the opening so new players get a clear goal and reasons to keep tapping.
- **Fair online play:** the server checks every save against the last one and refuses impossible progress (XP, wealth, kills), so hiscores and PvP stay fair.

## Tech

- HTML5 and JavaScript with three.js, installable as a PWA.
- Supabase (Postgres with row-level security) for accounts, saves, hiscores, chat, clans and the Grand Exchange.
- Hosted on Cloudflare Workers; a build step minifies the game.
- Creature models: Quaternius (CC0).

## Licence

All rights reserved. Shown here as a portfolio piece.
