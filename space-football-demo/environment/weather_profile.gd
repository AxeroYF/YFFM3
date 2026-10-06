extends Resource
## Authored configuration. Treat loaded profiles as immutable at runtime.
@export var display_name:String="晴朗"
@export var rain:bool=false
@export var wind_mean:float=0.0
@export var wind_gust:float=0.0
@export var wind_frequency:float=0.7
@export var surface_grip:float=1.0
@export var rolling_drag:float=1.0
@export var ball_restitution:float=0.32
@export var wetness:float=0.0
@export var visual_wind:float=0.1
@export var lightning:bool=false
@export var first_flash_delay:Vector2=Vector2(3.5,6.5)
@export var flash_interval:Vector2=Vector2(8.0,16.0)
@export var flash_duration:float=0.48
@export var flash_energy:float=0.70

func windy()->bool:
 return wind_mean!=0.0 or wind_gust!=0.0

func wind_at(seconds:float)->float:
 return wind_mean+wind_gust*sin(seconds*wind_frequency)
