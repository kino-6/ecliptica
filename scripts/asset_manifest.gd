extends RefCounted
class_name AssetManifest

const DEFAULT_PATH := "res://assets/manifest.yaml"

var entries := {}
var warning_text := "PLACEHOLDER ASSET"

func load_from_file(path := DEFAULT_PATH) -> void:
	_load(path)

func texture_path(asset_id: String, fallback := "") -> String:
	var entry := get_entry(asset_id)
	if entry.is_empty():
		return fallback
	return String(entry.get("path", fallback))

func is_placeholder(asset_id: String) -> bool:
	var entry := get_entry(asset_id)
	return String(entry.get("kind", "")) == "placeholder" or String(entry.get("path", "")).contains("/placeholder/")

func active_placeholder_ids() -> Array[String]:
	var ids: Array[String] = []
	for asset_id in entries.keys():
		if is_placeholder(String(asset_id)):
			ids.append(String(asset_id))
	ids.sort()
	return ids

func has_placeholder_assets() -> bool:
	return not active_placeholder_ids().is_empty()

func get_entry(asset_id: String) -> Dictionary:
	if not entries.has(asset_id):
		return {}
	return entries[asset_id]

func _load(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var current_section := ""
	var current_asset := ""
	for raw_line in text.split("\n"):
		var line := _strip_comment(raw_line)
		if line.strip_edges().is_empty():
			continue
		var indent := line.length() - line.strip_edges(true, false).length()
		var trimmed := line.strip_edges()
		if indent == 0:
			if trimmed.ends_with(":"):
				current_section = trimmed.trim_suffix(":")
				current_asset = ""
			else:
				var pair := _split_pair(trimmed)
				if pair[0] == "placeholder_warning":
					warning_text = String(pair[1])
			continue
		if current_section != "assets":
			continue
		if indent == 2 and trimmed.ends_with(":"):
			current_asset = trimmed.trim_suffix(":")
			entries[current_asset] = {}
			continue
		if indent >= 4 and current_asset != "":
			var pair := _split_pair(trimmed)
			if pair[0] != "":
				entries[current_asset][pair[0]] = pair[1]

func _strip_comment(line: String) -> String:
	var comment_index := line.find("#")
	if comment_index < 0:
		return line
	return line.substr(0, comment_index)

func _split_pair(line: String) -> Array:
	var colon := line.find(":")
	if colon < 0:
		return ["", ""]
	var key := line.substr(0, colon).strip_edges()
	var value := line.substr(colon + 1).strip_edges()
	return [key, _parse_value(value)]

func _parse_value(value: String) -> Variant:
	if value == "null":
		return null
	if value.begins_with("[") and value.ends_with("]"):
		var inner := value.substr(1, value.length() - 2).strip_edges()
		if inner.is_empty():
			return []
		var parsed := []
		for item in inner.split(","):
			parsed.append(_parse_scalar(item.strip_edges()))
		return parsed
	return _parse_scalar(value)

func _parse_scalar(value: String) -> Variant:
	if value.is_valid_int():
		return int(value)
	if value.is_valid_float():
		return float(value)
	return value.trim_prefix("\"").trim_suffix("\"")
