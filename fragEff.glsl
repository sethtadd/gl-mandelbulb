// Efficient Ray-Marching technique

#version 450 core
#extension GL_ARB_gpu_shader_fp64 : require

layout (location = 0) out vec4 fColor;

in vec2 posOnLens; // position of the fragment with respect to the center of the lens

uniform vec3 bgColor;
uniform int maxIters;
uniform float power;
uniform bool reflections;
// camera description
uniform float scale;
uniform float zoom;
uniform vec3 lightPos;
uniform vec3 camPos;
uniform vec3 frontDir;
uniform vec3 rightDir;
uniform vec3 upDir;

float maxDist = 200.0f; // clip distance

vec3 dirLight = vec3(0,1,0) * 0.9f; // dir * mag
vec3 pointLight = vec3(-3,0,0);

float distToSurf(vec3 init, vec3 rayDir);
float marchStep(vec3 coord);
vec3 normal(vec3 v);
vec4 lighting(vec3 lensPointPos, vec3 lensRay, vec3 surfPoint, float surfDist);
vec4 palette(float coords);
vec3 vecPow(vec3 z, float n);

void main()
{
	// get normalized position of current fragment(pixel) on "camera lens"
	vec3 fPosNorm = camPos + posOnLens.x * rightDir + posOnLens.y * upDir;
	// vec3 fPosNorm = camPos + posOnLens.x * rightDir * zoom + posOnLens.y * upDir * zoom;

	// Paralax, light source is a point behind camera
	vec3 lensRay = normalize(fPosNorm - lightPos);

	// shoot light ray from this position and determine distance to surface of Bulb
	float surfDist = distToSurf(fPosNorm, lensRay);
	vec3 pointOnSurf = fPosNorm + surfDist * lensRay;

	// get color of pixel based on how far it is from the Bulb's surface
	vec4 light = lighting(fPosNorm, lensRay, pointOnSurf, surfDist);
	distToSurf(fPosNorm, lensRay);
	vec4 color = palette(length(pointOnSurf));
	float r = light.r * color.r;
	float g = light.g * color.g;
	float b = light.b * color.b;
	float a = light.a * color.a;

	vec4 tunnel = 0.2f*vec4(pow(abs(length(posOnLens)),6));
	tunnel.a *= -1;

	fColor = vec4(r,g,b,a) - tunnel;
}

float distToSurf(vec3 init, vec3 rayDir)
{
	float dist = 0;
	int iters = maxIters;

	vec3 stepVec = rayDir;
	vec3 rayCoord = init; // begin at the light source

	// ray march until we're within a certain distance of the Bulb's surface
	while (dist < maxDist && bool(iters--))
	{
		float stepLen = marchStep(rayCoord) / 2; // smaller step size for more accuracy (divide by 2)
		rayCoord += stepVec * stepLen;
		dist += stepLen;

		if (abs(stepLen) < 0.001f) { return dist; } // try without abs? shouldn't need unless the ray marches back and forth across the surface a few times
	}

	return maxDist;
}

// approximate the distance to surface of Bulb... WHY TF DOES THIS WORK, SINCE I'M ONLY CALCULATING VECTOR MAGNITUDES????
float marchStep(vec3 coord)
{
	coord *= scale;
	vec3 z = coord * zoom; // z // multpilying here by a scalar does wack stuff!
	float r = length(z); // |z|
	float dr = 1; // |z'|

	int iters = maxIters;

	while (r < 2.0f && bool(iters--))
	{
		// dr
		float rn = pow(r,power-1);
		dr = power*rn*dr + 1;

		// z
		z = vecPow(z,power) + coord;

		// r
		r = length(z);
	}

	// d = G(c) / G'(c)
	return abs(log(r) * r / dr);
}

vec3 normal(vec3 v)
{
	float d = 0.005f;

	// these seem negative, maybe it's cause marchStep() returns negatives for |z|<1 ????
	float x = marchStep(v-vec3(d,0,0)) - marchStep(v+vec3(d,0,0));
	float y = marchStep(v-vec3(0,d,0)) - marchStep(v+vec3(0,d,0));
	float z = marchStep(v-vec3(0,0,d)) - marchStep(v+vec3(0,0,d));

	return normalize(vec3(x,y,z));
}

vec3 vecPow(vec3 v, float n)
{
	float initR = length(v);
	float r = pow(initR,n);

	float phi = atan(v.y/v.x);
	float theta = acos(v.z/initR);

	float x = sin(n*theta)*cos(n*phi);
	float y = sin(n*theta)*sin(n*phi);
	float z = cos(n*theta);

	return r * vec3(x,y,z);
}

vec4 palette(float radius)
{
	// return vec4(1);
	radius *= scale;
	float r = sin(radius * 2.0f + 0.5f);
	float g = cos(radius * 4.0f + 2.0f);
	float b = cos(r*g*20 + 1.0f);
	return vec4(r,g,b,1.0f);
}

vec4 lighting(vec3 lensPointPos, vec3 lensRay, vec3 surfPoint, float surfDist)
{
	if (surfDist >= maxDist) return vec4(0);

	// surfDist /= 1.0f; // make light more intense
	// surfDist++; // so when we divide by dist^2 we get something <= 1
	// float light = 1.0f / (surfDist*surfDist); // inverse square law

	vec3 totalLight = vec3(0);

	float ambient = 0.1f;
	totalLight += ambient;

	// use point light instead of dir
	dirLight = surfPoint - pointLight;

	// create shadows
	if ( distToSurf(surfPoint-dirLight*0.01f, -dirLight) < maxDist ) return vec4(totalLight,1);

	vec3 surfNorm = normal(surfPoint);

	// SPECULAR LIGHT
	float shininess = 0.7;
	vec3 reflection = reflect(-dirLight, surfNorm);
	float specular = 0.8f*pow(max(dot(lensRay, reflection), 0), shininess);

	// DIFFUSE LIGHT
	float diffuse = /*max((1.0f - 2*shininess),0)*/0.1*max(dot(surfNorm, dirLight), 0);

	// REFLECTED LIGHT
	vec3 refl = vec3(0);
	if (reflections)
	{
		// vector pointing from the surface to the camera lens
		vec3 lensToSurf = lensRay;
		// vector TO the point FROM whatever's being reflected
		vec3 reflRay = normalize(reflect(lensToSurf, surfNorm)); // reflect(rayFromLightSource, normal)
		// check distance to intersection when emmiting ray from point in the direction of reflRay
		float reflRayDist = distToSurf(surfPoint + reflRay*0.1f, reflRay);
		vec3 reflIntersect = surfPoint + reflRay * reflRayDist;
		// inverse square law
		float refLight = min(shininess*1.5f,1) * (maxDist*maxDist/2) / (reflRayDist * reflRayDist + maxDist*maxDist/2); // +1 so we have refLight <= 1
		// color the reflection
		vec3 color = reflRayDist < maxDist ? palette(length(reflIntersect)).rgb : bgColor;
		float reflDiffuse = max( dot( reflect(reflRay,normal(reflIntersect)), -dirLight ), 0);
		refl = refLight * color * reflDiffuse;
	}

	totalLight += specular + diffuse + refl;

	return vec4(totalLight, 1);
}