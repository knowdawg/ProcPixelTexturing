#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

//Merged radiance per ray (one layer per ray), produced by MergeRays.
layout(set = 0, binding = 0, rgba16f) uniform readonly image2DArray mergedRays;

//Cosine-convolved directional diffuse. One array layer per facing direction.
//rgb = diffuse for that facing angle, a = raw ray luminance at the nearest ray (sharp, for specular).
layout(set = 0, binding = 1, rgba16f) uniform writeonly image2DArray diffuseDirections;

layout(constant_id = 2) const int directionCount = 16; //output layers baked
layout(constant_id = 3) const int c1RayCountPerProbe = 16;

#define PI 3.141592

void main(){
    ivec2 probeCoord = ivec2(gl_GlobalInvocationID.xy);

    int halfSpan = c1RayCountPerProbe / 4; //rays within ~±90deg of the direction. The rest have cos<=0 -> 0
    float convScale = (2.0 * PI * PI) / float(c1RayCountPerProbe);

    for(int d = 0; d < directionCount; d++){
        float dirAngle = (float(d) / float(directionCount)) * 2.0 * PI;
        int center = int(round(float(d) / float(directionCount) * float(c1RayCountPerProbe))); //ray nearest dirAngle

        vec3 diffuse = vec3(0.0);
        float rawLum = 0.0;
        for(int k = -halfSpan; k <= halfSpan; k++){
            int i = (center + k + c1RayCountPerProbe) % c1RayCountPerProbe; //only the front hemisphere
            vec3 ray = imageLoad(mergedRays, ivec3(probeCoord, i)).rgb;

            float rayAngle = (float(i) / float(c1RayCountPerProbe)) * 2.0 * PI;
            diffuse += ray * max(0.0, cos(rayAngle - dirAngle));

            //center ray (k==0) is the nearest to dirAngle. Store its raw luminance for sharp specular
            if(k == 0) rawLum = dot(ray, vec3(0.2126, 0.7152, 0.0722));
        }

        imageStore(diffuseDirections, ivec3(probeCoord, d), vec4(diffuse * convScale, rawLum));
    }
}