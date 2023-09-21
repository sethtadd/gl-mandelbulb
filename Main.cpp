/* Mandelbulb Renderer
 *
 * Created by Seth Taddiken!
 * MM/DD/YYYY: 3/24/2019
 *
 * ----- Resources Used -----------------------------------------------
 * | - GLAD (OpenGL function-pointer-loading library)                 |
 * | - GLFW (OpenGL Framework: Window-creating library)               |
 * | - GLM (OpenGL Mathematics: Vector and matrix operations library) |
 * -------------------------------------------------------------------- */

#include <string>
#include <cmath>
#include <iostream>

#include <glad\glad.h>
#include <GLFW\glfw3.h>
#include <glm\glm.hpp>
#include <glm\gtc\matrix_transform.hpp>

#include "Shader.h"

const float GOLDEN_RATIO = 1.61803398875f;

float aspectRatio = GOLDEN_RATIO;

int width = 1000;
int height = width / aspectRatio;

float fov = 40; // in degrees
glm::vec3 bgColor = glm::vec3(0.0f, 0.3f, 0.28f);

unsigned int frameCount;

// mouse coordinates, WARNING: mouseX and mouseY are only initialized when mouse first moves
bool mouseInit = false; // true when mouse has been moved at least once
float mouseX;
float mouseY;

// Bulb's initial power
float power = 8;

float maxIters = 60;
bool reflections = false;
bool reflectionsPrimed = false;

// Camera
struct Camera
{
	float moveSpeed;
	float rotSpeed;
	float scaleSpeed;
	float scale;
	float zoom;
	float zoomSpeed;

	glm::vec3 lightPos;

	glm::vec3 pos;
	glm::vec3 frontDir;
	glm::vec3 rightDir;
	glm::vec3 upDir;
} cam;

// Timing Logic
// ------------
float deltaTime = 0.0f;
float lastFrameTime = 0.0f;

bool initGLFW(GLFWwindow **window);
void processInput(GLFWwindow *window);
void rotateCamera(glm::vec3 about, float amount);

// callback functions
void mouse_callback(GLFWwindow *window, double xPos, double yPos);		  // rotating camera / looking around
void scroll_callback(GLFWwindow *window, double xOffset, double yOffset); // scaling
void framebuffer_size_callback(GLFWwindow* window, int newWidth, int newHeight); // resizing window

