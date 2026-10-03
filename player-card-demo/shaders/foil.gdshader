shader_type canvas_item;
uniform int theme_id=0;
uniform float clock=0.0;
uniform vec2 pointer=vec2(0);
uniform float hover=0.0;
void fragment(){
 vec2 u=UV;
 float sweep=pow(max(0.0,1.0-abs(u.x*0.7+u.y*0.35-fract(clock*0.055+float(theme_id)*0.28)*1.65+0.25)*7.0),3.0);
 float sheen=pow(max(0.0,1.0-abs(u.x-u.y*0.35-0.35-pointer.x*0.6)*3.0),5.0)*hover;
 vec3 c=theme_id==0?vec3(1.0,0.76,0.36):theme_id==1?vec3(0.20,0.78,1.0):0.65+0.35*cos(vec3(0,2,4)+u.y*6.0+pointer.x*3.0+clock*0.2);
 float edge=pow(max(abs(u.x-0.5)*2.0,abs(u.y-0.5)*2.0),22.0);
 float cut=step(0.035,u.x+u.y)*step(0.035,1.0-u.x+u.y)*step(0.035,u.x+1.0-u.y)*step(0.035,2.0-u.x-u.y);
 COLOR=vec4(c,(sweep*0.09+sheen*0.075+edge*sweep*0.4)*cut);
}
