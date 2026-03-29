# QuestHUD

Optimised quest routing HUD overlay for **80→90 levelling** in World of Warcraft: **Midnight** (12.0).

QuestHUD hijacks the minimap and expands it into a full-screen heads-up display with:

- **Directional arrow** — colour-coded by quest type (campaign/side/delve), with arrival pulse
- **13-step route backbone** — pre-built path across Eversong Woods → Zul'Aman → Harandar → Arator's Journey → Voidstorm
- **Info panel** — draggable overlay showing current quest objective, XP reward, distance, and ETA
- **Gathering node overlay** — bundled herb + mine database with live collection via HereBeDragons pins
- **XP bonus detector** — tracks War Mode, Rested XP, Heirlooms, Darkmoon WHEE!, Warband Mentor
- **First Craft reminder** — nudges Alchemy/Herbalism players to earn the First Craft XP bonus

## Installation

Copy the `QuestHUD` folder into your `World of Warcraft\_retail_\Interface\AddOns\` directory.

Or install via CurseForge / Wago once published.

## Usage

- `/questhud` — toggle the HUD on/off
- Right-click the minimap button for options
- Drag the info panel to reposition it
- `/questhud firstcraft done` — dismiss the First Craft reminder

## Configuration

Open the addon options panel via the minimap button or `/questhud options`:

- **Quest Arrow** — toggle + colour customisation per quest type
- **Info Panel** — show/hide the objective/XP/ETA panel
- **Gathering Nodes** — enable/disable herb and mine overlays, set radius
- **XP Bonus & Time Estimate** — calibrate baseline XP/hour for time estimate accuracy
- **First Craft Reminder** — toggle or manually dismiss

## Requirements

- World of Warcraft Retail: **Midnight** (12.0.x)
- Interface version: `120001`

## Known Limitations

- Quest IDs in RouteData are placeholders (`0`) until Midnight PTR confirms real IDs
- Coordinates are estimated and will need PTR verification
- Baseline XP/hour for time estimates needs calibration via timed runs

## Libraries

Bundled via [BigWigsMods Packager](https://github.com/BigWigsMods/packager):

- HereBeDragons-2.0 + Pins
- AceConfig-3.0 / AceGUI-3.0
- LibDataBroker-1.1
- LibDBIcon-1.0
- LibStub / CallbackHandler-1.0
- LibColors-1.0

## Building

Push a git tag to trigger the GitHub Actions packager:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The packager will create release zips on GitHub, CurseForge, and Wago (when project IDs and API keys are configured in repository secrets).

## Blizzard Quest API Sync

QuestHUD includes a quest extractor script at `tools/extract_quests.py` that can:

- Fetch the full quest index from Blizzard Game Data APIs
- Optionally fetch per-quest detail payloads
- Write normalized outputs to JSON and Lua
- Auto-fill `id = 0` placeholders in `QuestHUD_RouteData.lua` by matching quest names

### 1) Set Blizzard API credentials

Use environment variables:

```powershell
$env:BLIZZARD_CLIENT_ID="<your-client-id>"
$env:BLIZZARD_CLIENT_SECRET="<your-client-secret>"
```

### 2) Extract all quest data and patch route IDs

From the repository root:

```powershell
python .\QuestHUD\tools\extract_quests.py `
  --region eu `
  --namespace static-eu `
  --locale en_GB `
  --details `
  --out-json .\QuestHUD\tools\generated\quest_data.json `
  --out-lua .\QuestHUD\QuestHUD_QuestAPIData.lua `
  --update-route-data .\QuestHUD\QuestHUD_RouteData.lua
```

Notes:

- `--details` makes one request per quest and can take time.
- Use `--max-quests 500` for test runs.
- If Blizzard returns no quest records for your region/namespace, the script exits with an error by default. Use `--allow-empty` if you still want to write empty output files.
- OAuth and API host routing follow Blizzard documentation automatically, including China (`cn`) hostnames.
- The Lua output is generated for local repository workflows; load it in `QuestHUD.toc` only if you intend to consume it at runtime.

## License

All rights reserved.
