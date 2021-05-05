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
export var min_fling_velocity: float = 100.0

# The fling deceleration rate in pixels per second. The higher this number
# faster the camera will stop. It have a 10000 limit but can be higher
export(float, 1.0, 10000.0) var deceleration: float = 2500.0

# The minimum camera zoom
export var min_zoom: float = 0.5

# The maximum camera zoom
export var max_zoom: float = 2

# Represents the amount of pixels traveled before the zoom action begins
export var zoom_sensitivity: int = 10

# How much the zoom will be incremented/decremented when the action happens
export var zoom_increment: Vector2 = Vector2(0.05, 0.05)

# If set true, the camera's position will be relative to a specific point
# when zooming (the mouse cursor or the middle point between the fingers)
export var zoom_at_point: bool = true

# If true the camera can be moved while zooming
# Relevant only for pinch to zoom actions
export var move_while_zooming: bool = true

# If true, allows the mouse wheel to change the zoom, and click and drag
# to pan the camera (without the need of emulating touch from mouse)
export var handle_mouse_events: bool = true

# The last distance between two touches.
# The last_pinch_distance will be compared to the current pinch distance to
# determine if the zoom needs to be incremented or decremented
var last_pinch_distance: float = 0

# Dictionary that holds the events in case of multitouch
# The InputEventScreen Touch/Drag only represents the last touch, even in case
# of multi touches. So, to hold the information off all touches you have
# to store previous events for later use
var events = {}

# Viewport size
var vp_size := Vector2.ZERO

# Helps the camera to stay on the limit
var limit_target := position

# If the camera is set to continue moving off limit, the original limits of
# the camera will be set to maximum possible and this will hold the
# original limits set by the dev
var base_limits := Rect2(limit_left, limit_top, limit_right, limit_bottom)

# Helps to check the area that the camera can stay
var valid_limit := Rect2(0, 0, 0, 0)

# Initial velocity of the fling action in the x axis
var velocity_x: float = 0.0

# Initial velocity of the fling action in the y axis
var velocity_y: float = 0.0

# The start position of the fling action
var start_position := Vector2.ZERO

# The end position of the fling action
var end_position := Vector2.ZERO

# The time taken to make the fling action
var fling_time: float = 0.0001

# Multi touch events can trigger an undesered fling action. This flag disables
# the fling action temporarily
var ignore_fling : bool = false

# Used to mark the "auto scroll" animation after a fling action
var is_flying: bool = false

# Used to mark if the camera is been moving
var is_moving: bool = false

# Used to mark he duration of the flying motion or the time elapsed until the
# end of the fling action
var duration: float = 0.0001

# Used to calculate the deceleration of the x axis
var dx: float = 0.0

# Used to calculate the deceleration of the y axis
var dy: float = 0.0


# Connects the viewport signal
func _ready() -> void:
	# This call initializes the vp_size reference
	_on_viewport_size_changed()

	# Calculate the camera's valid limit depending of the anchor mode
	calculate_valid_limits()

	# If the signal connection is not OK
	if get_viewport().connect("size_changed",
			self,"_on_viewport_size_changed") != OK:
		# Sets the view port size
		vp_size = get_viewport().size

	# Sets up the limits
	set_stop_on_limit(stop_on_limit)


# Called every frame
func _process(_delta) -> void:
	# If stop_on_limit is set false and there are no input events
	if not stop_on_limit and events.size() == 0:
		# Moves the camera towards the limit_target's position, returning it to
		# the valid limits
		position = lerp(position, limit_target, return_speed)

	# If the camera is moving
	if is_moving:
		# Update de duration
		duration += _delta

	# If the camera is flying (auto scrolling)
	if is_flying:
		# Set the next camera's position considering the velocity
		fling(velocity_x, velocity_y, _delta)


