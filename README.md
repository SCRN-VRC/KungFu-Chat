# KungFu Chat
[<img src="https://i.imgur.com/O3t1yab.png" align="middle" width="3000"/>](https://www.youtube.com/watch?v=HEqCgFU4ep0)
<img src="https://i.imgur.com/WF0r768.png" align="middle" width="3000"/>

## Overview
Shader based arcade game for VRChat
#### How the Game State Works
<img src="https://i.imgur.com/toiFDH9.png" align="middle" />
A 8x8 Custom Render Texture (CRT) with a feedback loop governs the interactions between players, zombies, and the boss. It also manages the states such as idle, attack, or knocked down that results from such interactions.

#### How the Game Renderer Works
<img src="https://i.imgur.com/OSWyZZs.png" align="middle" />
Originially, I had everything inside a single CRT with the depth sorting done by a radix sort. However the performance was poor on the Quest, so I took up Merlin's advice to seperate the sprites into individual quads and composite it with a camera. The Quest performant version is the one setup for in this project.

## Requirements
1. [VRCSDK](https://vrchat.com/home/download)

## Setup
1. Download the .zip or the Unity Package in Release
2. Open it in Unity
3. Install the VRCSDK

Thanks to [Merlin](https://github.com/Merlin-san/), [Scruffy](https://github.com/ScruffyRules/), [Xiexe](https://github.com/Xiexe/), and 1001 for helping.
