extends RefCounted
## The same generated manifest travels in source and exported builds.
static var cached:=""
static func fingerprint()->String:
 if not cached.is_empty(): return cached
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://network-build.json"))
 if not data is Dictionary or data.get("format")!=1 or not data.get("files") is Dictionary: return ""
 var names:Array=data.files.keys();names.sort()
 var combined:=""
 for name in names:
  # Editor/source builds must not silently use a stale release identity. Exported
  # scripts are compiled; their manifest is checked by the packaging workflow.
  if OS.has_feature("editor") or str(name).ends_with(".json"):
   if not FileAccess.file_exists("res://"+name): return ""
   var actual:=FileAccess.get_file_as_string("res://"+name).replace("\r\n","\n").sha256_text()
   if actual!=data.files[name]: return ""
  combined+=str(name)+":"+str(data.files[name])+"\n"
 cached=combined.sha256_text()
 if cached!=data.get("fingerprint",""): cached=""
 return cached
