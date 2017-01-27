This mod adds a specialized type of sign block that's intended to be used while exploring caves and other twisty mazes to make navigation easier.

Path markers are initially crafted in a "blank" state. Equip the stack of markers and click on anything with them to bring up a form where you can enter a short text label for this stack of markers. This initializes the stack of markers with that label. They can then be placed on surfaces like normal signs, but the text of the sign is predefined. It will read:

<label> #1
placed by <player name>

Each subsequent sign placed from this stack will increment the number count, and will also add a line of text indicating how many meters away the previous sign in the stack was placed. If you right-click on the sign a stream of particles will be displayed that travel in the direction the previous sign lies in. This should allow much easier "backtracking" along the path of signs. Good practice is to choose a label that describes the starting point of your expedition, since the trail of signs you leave behind will send travelers in the direction of that origin.

If you run out of markers and want to continue a path without starting over, right-click on the last marker you placed with a fresh stack of blank markers and the blank markers will be automatically initialized with the same label and the next number count in line. This also allows you to make "branching" paths, though this may be confusing in some circumstances so consider starting a second path with a new label instead.

Marker signs can be removed from walls using an axe, giving a blank marker sign ready to be initialized and reused. Initialized markers can also be returned to a blank state via the crafting grid.

If you place a marker and don't like how it's positioned, you can "undo" the most recently placed marker by clicking on it with the stack of markers. You can actually pick up all of the markers in a path this way, working your way backward to the origin. Note that this only works in reverse sequential order, if you want to remove a marker from the middle of a path you have to use an axe. Also note that removing a marker from the middle of a path doesn't update the subsequent marker's "previous marker" position - it will still point to the place the marker you removed used to be. So breaking a path in the middle can make following it difficult.