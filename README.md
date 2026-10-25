# Graphics for Games and Dynamics Modelling

**3D marble race in Processing:** eight named marbles drop onto a tilted wooden track, bounce off walls, bumps, and pillars, and race to a checkered finish while a HUD tracks places and times.

This is the Marble Race assignment for the Graphics for Games and Dynamics Modelling module. The sketch combines 3D rendering (P3D lighting, cameras, meshes) with a custom dynamics solver (gravity, friction, multi-pass collisions).

## Run the sketch

1. Install [Processing](https://processing.org/) (3.x or 4.x with P3D).
2. File → Open → `Graphics for Games and Dynamics Modelling/MarbleRace/MarbleRace/MarbleRace.pde`.
3. Click Run. The window is 1000×800 and resizable.

## Controls

| Input | Action |
| --- | --- |
| **Space** or Start | Drop the marbles and start the race clock |
| **R** or Reset | Return marbles to the start ledge (idle or after a finish) |
| **C** | Toggle flying camera vs the fixed sky overview |
| **WASD / arrow keys** | Move when flying camera is on |
| **Right mouse** | Look around when flying camera is on |

The overlay shows race status, a live leaderboard, and finish times once marbles cross the finish stripe. Hit flashes light up obstacles and marbles on contact.

## What the simulation does

- **Eight marbles** (Red, Orange, Green, Cyan, Purple, White, Pink, Ice) spawn on a ledge above the start line, then fall onto a ~5° ramp.
- **Track** is built from rotated boxes: platform, deck, walls, rails, kerbs, and start/finish posts. Start and finish are checkered stripes in 3D.
- **Obstacles** include round bumps on the deck and cylindrical pillars. Pillars are drawn as cylinders; collisions use a stack of spheres along each pillar.
- **Physics** does not use a generic one-step integrator for marbles. Each frame runs 8 sub-steps with gravity, ramp drive, speed clamp, box collisions, marble–marble pushes, and extra obstacle resolve so fast marbles do not tunnel through thin colliders.
- **Materials** differ by surface: soft deck bounce, stronger wall bounce, medium bounce on spherical obstacles.
- **Finish** freezes a marble when it crosses the trigger, parks it in a finishing row, and records place plus time.

## Project files

The course folder is `Graphics for Games and Dynamics Modelling/`. All Processing tabs live in `Graphics for Games and Dynamics Modelling/MarbleRace/MarbleRace/`. Processing treats them as one sketch. `MarbleRace.zip` is the same sketch as an archive. The demo video is omitted because it is over GitHub’s 100 MB file limit.

| File | Role |
| --- | --- |
| `MarbleRace.pde` | Game: track layout, HUD, race rules, marble physics and collisions |
| `Sim3DObjects.pde` | Scene solids: spheres, boxes, meshes, transforms, extents |
| `SimIntersections.pde` | Hit tests (sphere, box, mesh, ray, triangle) |
| `SimPhysics.pde` | Motion record (velocity, mass, friction) used as a snapshot for marbles |
| `SimCamera.pde` | Flying camera and scenic overview |
| `SimFunctions.pde` | Vector math, rays, triangles, bounding extents |
| `SimUI.pde` | Optional widgets (Start / Reset / status); most HUD is drawn by hand |

## Course

**Graphics for Games and Dynamics Modelling** — 3D graphics (camera, lighting, geometry) plus rigid-body style dynamics (forces, contacts, a race loop).
