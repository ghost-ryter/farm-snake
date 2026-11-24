# Farm Snake

A twist on classic Snake, Built with **Godot 4** and **GDScript**.

Your tail plants seeds as you move. Loop back at the right moment to harvest ripe pumpkins, but don't trample your crops before they're ready.

## How to play

- **Arrow keys** to steer, **Enter** to restart
- Eat the **seed bag** to get more seeds
- While you have seeds, your tail plants one in every square it leaves
- Sprouts ripen into **pumpkins**. Eat a ripe one for +3 points
- Running over an unripe sprout tramples it
- Ripe pumpkins rot if you wait too long
- Crops only grow during the **day**. Everything pauses at night
- Your best score is saved between sessions

## Features

- Grid movement and collision built from scratch
- Crop growth system with growing, ripe and withering stages
- Day/night cycle with a fading darkness overlay
- Persistent high score saved to disk
- Original 16x16 pixel art

## Running it

1. Install [Godot 4](https://godotengine.org/) (standard version)
2. Clone this repo
3. In Godot, click **Import** and select this folder's `project.godot`
4. Press **F5** to play

## What I learned

- How a game loop works (`_process`, fixed-step movement with a timer)
- Storing game state in arrays and dictionaries
- Drawing with `_draw()` and textures
- Saving data with `FileAccess` and `user://`