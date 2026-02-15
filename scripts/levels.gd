class_name Levels
extends RefCounted

## Defines the job/level progression with different window scenarios.

const JOB_LIST: Array = [
	{
		"id": "tutorial",
		"name": "Your First Window",
		"description": "A lightly soiled residential window. Perfect for learning the ropes.",
		"base_pay": 25.0,
		"par_time": 60.0,
		"window_size": Vector2(1.5, 2.0),
		"dirt": {
			"grime": 0.5,
			"grease": 0.1,
			"mineral": 0.0,
			"paint": 0.0,
			"bio": 0.0,
		},
	},
	{
		"id": "residential_1",
		"name": "Suburban Home - Front",
		"description": "A neglected front window with dust and fingerprints.",
		"base_pay": 40.0,
		"par_time": 90.0,
		"window_size": Vector2(2.0, 2.5),
		"dirt": {
			"grime": 0.7,
			"grease": 0.3,
			"mineral": 0.05,
			"paint": 0.0,
			"bio": 0.0,
		},
	},
	{
		"id": "residential_2",
		"name": "Kitchen Window",
		"description": "Greasy kitchen window with cooking splatter buildup.",
		"base_pay": 55.0,
		"par_time": 120.0,
		"window_size": Vector2(1.8, 1.5),
		"dirt": {
			"grime": 0.4,
			"grease": 0.8,
			"mineral": 0.1,
			"paint": 0.0,
			"bio": 0.0,
		},
	},
	{
		"id": "storefront_1",
		"name": "Corner Shop",
		"description": "Storefront window with street grime and hard water stains.",
		"base_pay": 70.0,
		"par_time": 150.0,
		"window_size": Vector2(3.0, 2.5),
		"dirt": {
			"grime": 0.6,
			"grease": 0.2,
			"mineral": 0.5,
			"paint": 0.0,
			"bio": 0.1,
		},
	},
	{
		"id": "renovation",
		"name": "Post-Renovation Cleanup",
		"description": "Paint splatters and construction dust everywhere. Bring the razor!",
		"base_pay": 90.0,
		"par_time": 180.0,
		"window_size": Vector2(2.0, 2.5),
		"dirt": {
			"grime": 0.5,
			"grease": 0.1,
			"mineral": 0.2,
			"paint": 0.7,
			"bio": 0.0,
		},
	},
	{
		"id": "bird_window",
		"name": "The Bird Perch",
		"description": "This window is under a popular bird hangout. Use bio cleaner!",
		"base_pay": 80.0,
		"par_time": 150.0,
		"window_size": Vector2(2.0, 2.0),
		"dirt": {
			"grime": 0.3,
			"grease": 0.1,
			"mineral": 0.1,
			"paint": 0.0,
			"bio": 0.8,
		},
	},
	{
		"id": "office_1",
		"name": "Office Tower - Floor 15",
		"description": "City office window. Years of mineral buildup from rain and pollution.",
		"base_pay": 100.0,
		"par_time": 180.0,
		"window_size": Vector2(2.5, 3.0),
		"dirt": {
			"grime": 0.6,
			"grease": 0.2,
			"mineral": 0.7,
			"paint": 0.05,
			"bio": 0.15,
		},
	},
	{
		"id": "disaster",
		"name": "The Nightmare Window",
		"description": "Everything. All at once. Good luck.",
		"base_pay": 150.0,
		"par_time": 300.0,
		"window_size": Vector2(3.0, 3.0),
		"dirt": {
			"grime": 0.8,
			"grease": 0.6,
			"mineral": 0.5,
			"paint": 0.4,
			"bio": 0.5,
		},
	},
]


static func get_job(index: int) -> Dictionary:
	if index >= 0 and index < JOB_LIST.size():
		return JOB_LIST[index]
	return JOB_LIST[0]


static func get_job_count() -> int:
	return JOB_LIST.size()