# Captures the unhandled inputs to verify the action to be executed by
# the camera
func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch
			or handle_mouse_events and event is InputEventMouseButton
			and event.get_button_index() == BUTTON_LEFT):

		# The InputEventMouseButton doesn't have a index, so if that's the
		# case the index will be 0
		var i
		if event is InputEventMouseButton and event.get_button_index() == BUTTON_LEFT:
			i = 0
		else:
			i = event.index

		# If the event is pressed
		if event.is_pressed():
			# Stores the event in the dictionary
			events[i] = event

			# If there is more than one finger at the screen, ignores the fling action
			if events.size() > 1:
				ignore_fling = true

			# Sets the camera as moving if the fling action is activated
			is_moving = true and fling_action

			# Prepare for the fling action if there is only one touch
			if events.size() == 1:
				# Stores the event start position to calculate the velocity later
				start_position = event.position
				end_position = start_position

			# In case the camera was flying, stops it
			finish_flying()

		# If it's not pressed
		else:
			if duration > 0 and is_moving and not ignore_fling:
				# Unset the camera moving flag
				is_moving = false

				# If the fling action is activated and it's not to ignore the fling action
				if fling_action and not ignore_fling:
					# Verify if the camera was flinged. If so, set as flying
					if was_flinged(start_position, end_position, fling_time):
						is_flying = true

			# Erases this event from the dictionary
			events.erase(i)

			# The fling action will be ignored until the last finger leave the screen
			if events.size() == 0:
				ignore_fling = false

	# If move while zooming is set true it means that the event stored
	# have to stay in the dictionary to allow the camera to move
	# Otherwise it can be erased
	if (not move_while_zooming and handle_mouse_events
			and event is InputEventMouseButton
			and event.get_button_index() != BUTTON_LEFT):
		# Checks if the key exists
		if events.has(0):
			# Erases this event from the dictionary
			events.erase(0)

	# If it's a motion
	if ((event is InputEventScreenDrag)
			or (handle_mouse_events and event is InputEventMouseMotion)):

		# If the camera is moving. Updates the start position every 0.02 seconds
		# This is needed to avoid fling the camera after the user perform a swipe
		# action, e.g. when the user moves the camera very fast and stops while
		# keep the finger on the screen
		if duration > 0.02 and is_moving and not ignore_fling:
			fling_time = duration
			duration = 0.0001
			end_position = start_position
			start_position = event.position

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
				var new_zoom: Vector2

				# If the pinch distance is lower than the last pinch distance
				# it means that a zoom-out action is happening
				if pinch_distance < last_pinch_distance:
					new_zoom = (zoom + zoom_increment)

				# Otherwise a zoom-in
				else:
					new_zoom = (zoom - zoom_increment)

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

				# Stores the current pinch_distance as the last for future use
				last_pinch_distance = pinch_distance

	# If the mouse events is set to be handled
	elif handle_mouse_events:
		if event is InputEventMouseButton and event.is_pressed():

			# Wheel up = zoom-in
			if event.get_button_index() == BUTTON_WHEEL_UP:
				if zoom_at_point:
					zoom_at(zoom - zoom_increment, event.position)
				else:
					zoom_at(zoom - zoom_increment, position)

			# Wheel down = zoom-out
			if event.get_button_index() == BUTTON_WHEEL_DOWN:
				if zoom_at_point:
					zoom_at(zoom + zoom_increment, event.position)
				else:
					zoom_at(zoom + zoom_increment, position)


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


# Checks if the camera was flinged with a velocity greater than the minimum allowed
# and calculate the x/y velocity and deceleration rate
func was_flinged(start_p: Vector2, end_p: Vector2, dt: float) -> bool:
	# Calculates the initial velocity of the action
	var vi: float = end_p.distance_to(start_p) / dt

	# Calculates how much time the animation will last
	duration = vi / deceleration

	# If the distance from the start point to the end divided by the time taken
	# to perform the action is greater or equals to the minimum fling velocity,
	# then the fling action was performed. Otherwise, the action was too
	# slow to be considered
	if vi >= min_fling_velocity:
		# Calculates the velocity for each axis
		velocity_x = (end_p.x - start_p.x) / dt
		velocity_y = (end_p.y - start_p.y) / dt

		# To avoid an axis from stop before the other, each one will have a its
		# own deceleration rate. Calculates the deceleration needed to the x and
		# y axis to take the same time to stop.
		dx = velocity_x / duration
		dy = velocity_y / duration
		return true

	# If the movement was too slow, ignore it
	else:
		return false


# Moves the camera based on the velocity
func fling(vx: float, vy: float, dt: float) -> void:
	# Calculates the remaining time of the animation
	duration -= dt

	# If there's time remaining...
	if duration > 0.0:
		# If some axis of the camera reach the limit calculates a new deceleration
		# to it stop in 0.2 seconds. It makes a bounce effect. The other axis will
		# continue to flying
		if position.x > valid_limit.size.x or position.x < valid_limit.position.x:
			dx = velocity_x / 0.2
		if position.y > valid_limit.size.y or position.y < valid_limit.position.y:
			dy = velocity_y / 0.2

		# Calculates the next camera's position for both axis
		var npx = position.x + vx * dt
		var npy = position.y + vy * dt

		# Moves the camera to the next position
		set_position(Vector2(npx, npy))

		# Calculates the next velocity for both axis considering the deceleration
		velocity_x = vx - dx * dt
		velocity_y = vy - dy * dt

	# Otherwise finishes the animation
	else:
		finish_flying()


