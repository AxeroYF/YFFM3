extends RefCounted
## Per-step values; callers cannot mutate shared configuration resources through this object.
var gravity_scale:float=1.0
var rolling_drag:float=1.0
var restitution:float=0.32
var solar_wind:float=0.0
var crosswind:float=0.0
