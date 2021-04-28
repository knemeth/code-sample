# code-sample
Contains snippets of code authored by Kiefer Nemeth

Samples from Katja's Abyss: Tactics - https://store.steampowered.com/app/1586270/Katjas_Abyss_Tactics/
> arrays.hss 
> Since the scripting language for the engine the game is made in, the OHRRPGCE, doesn't include arrays, I created my own fake arrays by storing data in the screen position of invisible objects. The fake arrays are modeled after Python Lists, and are used in enemy AI, level generation, and various other systems in Katja's Abyss. 

> enemy.hss
> This includes the enemy behavior code for Katja's Abyss. Such behaviors involve pathfinding, choosing a target, attacking a target, and unique actions in specific conditions.

> animate.hss
> Katja's Abyss has many vfx that animate passively on screen, such as attack animations, menu visuals, particles, etc. This file manages each sprite intended to animate and applies the appropriate changes to them. 

Samples from Digital Soul Data - https://prifurin.itch.io/digital-soul-data
> s_move.hss
> Because the game has a very small resolution (only about 400 pixels wide) and runs at 60fps, even the slowest movement speed, 1 pixel per frame, is very fast. DSD uses subpixel movement to allow for more fidelity to player, enemy, and bullet movement. Hspeak does not include floating point numbers, so this code instead multiplies an x,y pixel position by 1000, performs changes necessary, then divides back down to get the new pixel position. 

> s_enemy.hss
> Definse enemy creation and AI for the top-down bullet hell shooter. Each enemy has a dynamic array of Instructions. Each Instruction includes information on a direction to move, how long to move for, bullets to fire, etc. Specific enemies have unique behaviors, like spawning smaller enemies. The boss is particularly complex. 

> s_level.hss
> Because another team member was designing the levels, I created code that parses the level editor to determine where and when enemies spawn. This way, non-programmers could avoid code entirely. Enemies spawn in waves, so the y-position of each enemy in the level editor determines when it spawns during the level. Its x-position determines where, whether at the top of the screen, from the left, or from the right. 

> guide.png
> This was the tutorial image supplied to the designers to author where enemies spawn. s_level.hss parses the info authored in the level editor.