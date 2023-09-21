#version 450 core
#extension GL_ARB_gpu_shader_fp64 : require

layout (location = 0) in vec2 vPos; // interpolated vertex position

out vec2 posOnLens; // coordinates on quad surface

uniform float aspectRatio;

void main()
{
	// interpolated vertex position
	posOnLens = vec2(vPos.x, vPos.y / aspectRatio); // scale vertical axis to undo distortion
	gl_Position = vec4(vPos, 0.0f, 1.0f);
}