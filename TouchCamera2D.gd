# Make sure the icon path points to the correct location
class_name TouchCamera2D, "res://touch_camera_icon.svg"

extends Camera2D

# If set true the camera will stop moving when the limits are reached.
# Otherwise the camera will continue moving, but will return to the
# limit smoothly
export var stop_on_limit: bool = false setget set_stop_on_limit

# The return speed of the camera to the limit. The higher this number
# faster the camera will return to the limit
export(float, 0.01, 1, 0.01) var return_speed = 0.15

# If true, the camera will continue moving after a fling movement, decelerating
# over time, until it stops completely
export var fling_action: bool = true

# Minimum velocity to execute a fling action. In pixels per second
export var min_fling_velocity: int = 750

# The fling deceleration rate in pixels per second. The higher this number
# faster the camera will stop
export(int, 0, 3000) var deceleration = 600

# The minimum camera zoom
export var min_zoom: float = 0.5

# The maximum camera zoom
export var max_zoom: float = 2

# Represents the amount of pixels traveled before the zoom action begins
export var zoom_sensitivity: int = 10

# How much the zoom will be incremented/decremented when the action happens
export var zoom_increment: float = 0.05

# If set true, the camera's position will be relative to a specific point
# when zooming (the mouse cursor or the middle point between the fingers)
export var zoom_at_point: bool = true

# If true the camera can be moved while zooming
# Relevant only for pinch to zoom actions
export var move_while_zooming: bool = true

# If true, allows the mouse wheel to change the zoom, and click and drag
# to pan the camera (without the need of emulating touch from mouse)
export var handle_mouse_events: bool = true

# How much the mouse wheel will incremented/decremented the zoom
export var mouse_zoom_increment: float = 0.1

# The last distance between two touches.
# The last_pinch_distance will be compared to the current pinch distance to
# determine if the zoom needs to be incremented or decremented
var last_pinch_distance: float = 0

# Dictionary that holds the events in case of multitouch
# The InputEventScreen Touch/Drag only represents the last touch, even in case
# of multi touches. So, to hold the information off all touches you have
# to store previous events for latter use
var events = {}

# Viewport size
var vp_size := Vector2.ZERO

# Helps the camera to stay on the limit
var limit_target := position

# If the camera is set to continue moving off limit, the original limits of
# the camera will be set to maximum possible and this will hold the
# original limits
var base_limits := Rect2(limit_left, limit_top, limit_right, limit_bottom)

# Initial velocity of the fling action in the x axis
var velocity_x: int = 0

# Initial velocity of the fling action in the y axis
var velocity_y: int = 0

# The position that the action started
var start_position := Vector2.ZERO

# The time elapsed until the end of the action
var action_time: float = 0

# Used to mark the "auto scroll" animation after a fling action
var is_flying: bool = false


# Connects the viewport signal
func _ready() -> void:
	# This call initializes the vp_size reference
	_on_viewport_size_changed()

	# If the signal connection is not OK
	if get_viewport().connect("size_changed",
			self,"_on_viewport_size_changed") != OK:
		# Sets vp_size
		vp_size = get_viewport().size

	# Sets up the limits
	set_stop_on_limit(stop_on_limit)


# Called every frame
func _process(_delta) -> void:
	# If stop on limit is set false and there are no input events
	if not stop_on_limit and events.size() == 0:
		# Move the camera towards the limit_target's position
		position = lerp(position, limit_target, return_speed)


# Captures the unhandled inputs to verify the action to be executed by
# the camera
func _unhandled_input(event: InputEvent) -> void:
	# If event is a touch
	if event is InputEventScreenTouch:
		# And it's pressed
		if event.is_pressed():
			# Stores the event in the dictionary
			events[event.index] = event

		# If it's not pressed
		else:
			# Erases this event from the dictionary
			events.erase(event.index)

	# If it's set to handle the mouse events, it's a Left button
	# and it's pressed
	# If you need to emulate touch from mouse, to avoid pan issue,
	# you can delete this section. From here...
	elif handle_mouse_events and event is InputEventMouseButton:
		if event.get_button_index() == BUTTON_LEFT:
			if event.is_pressed():
				# Stores the event in the dictionary
				events[0] = event

			# If it's not pressed
			else:
				# Erases this event from the dictionary
				events.erase(0)

		# If move while zooming is set true it means that the event stored
		# have to stay in the dictionary to allow the camera to move
		# Otherwise it can be erased
		elif not move_while_zooming:
			# Checks if the key exists
			if events.has(0):
				# Erases this event from the dictionary
				events.erase(0)
	# ...to here

	# If it's a motion
	# if emulate touch is needed...
	if ((event is InputEventScreenDrag) # ...change to: if event is InputEventScreenDrag:
			# and delete the next line
			or (handle_mouse_events and event is InputEventMouseMotion)):

		# If it's a ScreenDrag
		if event is InputEventScreenDrag:
			var last_pos: Vector2 = events[event.index].position

			# If the distance between this touch index and the stored
			# is greater than the zoom sensitivity
			if last_pos.distance_to(event.position) > zoom_sensitivity:
				# Update the event stored in the dictionary
				events[event.index] = event

		# If the dictionary have only one event stored, it means that
		# the user is moving the camera
		if events.size() == 1:
			set_position(position - event.relative * zoom)

		# If there are more than one finger on screen
		if events.size() > 1:
			# Get index (this is random with window 10 touch)
			var keys = events.keys()
			# Stores the touches position
			var p1: Vector2 = events[keys[0]].position
			var p2: Vector2 = events[keys[1]].position

			# If move while zooming is set true
			if move_while_zooming:
				# Sets the position of the camera considering the average
				# position of the touches
				set_position(position - event.relative / 2 * zoom)

			# Calculates the distance between them
			var pinch_distance: float = p1.distance_to(p2)

			# If the absolute difference between the last and the
			# current pinch distance is greater than the zoom sensitivity
			if abs(pinch_distance - last_pinch_distance) > zoom_sensitivity:
				var new_zoom: float

				# If the pinch distance is lower than the last pinch distance
				# it means that a zoom-out action is happening
				if pinch_distance < last_pinch_distance:
					new_zoom = (zoom.x + zoom_increment)

				# Otherwise a zoom-in
				else:
					new_zoom = (zoom.x - zoom_increment)

				# If zoom at point is true
				if zoom_at_point:
					# Updates the camera's zoom and position
					# to keep the focused point at screen
					# In case of pinch to zoom, the focus will be the
					# average point between the fingers
					zoom_at(new_zoom * Vector2.ONE, (p1 + p2) / 2)
				else:
					# Otherwise, just updates de camera's zoom
					zoom_at(new_zoom * Vector2.ONE, position)

				# Stores the current pinch_distance as the last for
				# future use
				last_pinch_distance = pinch_distance

	# If the mouse events is set to be handled
	elif handle_mouse_events:
		if event is InputEventMouseButton and event.is_pressed():
			var zoom_diff := Vector2(mouse_zoom_increment, mouse_zoom_increment)
			# Wheel up = zoom-in
			if event.get_button_index() == BUTTON_WHEEL_UP:
				if zoom_at_point:
					zoom_at(zoom - zoom_diff, event.position)
				else:
					zoom_at(zoom - zoom_diff, position)

			# Wheel down = zoom-out
			if event.get_button_index() == BUTTON_WHEEL_DOWN:
				if zoom_at_point:
					zoom_at(zoom + zoom_diff, event.position)
				else:
					zoom_at(zoom + zoom_diff, position)


