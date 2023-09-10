#Preparation
Disclaimer: Very much a work in progress.

Build a computer in Satisfactory and add a Floppy Disk and EEPRROM to it.
Find the filesystem path to the floppy drive.
On Windows, usually under %localappdata%\FactoryGame\Saved\SaveGames\Computers\
You can see the ID of the floppy drive in game in its tool tip text. Remember you have to insert it into a computer first, then remove it, to get an ID. Un-used drives is not mapped.
Copy Common.lua, json.lua and HyperNet/HyperNet.lua into the root of the drive. And copy the contents of init-hypernet.lua into the eeprom code window in game. Before you run the computer, also create two folders panels and tubedata into the floppy, or you will get errors running the machine.

![Network Descriptor Top Down](Documentation/Image-001.png)

![Network Descriptor](Documentation/Image-002.png)
# Network setup:
- Entrance Gate Switch:
  Network nick: “HyperNet node=*[node]*|type=entrance|gates=*[n]*|name=*[name]*” without quotes
  - *[node]* = Unique network node name/index, should be the same for all objects in a node. Must be lua identifier compliant. For Simplicity, only use letters and numbers. And start with a letter. Eg. Node1 
  - *[n]* = Number of Gates, excluding entrance/exit, in example would be 3. 
  - *[name]* = Human readable name displayed on panels
- Exit Gate Switch:
  Network nick: “HyperNet node=*[node]*|type=exit” without quotes
  - *[node]* = Node name this switch belongs to
- Gate [index]:
  Power connected to Gate Switch with the same index
  Network nick: “HyperNet node=*[node]*|type=pipe|index=[index]” without quotes
  - *[node]* = Node name this gate belongs to
  - *[index]* = The index of this gate. 0 to ([n] – 1) as defined in Entrance gate switch. In example, there is 0, 1 and 2.
- Gate Switch [index]:
  Network nick: “HyperNet node=*[node]*|type=gate|index=*[index]*|next=auto” without quotes
  - *[node]* = Node name this switch belongs to
  - *[index]* = Same as Gate, one switch per gate
  - *next=auto* = Can be changed to next=[node] where node is the name of another node, if auto does not work. Legacy support.
- Entrance Gate:
  Power connected to Entrance Gate Switch
  Network nick: “HyperNet node=*[node]*|type=epipe”
  - *[node]* = Node name this switch belongs to
- Exit Gate:
  Power connected to Exit Gate Switch
- Display (Optional):
  Network nick: “HyperNet node=*[node]*|type=sign” without quotes
  - *[node]* = Node name this switch belongs to
- Control Panel:
  Network nick: “HyperNet node=*[node]*|type=controls”
  - *[node]* = Node name this switch belongs to
- Light Tower (Optional):
  Network nick: “HyperNet node=*[node]*|type=tower”
  - *[node]* = Node name this switch belongs to


## Example node:
An example for a node called Node1.

![Example Node](Documentation/Image-003.png)

[3-way Node with Exit. Named, but all names need parameters to be replaced](https://satisfactory-calculator.com/en/blueprints/index/details/id/3861/name/HyperNet+Entrance+Node)

# Light Tower:
Simply a modular indicator tower with one or two indicators. 


#
# Panel Options:
## Small panel
- 1x Encoder
- 1x Large Micro Display
- 1x Push Button or Mushroom Pushbutton

![Small Panel Example](Documentation/Image-004.png)
## Large Panel
- 1x Encoder
- 2x Large Micro Display. One will show destination, the other travel distance.
- 1x Push Button or Mushroom Pushbutton

![Large Panel Example](Documentation/Image-005.png)

