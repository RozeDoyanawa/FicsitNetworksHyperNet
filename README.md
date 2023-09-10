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
