extends Node

# Story data loaded from JSON files in res://data/story/
# Each JSON file contains a flat object of node_key -> node_data.
# All files are merged into one dictionary at runtime.
#
# Node format:
#   "text"       : String — the story passage
#   "choices"    : Array of { "text", "next", optional "require_stat"/"require_value"/"require_item" }
#   "gives_item" : (optional) String — item added to inventory when entering this node
#   "uses_item"  : (optional) String — item consumed when entering this node

const STORY_DIR := "res://data/story/"

var story: Dictionary = {}

func _ready() -> void:
	_load_all_story_files()

func _load_all_story_files() -> void:
	story = {}
	var dir := DirAccess.open(STORY_DIR)
	if dir == null:
		push_error("StoryData: Could not open story directory: %s" % STORY_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_load_story_file(STORY_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("StoryData: Loaded %d nodes from %s" % [story.size(), STORY_DIR])

func _load_story_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("StoryData: Could not open file: %s" % path)
		return
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_error("StoryData: JSON parse error in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return
	var data: Dictionary = json.data
	for key in data:
		if story.has(key):
			push_warning("StoryData: Duplicate node key '%s' in %s — overwriting!" % [key, path])
		story[key] = data[key]

func get_node_data(node_key: String) -> Dictionary:
	if story.has(node_key):
		return story[node_key]
	push_error("StoryData: Node not found: '%s'" % node_key)
	return {"text": "Error: Story node '%s' not found." % node_key, "choices": []}