# Updates the reference vp_size properly when the viewport change size
func _on_viewport_size_changed() -> void:
	# If the stretch mode is set to disabled or viewport, the size override will
	# always be (0, 0). And if that's the case, the vp_size will be the
	# viewport size
	if get_viewport().get_size_override() == Vector2.ZERO:
		vp_size = get_viewport().size

	# Otherwise, vp_size will be the size_override
	else:
		vp_size = get_viewport().get_size_override()


# Checks if the camera was flinged with a velocity grater than the minimum allowed
func was_flinged(start_p: Vector2, end_p: Vector2, dt: float) -> bool:
	return int(start_p.distance_to(end_p) / dt) >= min_fling_velocity


# Sets the camera's zoom making sure it stays between the minimum and maximum
func set_zoom(new_zoom: Vector2) -> void:
	new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
	zoom = Vector2.ONE * new_zoom.x


# Sets the zoom and positions the camera to keep the focused point at screen
func zoom_at(new_zoom: Vector2, point: Vector2) -> void:
	if new_zoom.x > min_zoom and new_zoom.x < max_zoom:

		# If the camera's anchor is set to center
		if anchor_mode == ANCHOR_MODE_DRAG_CENTER:
			# Updates the point value to be relative to the center of the screen
			point -= vp_size/2

		# Holds the difference between the updated and the current zoom
		var zoom_diff: Vector2
		zoom_diff = new_zoom - zoom

		# Sets the new zoom
		set_zoom(new_zoom)

		# Sets the camera's position to keep the focus point on screen
		set_position(position - (point * zoom_diff))


# Sets the camera's position making sure it stays between the limits
func set_position(new_position: Vector2) -> void:
	var offset: Vector2
	var left: float
	var right: float
	var top: float
	var bottom: float

	var bp := base_limits.position
	var bs := base_limits.size

	# If the camera's anchor is set to center, to make sure the camera's
	# position stays inside the scroll limits, the position can't be less than
	# the left/top (bottom/right as well) limit plus half the viewport
	# times the zoom
	if anchor_mode == ANCHOR_MODE_DRAG_CENTER:
		offset = vp_size / 2
		left = limit_left + offset.x * zoom.x
		top = limit_top + offset.y * zoom.y

		# Adjusts the base limit position relative to the offset * zoom
		bp += offset * zoom

	# If the anchor is set to top left, the left/top limits are not influenced
	# by the offset. Consequently the offset for bottom/right limits are the
	# entire viewport times the zoom
	elif anchor_mode == ANCHOR_MODE_FIXED_TOP_LEFT:
		offset = vp_size
		left = limit_left
		top = limit_top

	# Apply the offset to the bottom/right limits
	right = limit_right - offset.x * zoom.x
	bottom = limit_bottom - offset.y * zoom.y

	# Adjusts the base limit size relative to the offset * zoom
	bs -= offset * zoom

	# If is to stop the camera on limit
	if stop_on_limit:
		# Makes sure that the camera's position stays between the limits
		position.x = clamp(new_position.x, left, right)
		position.y = clamp(new_position.y, top, bottom)

	else:
		# Otherwise continue moving the camera
		position.x = new_position.x
		position.y = new_position.y

		# And clamp the limit target so that the camera can return smoothly
		limit_target.x = clamp(new_position.x, bp.x, bs.x)
		limit_target.y = clamp(new_position.y, bp.y, bs.y)


# Sets the camera's behavior relative to its limits
func set_stop_on_limit(stop: bool) -> void:
	stop_on_limit = stop

	# If the stop_on_limit is true, resets the camera limits
	if stop_on_limit:
		limit_left = base_limits.position.x as int
		limit_top = base_limits.position.y as int
		limit_right = base_limits.size.x as int
		limit_bottom = base_limits.size.y as int
	else:
		# Otherwise sets the limits to default values
		limit_left = -10000000
		limit_top = -10000000
		limit_right = 10000000
		limit_bottom = 10000000
