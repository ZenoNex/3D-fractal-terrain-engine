// Math.cpp (implementation of Camera::update)
#include "Math.hpp"
#include <GLFW/glfw3.h>

void Camera::update(float dt) {
    // (mouse + WASD handling omitted – plug your own input system)
    // Example placeholder:
    if (glfwGetKey(glfwGetCurrentContext(), GLFW_KEY_W) == GLFW_PRESS)
        position += front * speed * dt;
    if (glfwGetKey(glfwGetCurrentContext(), GLFW_KEY_S) == GLFW_PRESS)
        position -= front * speed * dt;
    // ... similarly for A/D, Space/CTRL, mouse look ...
}
