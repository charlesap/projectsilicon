wget http://www.projectoberon.net/wirth/ProjectOberon/license.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/Kernel.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/FileDir.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/Files.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/Modules.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/Input.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/Display.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/Viewers.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/Fonts.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/Texts.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/Oberon.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/MenuViewers.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/TextFrames.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/System.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/Edit.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/SCC.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/Net.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/ORS.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/ORB.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/ORG.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/ORP.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/ORTool.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/Graphics.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/GraphicFrames.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/Draw.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/GraphTool.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/Rectangles.Mod.txt
wget http://www.inf.ethz.ch/personal/wirth/ProjectOberon/Sources/Curves.Mod.txt

cat license.txt          | tr -d '\r' > license.txt.1          
cat Kernel.Mod.txt       | tr -d '\r' > Kernel.Mod        
cat FileDir.Mod.txt      | tr -d '\r' > FileDir.Mod
cat Files.Mod.txt        | tr -d '\r' > Files.Mod
cat Modules.Mod.txt      | tr -d '\r' > Modules.Mod
cat Input.Mod.txt        | tr -d '\r' > Input.Mod
cat Display.Mod.txt      | tr -d '\r' > Display.Mod
cat Viewers.Mod.txt      | tr -d '\r' > Viewers.Mod
cat Fonts.Mod.txt        | tr -d '\r' > Fonts.Mod
cat Texts.Mod.txt        | tr -d '\r' > Texts.Mod
cat Oberon.Mod.txt       | tr -d '\r' > Oberon.Mod
cat MenuViewers.Mod.txt  | tr -d '\r' > MenuViewers.Mod
cat TextFrames.Mod.txt   | tr -d '\r' > TextFrames.Mod
cat System.Mod.txt       | tr -d '\r' > System.Mod
cat Edit.Mod.txt         | tr -d '\r' > Edit.Mod
cat SCC.Mod.txt          | tr -d '\r' > SCC.Mod
cat Net.Mod.txt          | tr -d '\r' > Net.Mod
cat ORS.Mod.txt          | tr -d '\r' > ORS.Mod
cat ORB.Mod.txt          | tr -d '\r' > ORB.Mod
cat ORG.Mod.txt          | tr -d '\r' > ORG.Mod
cat ORP.Mod.txt          | tr -d '\r' > ORP.Mod
cat ORTool.Mod.txt       | tr -d '\r' > ORTool.Mod
cat Graphics.Mod.txt     | tr -d '\r' > Graphics.Mod
cat GraphicFrames.Mod.txt| tr -d '\r' > GraphicFrames.Mod
cat Draw.Mod.txt         | tr -d '\r' > Draw.Mod
cat GraphTool.Mod.txt    | tr -d '\r' > GraphTool.Mod
cat Rectangles.Mod.txt   | tr -d '\r' > Rectangles.Mod
cat Curves.Mod.txt       | tr -d '\r' > Curves.Mod
rm *.txt
mv license.txt.1 license.txt



