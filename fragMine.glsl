// Ray-Tracing Technique (Note: Ray-Marching is more efficient)

#version 450 core
#extension GL_ARB_gpu_shader_fp64 : require

out vec4 fColor;

in vec2 posOnLens; // position of the fragment with respect to the center of the lens

uniform int maxIters;
uniform float power;
// camera description
uniform float scale;
uniform vec3 lightPos;
uniform vec3 camPos;
uniform vec3 frontDir;
uniform vec3 rightDir;
uniform vec3 upDir;

float maxDist = 10.0f; // clip distance

float surfPosLen;
// float orbLen; // length of orbit path

float distToSurf(vec3 init);
bool onSurf(vec3 coord);
vec2 vecSqrd(vec2 v);
vec4 palette(float coords);

void main()
{
	// get normalized position of current fragment(pixel) on "camera lens"
	vec3 fPosNorm = camPos + posOnLens.x * rightDir + posOnLens.y * upDir;
	
	// shoot light ray from this position and determine distance to surface of Bulb
	float dist = distToSurf(fPosNorm);

	// get color of pixel based on how far it is from the Bulb's surface
	fColor = palette(dist);
}

float distToSurf(vec3 init)
{
	float stepLen = 0.01f;
	// vec3 stepVec = frontDir * stepLen; // Orthographic Perspective, light shoots perpendicularly from camera lens
	vec3 stepVec = normalize(init - lightPos) * stepLen; // Paralax, light source is a point behind camera
	vec3 rayCoord = init; // begin at the light source
	
	while (length(rayCoord - init) < maxDist && !onSurf(rayCoord)) // bail at certain distance from camera (clip)
	{
		// if ray is moving away from origin and is outside of sphere-of-possible-convergence then return maxDist because the ray will never intersect the Bulb
		if (dot(stepVec,rayCoord) >= 0 && length(rayCoord) > 2.0f / scale) return maxDist;
		else rayCoord += stepVec;
	}
	
	surfPosLen = length(rayCoord);

	return length(init - rayCoord); // distance ray traveled
}

bool onSurf(vec3 coord)
{
	coord *= scale;

	int i;

	vec3 c = coord;
	vec3 v1 = coord;
	vec3 v2 = coord;

	vec3 v = coord;

	for (i = 0; i < maxIters && length(v) < 2.0f; i++ )
	{
		v1 = vec3((vecSqrd(v.xy) + c.xy), 0);
		vec2 temp = (vecSqrd(vec2(v.x,-v.z)) + c.xz);
		v2 = vec3(temp.x, 0, temp.y);

		v += ((v1 - v)/**(i%2)*/ + (v2 - v)/**((i+1)%2)*/)/8;
	}

	if (i == maxIters) return true;
	else return false;
}

vec2 vecSqrd(vec2 v)
{
	double a = v.x, b = v.y, b_temp;

	b_temp = 2 * a * b;
    a = a * a - b * b;
    b = b_temp;

	return vec2(a,b);
}

vec4 palette(float dist)
{
	if (dist >= maxDist) return vec4(0);
	else return vec4(vec3(1/(dist*dist+1)),1);
}