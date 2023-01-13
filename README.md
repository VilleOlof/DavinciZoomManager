# DavinciZoomManager
Used to manage zoom presets, customizable up to **176** zoom presets (with 16 of them being project dynamic).  
Customize each zoom preset with an icon and which tracks it will affect.    
You can also choose to either append or override the clips properties.  

Each zoom preset will take most of the transform properties and not only the zoom.  
You really only need `ZoomExtended.lua` (Which is the main script) to utilize it but,  
using both `ZoomChild` and `ZoomClamp` is recommended.  

The 11th tab is project dynamic and will change and save zoom presets,  
depending on the project you're in.  

Each zoom button inside `ZoomExtended` can have custom icons.  
Put your icons into `%appdata%/Blackmagic Design/DaVinci Resolve/ZoomExtended/ZoomManagerButtonIcons/`  
And name your icons according to this template: `UI_Zoom_tab_row_column_Icon.png`  
Example: `UI_Zoom_2_1_3_Icon.png`  

**ZoomExtended**  
This is the main manager UI script.  
Add, Modify, Select Zoom Tracks in this UI.  
Each Zoom Button/Preset has an ID.  
This ID represents it's Tab, Row & Column in the UI.  
This ID is used in the ZoomChild script to specify a zoom preset.  

**ZoomChild**  
This script acts more like a hotkey than a script.  
In the `ZoomChild.lua` file you can modify which zoom preset it will choose  
and it will only apply those properties to selected tracks.  
You can also sync the current tab in `ZoomExtended` to `ZoomChild`,  
This allows you to only really specify row and column and switch tabs in  
`ZoomExtended` to more easily switch between a lot of hotkeys.  

Duplicating this to add more hotkeys to some presets are recommended.  

**ZoomClamp**  
Is a unique script that clamps the current clip into frame,  
depending on the track selection in the `ZoomExtended` UI.  
Or you can clamp all tracks if you enable that option in the `ZoomClamp.lua file`.  

No settings or changes to the script needs to be made except the `tab, row, column` in `ZoomChild.lua`.  


## Installation

Place the script into `%appdata%/Blackmagic Design/DaVinci Resolve/Support/Fusion/Scripts/Edit/`  
and it can be found inside davinci resolve at   
`Workspace>Scripts>ZoomExtended/ZoomChild/ZoomClamp`
