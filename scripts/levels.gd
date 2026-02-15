class_name Levels
extends RefCounted

## Defines the job/level progression with different window scenarios.
## Jobs are ordered so the player naturally needs new tools/soaps as they progress:
##
## Job 1-2: Spray + Squeegee + General Soap only (starter gear)
## Job 3:   Sponge makes this much easier (available to buy after job 1)
## Job 4:   Degreaser soap needed (available after job 2)
## Job 5:   Bio cleaner helpful (available after job 2)
## Job 6:   Steel wool + mineral soap needed (available after job 3)
## Job 7:   Razor blade needed (available after job 4)
## Job 8:   Everything at once

const JOB_LIST: Array = [
	{
		"id": "tutorial",
		"name": "Your First Window",
		"description": "A lightly soiled residential window. Just spray and squeegee!",
		"base_pay": 25.0,
		"par_time": 60.0,
		"window_size": Vector2(1.5, 2.0),
		"dirt": {
			"grime": 0.5,
			"grease": 0.05,
			"mineral": 0.0,
			"paint": 0.0,
			"bio": 0.0,
		},
	},
	{
		"id": "residential_dusty",
		"name": "Dusty Porch Window",
		"description": "Thick dust on a back porch window. Good practice for the basics.",
		"base_pay": 35.0,
		"par_time": 75.0,
		"window_size": Vector2(1.8, 2.0),
		"dirt": {
			"grime": 0.7,
			"grease": 0.1,
			"mineral": 0.0,
			"paint": 0.0,
			"bio": 0.0,
		},
	},
	{
		"id": "residential_smudgy",
		"name": "Suburban Home - Front",
		"description": "Fingerprints and grime. A sponge would really help here...",
		"base_pay": 45.0,
		"par_time": 100.0,
		"window_size": Vector2(2.0, 2.5),
		"dirt": {
			"grime": 0.6,
			"grease": 0.35,
			"mineral": 0.05,
			"paint": 0.0,
			"bio": 0.0,
		},
	},
	{
		"id": "kitchen",
		"name": "Kitchen Window",
		"description": "Greasy cooking splatter. You'll want degreaser soap for this one.",
		"base_pay": 55.0,
		"par_time": 120.0,
		"window_size": Vector2(1.8, 1.5),
		"dirt": {
			"grime": 0.3,
			"grease": 0.8,
			"mineral": 0.05,
			"paint": 0.0,
			"bio": 0.0,
		},
	},
	{
		"id": "bird_window",
		"name": "The Bird Perch",
		"description": "This window sits under a popular bird hangout. Bio cleaner is a must!",
		"base_pay": 65.0,
		"par_time": 130.0,
		"window_size": Vector2(2.0, 2.0),
		"dirt": {
			"grime": 0.3,
			"grease": 0.1,
			"mineral": 0.05,
			"paint": 0.0,
			"bio": 0.7,
		},
	},
	{
		"id": "storefront",
		"name": "Corner Shop",
		"description": "Hard water stains from years of rain. Steel wool and mineral remover time.",
		"base_pay": 80.0,
		"par_time": 160.0,
		"window_size": Vector2(3.0, 2.5),
		"dirt": {
			"grime": 0.4,
			"grease": 0.15,
			"mineral": 0.65,
			"paint": 0.0,
			"bio": 0.1,
		},
	},
	{
		"id": "renovation",
		"name": "Post-Renovation Cleanup",
		"description": "Paint splatters and construction dust. Break out the razor blade!",
		"base_pay": 100.0,
		"par_time": 200.0,
		"window_size": Vector2(2.0, 2.5),
		"dirt": {
			"grime": 0.5,
			"grease": 0.1,
			"mineral": 0.15,
			"paint": 0.7,
			"bio": 0.0,
		},
	},
	{
		"id": "office_tower",
		"name": "Office Tower - Floor 15",
		"description": "City office window. Years of everything. Bring your full kit.",
		"base_pay": 120.0,
		"par_time": 200.0,
		"window_size": Vector2(2.5, 3.0),
		"dirt": {
			"grime": 0.6,
			"grease": 0.3,
			"mineral": 0.5,
			"paint": 0.1,
			"bio": 0.2,
		},
	},
	{
		"id": "disaster",
		"name": "The Nightmare Window",
		"description": "Everything. All at once. Good luck.",
		"base_pay": 175.0,
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
