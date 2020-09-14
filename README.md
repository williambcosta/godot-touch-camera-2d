### Table of Contents
- [Introduction](#introduction)
- [Configuration](#configuration)
- [Compatibility](#compatibility)
- [Functioning](#functioning)
- [Mouse inputs support](#mouse-inputs-support)
- [Move the camera while zooming](#move-the-camera-while-zooming)
- [Zoom at a specific point](#zoom-at-a-specific-point)
- [Stop moving on camera's limit](#stop-moving-on-cameras-limit)
- [Known issues](#known-issues)
  - [Control Nodes](#control-nodes)
  - [Emulating touch from mouse](#emulating-touch-from-mouse)
- [Contributing](#contributing)


# Introduction
The necessity of a camera with touch inputs support bring me to search the
web for a solution, without much success.

Some implementations that I found look promising, but I always came
across some behavior that just don't work the way I expected, like the
impossibility of move the camera while zooming, or even the zoom itself,
amplifying the center of the screen when I was focused in something
that simply disappear, forcing me to move the camera on every zoom
ajustement.

It lead me to implement a solution that fit my needs in any scenario
used. So here it is.

**[⬆ back to top](#table-of-contents)**


# Configuration
Put the TouchCamera2D.gd script somewhere on your project and make sure
the class icon path points to the correct svg file (touch_camera_icon.svg)
or simply delete everything after `class_name TouchCamera2D`.

<p align="center">
    <img src="https://raw.githubusercontent.com/williambcosta/godot-touch-camera-2d/master/screenshots/icon_path_highlighted.png" alt="Icon Path">
</p>

If everything is done right you should be able to add the camera as a node
on your scene tree.

<p align="center">
    <img src="https://raw.githubusercontent.com/williambcosta/godot-touch-camera-2d/master/screenshots/add_camera.gif" alt="Add camera">
</p>

Set the parameters you need and make sure to mark the camera as the current
one (it can also be set via script by calling `camera_reference.make_current()`).
Done, it should be ready.

<p align="center">
    <img src="https://raw.githubusercontent.com/williambcosta/godot-touch-camera-2d/master/screenshots/script_parameters.png" width="250" alt="Parameters">
</p>

**[⬆ back to top](#table-of-contents)**


# Compatibility
For now, the camera script was only tested using the Godot version 3.2.x

**[⬆ back to top](#table-of-contents)**


# Functioning
The camera captures and interprets the unhandled inputs, so make sure the inputs
reaches the camera's `_unhandled_input(event: InputEvent)` method. If needed you
can call it directly by script, like this `camera_reference._unhandled_input(event)`.

**[⬆ back to top](#table-of-contents)**


# Mouse inputs support
The camera can handle the mouse inputs right out of the box without the need of
emulating touch from mouse. If needed, you can ignore the mouse inputs by
unmarking the **Handle Mouse Inputs** on the Inspector panel.

<p align="center">
    <img src="https://raw.githubusercontent.com/williambcosta/godot-touch-camera-2d/master/screenshots/mouse_settings.gif" alt="Mouse settings">
</p>

The mouse inputs supported are left click and drag to pan the camera, and the
mouse wheel up/down to zoom in and out.

**[⬆ back to top](#table-of-contents)**


# Move the camera while zooming
By default, the camera move the camera while you applying zoom, so you don't
have to remove a finger to move the camera if needed.

It can be turned off on the Inspector panel by disabling **Move While Zooming**.

<p align="center">
    <img src="https://raw.githubusercontent.com/williambcosta/godot-touch-camera-2d/master/screenshots/move_while_zooming.gif" width="450" alt="Move camera while zooming">
</p>

**[⬆ back to top](#table-of-contents)**


# Zoom at a specific point
When applying zoom, is expected that the point you're focused in always
stays on screen. The camera will do that if the **Zoom At Point** is set
true on the Inspector panel. Otherwise the camera will zoom in/out relative
to the camera position.

<p align="center">
    <img src="https://raw.githubusercontent.com/williambcosta/godot-touch-camera-2d/master/screenshots/zoom_at_point.gif" width="450" alt="Zoom at a specific point">
</p>

**[⬆ back to top](#table-of-contents)**


# Stop moving on camera's limit
If you change the value of the camera's limits, by default, the script will
stop moving the camera's position to prevent pan issues. But if you desire
a more smooth action, the script can allow the user mo move the camera
beyond the limit. After the move action be release the camera will move
itself to the limit smoothly

<p align="center">
    <img src="https://raw.githubusercontent.com/williambcosta/godot-touch-camera-2d/master/screenshots/stop-on-limit.gif" alt="Stop moving on camera's limit">
</p>

**[⬆ back to top](#table-of-contents)**


# Known issues

### Control Nodes
As said above, the camera catches the unhandled inputs to work. But what if
this events never reaches the camera? Well, the camera will not do anything.

A good example of this is Nodes that inherits `Control`. The `Control`
nodes always handle the inputs that occur inside them, even when your
code don't do anything with it. In this cases you can call the camera's
`_unhandled_input(event: InputEvent)` method directly passing the event
to it.

The problem with that is the fact that control nodes events have their
position relative to the node itself. So if you touch in the middle of
a 20x20 node, the `event.position` will be `(10, 10)`, independely of the
viewport size.

For moving the camera it don't represents a lot of trouble, but for zoom at
a specific point the camera need the position relative to the viewport.
Otherwise the camera will go crazy, e.g. positioning itself at 10, 10
while you are focusing an object at 1000, 1000.

A work around, is to manipulate the event's position before calling the
camera's method, adding the node's position to the event's position. But
you'll have to test it well to see if it behaves properly.

**[⬆ back to top](#table-of-contents)**


### Emulating touch from mouse
If you need to emulate touch from mouse and the  **Handle Mouse Events**
are set to true, it causes an issue while moving the camera.

The engine will trigger the camera's `_unhandled_input(event: InputEvent)`
twice, one for the mouse and one for the emulated touch. For zoom action
it's not a big of a deal, since this action is handled independently for the
mouse and touch. But when moving the camera it causes the drag to double, e.g
clicking and dragging the mouse 10 pixels, will move the camera 20.

So, if you really need to emulate the touch, you'll need to change the script.
Adjusting the if statement at the line 122 from this
`if ((event is InputEventScreenDrag)` to this `if event is InputEventScreenDrag:`
and deleting the line 99 as well, should do the trick. The lines 99 thru
119 will not be needed anymore so feel free to delete them.

<p align="center">
    <img src="https://raw.githubusercontent.com/williambcosta/godot-touch-camera-2d/master/screenshots/script_ajustments.png" width="500" alt="Script ajustments">
</p>

**[⬆ back to top](#table-of-contents)**


# Contributing
Feel free to suggest any improvements for the script or for this README translation.
