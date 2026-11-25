# UMBRA SHIFT (Godot 4)

A 100% procedural, 60 FPS 2D fast-paced shapeshifting endless runner built exclusively in **Godot 4 (GDScript + GLSL CanvasItem Shaders)** with zero external sprites, images, textures, fonts, or audio files.

Flee through a rain-drenched, moonlit twilight forest while relentlessly pursued by the living **Shadow Ink Tide**, shifting instantaneously between three anatomically articulated bioluminescent creatures to maintain momentum and build your **Flow Multiplier (`x1` – `x10`)**.

---

## How to Open & Run in Godot 4

1. Install **Godot Engine 4.3+** (Standard edition, GDScript).
2. Open the **Godot Project Manager** and click **Import**.
3. Select the `project.godot` file in the root of this folder and click **Import & Edit**.
4. Press **F5** (or click the **Play** button in the top-right corner) to launch `res://scenes/main.tscn`.

> High scores and best distances are saved automatically at runtime to Godot's user data directory (`user://highscore.cfg`).

---

## Controls

| Action | Keys / Input |
| :--- | :--- |
| **Shift to Fox** (Mint `#4FFFB0`) | `1` or `J` |
| **Shift to Moth** (Cyan `#00E5FF`) | `2` or `K` |
| **Shift to Pangolin** (Amber `#FF9E00`) | `3` or `L` |
| **Cycle Forms Left / Right** | `Q` / `E` or `Left` / `Right` |
| **Jump / Double-Jump / Moth Flap & Hold-to-Glide** | `Space`, `W`, or `Up` |
| **Fox Phantom Dash** (slides under low root tunnels) | `Shift` or `Right-Click` |
| **Pangolin Meteor Slam / Fast-Fall / Low Dash** | `S` or `Down` |
| **Pause / Resume** | `P` or `Esc` |
| **Instant Restart** | `R` |
| **Mute / Unmute Procedural Audio** | `M` |

You can also click any of the three form badges on the bottom-left HUD to shift forms directly.

---

## The Three Shapeshifting Forms

- **Bioluminescent Fox (`#4FFFB0` Mint Green)** — Fastest runner with 3-segment digitigrade 4-beat gallop legs, a 10-node Verlet brush tail, responsive double-jump, and a horizontal **Phantom Dash** (with translucent mint afterimages) to slip beneath low root tunnels.
- **Luminous Moth (`#00E5FF` Electric Cyan)** — Plumed bipectinate antennae, asymmetric falcate forewings, trailing swallowtail hindwings, branching cyan venation, and ocelli eye-spots. Tap to flutter upward, hold to glide softly, and ride glowing cyan **Spore-Drafts** across bottomless ravines.
- **Armored Pangolin (`#FF9E00`–`#FF4500` Magma Amber)** — Layered weathered-basalt diamond keratin scales with glowing volcanic fissures and 3-clawed digging limbs. Curls into a rotating armored sphere downhill and at speed, ignores brambles, executes heavy **Meteor Ground-Slams**, and shatters cracked monoliths, crystal walls, and fallen logs with 50ms hitstop, flying stone debris, and glowing fracture decals.

---

## Project Structure

```text
.
├── project.godot                  # Godot 4.3 project config, 1280x720 canvas_items expand, full input map
├── README.md                      # Setup, controls, and architecture guide
├── resources/
│   └── world_env.tres             # WorldEnvironment HDR Glow/Bloom & tonemapping
├── scenes/
│   ├── main.tscn                  # Root scene (WorldEnvironment, CanvasModulate, 6-layer forest, Player, Camera2D, VFX, Ink Tide, HUD, Audio)
│   ├── player.tscn                # CharacterBody2D with procedural PointLight2D (GradientTexture2D), Line2D MothRibbon, and 3 creature renderers
│   └── hud.tscn                   # CanvasLayer hosting Title Screen, minimalist HUD, Pause modal, and Game Over card
├── scripts/
│   ├── main.gd                    # State machine, 50ms hitstop, dynamic camera, obstacle collision, Flow multiplier
│   ├── player.gd                  # 3-form physics, coyote time, jump/morph buffering, momentum conservation
│   ├── fox_renderer.gd            # Procedural _draw() Bioluminescent Fox anatomy
│   ├── moth_renderer.gd           # Procedural _draw() Luminous Moth anatomy
│   ├── pangolin_renderer.gd       # Procedural _draw() Armored Pangolin & curled sphere anatomy
│   ├── environment_backdrop.gd    # 6-layer parallax forest, wind-swaying canopy polygons, 3-depth diagonal rain
│   ├── level_generator.gd         # Chunk-based clearable level generator, organic cliffs, shader puddles, reactive bending ferns, waystones
│   ├── ink_tide.gd                # Shadow Ink Tide proximity/surge controller + writhing procedural tendrils
│   ├── vfx_manager.gd             # Zero-GC pooled sparks, morph bursts, afterimages, stone debris, ripples & ground decals
│   ├── procedural_audio.gd        # Pure AudioStreamGenerator synthesizer (rain/wind pink noise, form SFX, heartbeat, Flow arpeggio)
│   └── hud.gd                     # Responsive procedural UI + ConfigFile (user://highscore.cfg) persistence
└── shaders/
    ├── sky_clouds.gdshader        # Twilight sky gradient, crescent moon halo, FBM storm clouds, sheet lightning
    ├── tree_sway.gdshader         # Vertex wind-sway displacement for mid-ground forest canopies
    ├── water_reflect.gdshader     # Rain-rippled puddle reflections synced to player bioluminescence
    ├── ink_tide.gdshader          # FBM liquid ink wave displacement with glossy moonlight crest sheen
    └── speed_lines.gdshader       # High-Flow speed streaks & 0.12s morph chromatic rim pulse
```
