// Ray-Tracing Technique (Note: Ray-Marching is more efficient)

#version 450 core
#extension GL_ARB_gpu_shader_fp64 : require

out vec4 fColor;

in vec2 posOnLens; // position of the fragment with respect to the center of the lens

uniform int maxIters;
uniform float power;
uniform int height;
uniform int width;
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
	vec3 v = coord;
	vec3 lastPos;
	// orbLen = 0;
	for ( i = 0; i < maxIters && length(v) < 2.0f; i++ )
	{
		lastPos = v;
		// Bulb iteration logic
		// --------------------
		//"exponentiate" the vector
		float initR = length(v);
		float r = pow(initR,power);
		float phi = atan(v.y/v.x);
		float theta = acos(v.z/initR);
		float x = sin(power*theta)*cos(power*phi);
		float y = sin(power*theta)*sin(power*phi);
		float z = cos(power*theta);
		// add c
		v = r*vec3(x,y,z) + c;

		// orbLen += length(v - lastPos);
	}

	if (i == maxIters) return true;
	else return false;
}

vec4 palette(float dist)
{
	if (dist >= maxDist) { return vec4(1,1,1,0.0f); }

	dist /= 4.0f; // make light more intense
	dist++; // so when we divide by dist^2 we get something <= 1
	float light = 1.0f / (dist*dist); // inverse square law

	// float s = sin(orbLen/(maxIters*0.2f) + 2.0f);
	// float c = cos(orbLen/(maxIters*0.2f) + 2.0f);
	float s = pow(sin(surfPosLen*20 + 0.0f),2);
	float c = pow(cos(surfPosLen*20 + 2.0f),2);
	float r = 0.9f*s + 0.1f;
	float g = 0.9f*c + 0.1f;
	float b = 0.9f*s*c + 0.1f;
	return light*vec4(r,g,b, light*0.5f) + vec4(0,0,0, 0.5f);
}