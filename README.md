# KungFu Chat
[<img src="https://i.imgur.com/O3t1yab.png" align="middle" width="3000"/>](https://www.youtube.com/watch?v=HEqCgFU4ep0)
<img src="https://i.imgur.com/WF0r768.png" align="middle" width="3000"/>

## Overview
Shader based arcade game for VRChat
#### How the Game State Works
<img src="https://i.imgur.com/lS429Bu.png" align="middle" />
A 8x8 Custom Render Texture (CRT) with a feedback loop governs the interactions between players, zombies, and the boss. It also manages the states such as idle, attack, or knocked down that results from such interactions.

#### How the Game Renderer Works
<img src="https://i.imgur.com/OSWyZZs.png" align="middle" />
Originially, I had everything inside a single CRT with the depth sorting done by a radix sort. However the performance was poor on the Quest, so I took up Merlin's advice to seperate the sprites into individual quads and composite it with a camera. The Quest performant version is the one setup for in this project.

## Requirements
1. [VRCSDK](https://vrchat.com/home/download)

## Setup
1. Download the .zip or the Unity package in Release
2. Install the VRCSDK
3. Import the KungFu Chat Unity package
4. Either open the Scene or place down the prefab in the Editor

<img src="https://i.imgur.com/MYQ30H1.png" align="middle" />

5. Setup the VRC Layers

<img src="https://i.imgur.com/lsd8IgG.png" align="middle" />

6. Put the **KungFu Layers** GameOject in the Default layer, but I recommend making a specific layer just for the game

<img src="https://i.imgur.com/dAcpVMK.png" align="middle" />

7. Make sure the **Culling Mask** of the **KungFu Layers Camera** is in the same layer

#### Building for the Quest

1. Follow the same steps as above and [convert to the Android build](https://docs.vrchat.com/docs/creating-content-for-the-oculus-quest)

<img src="https://i.imgur.com/sE3WHLG.png" align="middle" />

2. Set the **Max Size** for **scrn-spritesheet.png** located in **Assets > Shader Games > KungFu Chat > Textures** to **4096**
3. Set the resolution of **KungFu Quest.renderTexture** located in **Assets > Shader Games > KungFu Chat > Quest Compatible** to **120x120**

Thanks to [Merlin](https://github.com/Merlin-san/), [Scruffy](https://github.com/ScruffyRules/), [Xiexe](https://github.com/Xiexe/), and 1001 for helping.