int main(void)
{
	GLFWwindow *window;

	// initialize GLFW
	if (!initGLFW(&window))
	{
		std::cout << "Failed to create GLFW window" << std::endl;
		return -1;
	}
	// set callback functions
	glfwSetCursorPosCallback(window, mouse_callback);
	glfwSetScrollCallback(window, scroll_callback);
	glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

	// initialize GLAD
	if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
	{
		std::cout << "Failed to initialize GLAD" << std::endl;
		return -1;
	}

	glViewport(0,0,width,height);

	// Initialize Camera
	cam.moveSpeed = 1.5;
	cam.rotSpeed = 1;
	cam.scaleSpeed = 0.1;
	cam.zoomSpeed = 0.01;
	cam.scale = 1;
	cam.zoom = 1;
	cam.lightPos = glm::vec3(0, 0, -2 - 1.402232f);
	cam.pos = glm::vec3(0, 0, -2);
	cam.frontDir = glm::vec3(0, 0, 1);
	cam.rightDir = glm::vec3(1, 0, 0);
	cam.upDir = glm::vec3(0, 1, 0);

	// Initialize shader using source code from "shader.vs" (vertex shader code) and "shader.fs" fragment shader code

	Shader shader("vert.glsl", "fragEff.glsl");
	shader.use();

	// Create rectangle, this will be the screen and represents the camera lens surface
	float vertices[8] = {
		-1.0f, -1.0f,
		1.0f, -1.0f,
		1.0f, 1.0f,
		-1.0f, 1.0f};

	unsigned int indices[6] = {
		0, 1, 3,
		1, 2, 3};

	unsigned int VAO;
	unsigned int VBO;
	unsigned int EBO;

	glGenVertexArrays(1, &VAO);
	glGenBuffers(1, &VBO);
	glGenBuffers(1, &EBO);

	glBindVertexArray(VAO);
	glBindBuffer(GL_ARRAY_BUFFER, VBO);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);

	glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void *)(0));
	glEnableVertexAttribArray(0);

	glBindVertexArray(0);

	// OpenGL-Machine settings
	glClearColor(bgColor.r, bgColor.g, bgColor.b, 1.0f);						 // set clear color
	glEnable(GL_BLEND);											 // blend colors with alpha
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);			 // alpha settings
	glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED); // disable cursor

	// render loop
	for (frameCount = 0; !glfwWindowShouldClose(window); frameCount++)
	{
		// Timing Logic
		float currentFrameTime = (float)glfwGetTime();
		deltaTime = currentFrameTime - lastFrameTime;
		lastFrameTime = currentFrameTime;
		if (frameCount % 100 == 0)
		{
			printf("FPS: %f\n", 1.0f / deltaTime);
		}

		glfwPollEvents();
		processInput(window);

		glClear(GL_COLOR_BUFFER_BIT); // clear back buffer

		// set shader uniforms
		shader.setFloat3("bgColor", bgColor);
		shader.setFloat("aspectRatio", aspectRatio);
		shader.setFloat("power", power);
		shader.setBool("reflections", reflections);
		shader.setInt("maxIters", (int)maxIters);
		shader.setFloat("zoom", cam.zoom);
		shader.setFloat("scale", cam.scale);
		shader.setFloat3("frontDir", cam.frontDir);
		shader.setFloat3("rightDir", cam.rightDir);
		shader.setFloat3("upDir", cam.upDir);
		shader.setFloat3("camPos", cam.pos);
		cam.lightPos = cam.pos - 0.5f/(float)asin(glm::radians(fov/2)) * cam.frontDir; // move the light-ray source behind the camera position such that the rays at either side of the width of the
		shader.setFloat3("lightPos", cam.lightPos);

		glBindVertexArray(VAO);
		glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0); // draw to back buffer
		glBindVertexArray(0);

		// Swap front/back buffers
		glfwSwapBuffers(window);
	}

	glDeleteBuffers(1, &EBO);
	glDeleteBuffers(1, &VBO);
	glDeleteVertexArrays(1, &VAO);

	glfwTerminate();
	return 0;
}

// More a convenience, this function encapsulates all of the initialization proceedures for creating a GLFW window
bool initGLFW(GLFWwindow **window)
{
	glfwInit();

	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 4);				   // set minimum OpenGL version requirement to OpenGL 3
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);				   // set maximum OpenGL version requirement to OpenGL 3
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE); // tell GLWF that we want to use the core profile of OpenGL
	glfwWindowHint(GLFW_RESIZABLE, GL_TRUE);					   // window is resizeable

	*window = glfwCreateWindow(width, height, "MangelbulbGL", /*glfwGetPrimaryMonitor()*/0, NULL);

	// Test for successful window creation
	if (window == NULL)
	{
		return false;
	}

	glfwMakeContextCurrent(*window);

	return true;
}

