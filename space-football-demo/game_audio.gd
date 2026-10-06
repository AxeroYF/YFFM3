extends AudioStreamPlayer
## Owns generated sound playback and sample state. The application schedules buffer fills.
var enabled:=true:
 set(value):
  enabled=value
  if not enabled: sound_left=0
var sound_playback: AudioStreamGeneratorPlayback
var sound_left := 0.0
var sound_phase := 0.0
var sound_freq := 400.0
var sound_impact:=false
var sound_age:=0.0
var sound_power:=0.5

func start() -> void:
 var generator:=AudioStreamGenerator.new()
 generator.mix_rate=22050
 generator.buffer_length=0.15
 stream=generator
 volume_db=-16
 play()
 sound_playback=get_stream_playback()

func beep(frequency: float, duration: float) -> void:
 if enabled:
  sound_impact=false
  sound_freq=frequency
  sound_left=duration

func kick_sound(power:float)->void:
 if not enabled: return
 sound_impact=true;sound_age=0;sound_phase=0;sound_power=clampf(power,0,1);sound_left=0.12

func fill_buffer() -> void:
 if sound_playback==null: return
 var count:=mini(sound_playback.get_frames_available(),3300)
 for i in count:
  var value:=0.0
  if sound_left>0:
   if sound_impact:
    value=(sin(sound_phase)*exp(-sound_age*30)*0.60+sin(sound_phase*13.7)*exp(-sound_age*100)*0.14)*(0.55+sound_power*0.45)
    sound_phase+=TAU*(55+75*exp(-sound_age*45))/22050.0;sound_age+=1.0/22050.0
   else:
    value=sin(sound_phase)*minf(1,sound_left*15)*0.35
    sound_phase+=TAU*sound_freq/22050.0
   sound_left-=1.0/22050.0
  sound_playback.push_frame(Vector2(value,value))
