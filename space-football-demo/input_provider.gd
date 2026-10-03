extends RefCounted
## Future platform adapter contract. No touch controls are instantiated on desktop.
## Android can supply multitouch joystick/buttons by implementing these two methods.
## Preserve press/release edges for charge shots and passes. Emit action bits once.
## power is 0..1; direction is a separate normalized switch/skill direction.
## Menu navigation stays outside commands; a substitution submits out/reserve indices.
func sample()->Dictionary:
 return {"move":Vector2.ZERO,"sprint":false,"jockey":false,"action":0,"aim":0.0,"tactic":1,"finesse":false,"chip":false,"keeper_rush":false,"power":0.35,"direction":Vector2.ZERO,"driven":false,"contain":false,"out":1,"reserve":0}

func reset()->void:
 pass
