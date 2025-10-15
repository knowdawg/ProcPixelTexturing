shader_type canvas_item;

uniform sampler2D image : filter_nearest;
uniform float offset;

void fragment(){
   float closestDist = 9999999.9;
   vec2 closestPos = vec2(0.0);

   for(float x = -1.0; x <= 1.0; x += 1.0){
      for(float y = -1.0; y <= 1.0; y += 1.0){
         vec2 voffset = UV;
         voffset += vec2(x, y) * SCREEN_PIXEL_SIZE * offset;

         vec2 pos = texture(image, voffset).xy;
         float dist = distance(pos.xy, UV.xy);

         if(pos.x != 0.0 && pos.y != 0.0 && dist < closestDist){
            closestDist = dist;
            closestPos = pos;
         }
      }
   }
   COLOR = vec4(closestPos, 0.0, 1.0);
}

