// Math.hpp
#pragma once
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <glm/gtx/hash.hpp>

using Vec2 = glm::vec2;
using Vec3 = glm::vec3;
using Vec4 = glm::vec4;
using Mat4 = glm::mat4;
using Quat = glm::quat;

// ------------------------------------------------------------------
// Simple camera (fly-cam style)
struct Camera {
    Vec3 position{0, 0, 5};
    Vec3 front{0, 0, -1};
    Vec3 up{0, 1, 0};
    Vec3 right{1, 0, 0};
    float yaw = -90.0f, pitch = 0.0f;
    float speed = 12.0f, sensitivity = 0.08f;
    float lastX = 0.0f, lastY = 0.0f;
    bool firstMouse = true;

    void update(float dt, GLFWwindow* window);
    void processMouse(float xpos, float ypos);
    Mat4 viewMatrix() const { return glm::lookAt(position, position + front, up); }
};

// ------------------------------------------------------------------
inline uint64_t mortonEncode(glm::uvec3 p) {
    uint64_t mort = 0;
    for (int i = 0; i < 21; ++i) { // 21 bits per axis → 63-bit key
        mort |= ((p.x >> i) & 1ull) << (3ull * i + 0ull);
        mort |= ((p.y >> i) & 1ull) << (3ull * i + 1ull);
        mort |= ((p.z >> i) & 1ull) << (3ull * i + 2ull);
    }
    return mort;
}
