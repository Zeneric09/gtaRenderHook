# GTA rendering hook
GTA SA rendering hook
Implements DirectX11 rendering API to GTA San Andreas(possible to GTA VC and GTA 3 someday) as well as totally new rendering pipeline.
We have discord server(https://discord.gg/rsZEUNW), come and help to improve it!
## Current requirements to build development source code
1) Windows 7+
2) Latest DirectX SDK
3) DK22Pac's Plugin SDK
4) tinyxml2
5) AntTweakBar
## How to setup
1) Change output directory to GTA SA folder
2) Build in release mode
3) Run and have fun!
## Tips
1) If you encounter bug please report it, and attach debug.log file to bugreport
2) To enable more debug info set debuglevel higher(0-2) in autogenerated settings.xml
3) To enable in-game menu press F12
4) Currently there is experimental feature: Physically Based Rendering Materials, to put it simply render hook loads textures and material info from materials folder in executable directory. To add material you have to create materials.txd inside materials folder, and .mat file named after some in-game texture with specular texture name inside it. Specular texture should be added to materials.txd, red channel of specular texture is intensity, while green channel is glossiness.