# Finishes the animation
func finish_flying() -> void:
	is_flying = false
	duration = 0.0
	velocity_x = 0.0
	velocity_y = 0.0


# Sets the camera's zoom making sure it stays between the minimum and maximum
func set_zoom(new_zoom: Vector2) -> void:
	new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
	zoom = Vector2.ONE * new_zoom.x

	# If the zoom change the valid limits need to be calculated again
	calculate_valid_limits()


# Sets the zoom and positions the camera to keep the focused point at screen
func zoom_at(new_zoom: Vector2, point: Vector2) -> void:
	# Holds the difference between the updated and the current zoom
	var zoom_diff: Vector2
	zoom_diff = new_zoom - zoom

	# For some reason, sometimes the calculation for the next_zoom loses 0.000001
	# e.g. instead of increasing from 1.50 to 1.55 it changes to 1.549999 which
	# causes weird behaviours when changing the zoom. Stepifying new_zoom.x
	# prevents it
	new_zoom.x = stepify(new_zoom.x, 0.01)

	# Ensures that the zoom will reach the min/max value
	if ((zoom_diff.x > 0 and new_zoom.x < max_zoom + zoom_diff.x)
				or (zoom_diff.x < 0 and new_zoom.x > min_zoom + zoom_diff.x)):

			# If the camera's anchor is set to center
			if anchor_mode == ANCHOR_MODE_DRAG_CENTER:
				# Updates the focused point value to be relative to the center
				# of the screen
				point -= vp_size/2

			# Sets the new zoom and the camera's position to keep the focus
			# point on screen
			set_zoom(new_zoom)
			set_position(position - (point * zoom_diff))


# Returns if the camera's position is out of the valid limit
func is_camera_out_of_limit() -> bool:
	return (position.x < valid_limit.position.x
				or position.x > valid_limit.size.x
				or position.y < valid_limit.position.y
				or position.y > valid_limit.size.y)


# Calculates the valid limits for the camera's position relative to the anchor mode
# The anchor mode and the zoom can affect the limit of the camera.
#
# Originally, if the anchor mode is set to, for exemple, Top Left, and you set a limit
# at 1000x1000, the camera will stop render when its position reach the 1000x1000,
# however with the anchor at the top left, the position of the camera will be relative to
# the top left pixel of the viewport. But the bottom left pixel will be after that.
# In other words the camera will render more than you want.
#
# This function calculate another limit based on the one you set at the properties
# panel, restricting the camera's position ensuring that the viewport will be
# always inside the limits. So the left side of the viewport will never be less
# than the left limit, as well as the right side won't be bigger than the right
# limit. The same with the top and bottom. Independent of the anchor mode
func calculate_valid_limits() -> void:
	var offset: Vector2
	valid_limit.position = base_limits.position
	valid_limit.size = base_limits.size

	# If the camera's anchor is set to center, to make sure the camera's
	# position stays inside the scroll limits
	if anchor_mode == ANCHOR_MODE_DRAG_CENTER:
		offset = vp_size / 2
		valid_limit.position += offset * zoom

	# If the anchor is set to top left, the left/top limits are not influenced
	# by the offset. Consequently the offset for bottom/right limits are the
	# entire viewport times the zoom
	elif anchor_mode == ANCHOR_MODE_FIXED_TOP_LEFT:
		offset = vp_size

	# Adjusts the base limit size and position relative to the offset times the zoom
	valid_limit.size -= offset * zoom


# Sets the camera's position making sure it stays between the limits
func set_position(new_position: Vector2) -> void:
	# If is to stop the camera on limit
	if stop_on_limit:
		# Makes sure that the camera's position stays between the limits
		position.x = clamp(new_position.x, valid_limit.position.x, valid_limit.size.x)
		position.y = clamp(new_position.y, valid_limit.position.y, valid_limit.size.y)

	else:
		# Otherwise continue moving the camera
		position.x = new_position.x
		position.y = new_position.y

		# And clamp the limit target so that the camera can return smoothly
		limit_target.x = clamp(new_position.x, valid_limit.position.x, valid_limit.size.x)
		limit_target.y = clamp(new_position.y, valid_limit.position.y, valid_limit.size.y)

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