// This function is called every frame, updates values based on key states
void processInput(GLFWwindow *window)
{
	// exit program
	if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
	{
		glfwSetWindowShouldClose(window, GLFW_TRUE);
	}
	// move forward/backward
	if (glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT) == GLFW_PRESS)
	{
		cam.pos += cam.frontDir * cam.moveSpeed * cam.scale * deltaTime;
	}
	if (glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_RIGHT) == GLFW_PRESS)
	{
		cam.pos -= cam.frontDir * cam.moveSpeed * cam.scale * deltaTime;
		if (!(frameCount % 100))
			printf("cam dist: %f\n", glm::length(cam.pos));
	}
	// Bulb power
	if (glfwGetKey(window, GLFW_KEY_F) == GLFW_PRESS)
	{
		power += 0.01;
	}
	if (glfwGetKey(window, GLFW_KEY_G) == GLFW_PRESS)
	{
		power -= 0.01;
	}
	// iterations
	if (glfwGetKey(window, GLFW_KEY_V) == GLFW_PRESS)
	{
		maxIters += 0.5;
	}
	if (glfwGetKey(window, GLFW_KEY_C) == GLFW_PRESS && maxIters > 2)
	{
		maxIters -= 0.5;
	}
	// move speed
	if (glfwGetKey(window, GLFW_KEY_Z) == GLFW_PRESS)
	{
		cam.moveSpeed *= 1.05;
	}
	if (glfwGetKey(window, GLFW_KEY_X) == GLFW_PRESS && cam.moveSpeed > 0)
	{
		cam.moveSpeed /= 1.05;
	}
	// pan vertical
	if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
	{
		cam.pos += cam.upDir * cam.moveSpeed * cam.scale * deltaTime;
	}
	if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
	{
		cam.pos -= cam.upDir * cam.moveSpeed * cam.scale * deltaTime;
	}
	// pan horizontal
	if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
	{
		cam.pos += cam.rightDir * cam.moveSpeed * cam.scale * deltaTime;
	}
	if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
	{
		cam.pos -= cam.rightDir * cam.moveSpeed * cam.scale * deltaTime;
	}
	// camera roll
	if (glfwGetKey(window, GLFW_KEY_E) == GLFW_PRESS)
	{
		rotateCamera(cam.frontDir, cam.rotSpeed * 1.5f);
	}
	if (glfwGetKey(window, GLFW_KEY_Q) == GLFW_PRESS)
	{
		rotateCamera(-cam.frontDir, cam.rotSpeed * 1.5f);
	}
	// camera zoom
	if (glfwGetKey(window, GLFW_KEY_M) == GLFW_PRESS)
	{
		cam.zoom *= 1 + cam.zoomSpeed;
		printf("cam zoom: %f\n", cam.zoom);
	}
	if (glfwGetKey(window, GLFW_KEY_N) == GLFW_PRESS)
	{
		cam.zoom /= 1 + cam.zoomSpeed;
		printf("cam zoom: %f\n", cam.zoom);
	}
	// reflections toggling
	if (glfwGetKey(window, GLFW_KEY_R) == GLFW_PRESS)
	{
		reflectionsPrimed = true;
	}
	if (glfwGetKey(window, GLFW_KEY_R) != GLFW_PRESS && reflectionsPrimed)
	{
		reflections = !reflections;
		reflectionsPrimed = false;
	}
}

void rotateCamera(glm::vec3 about, float amount)
{
	glm::mat4 rot = glm::mat4(1.0f);
	rot = glm::rotate(rot, amount * deltaTime, glm::vec3(about));

	// WARNING this is implicitly casting vec4's to vec3's
	cam.frontDir = glm::vec4(cam.frontDir, 1.0f) * rot;
	cam.rightDir = glm::vec4(cam.rightDir, 1.0f) * rot;
	cam.upDir = glm::vec4(cam.upDir, 1.0f) * rot;
}

void mouse_callback(GLFWwindow *window, double xPos, double yPos)
{
	// prevent abrupt camera movement on first mouse movement by considering mouse's initial position
	if (!mouseInit)
	{
		mouseX = xPos;
		mouseY = yPos;
		mouseInit = true;
	}

	float xOffset = -(xPos - mouseX);
	float yOffset = -(yPos - mouseY); // mouse coordinates are reversed on y-axis

	mouseX = xPos;
	mouseY = yPos;

	rotateCamera(cam.upDir, xOffset);
	rotateCamera(cam.rightDir, yOffset);
}

void scroll_callback(GLFWwindow *window, double xOffset, double yOffset)
{
	if (yOffset < 0)
	{
		cam.scale *= 1 + cam.scaleSpeed;
	}

	if (yOffset > 0)
	{
		cam.scale /= 1 + cam.scaleSpeed;
	}

	// THIS DOESN'T WORK IDK WHY
	// cam.pos /= cam.scale;
}

void framebuffer_size_callback(GLFWwindow* window, int newWidth, int newHeight)
{
	height = newHeight;
	width = newWidth;
	aspectRatio = (float)width/height;
    glViewport(0, 0, width, height);
} 