// VulkanContext.hpp
#pragma once
#include <vulkan/vulkan.hpp>
#include <GLFW/glfw3.h>
#include <glm/glm.hpp>
#include <vector>
#include <optional>

struct QueueFamilyIndices {
    std::optional<uint32_t> graphics;
    std::optional<uint32_t> compute;
    std::optional<uint32_t> present;
    bool isComplete() const { return graphics && compute && present; }
};

class VulkanContext {
public:
    VulkanContext();
    ~VulkanContext();

    void initWindow(uint32_t w, uint32_t h, const char* title);
    bool shouldClose() const { return glfwWindowShouldClose(window); }
    void pollEvents() const { glfwPollEvents(); }

    // Core objects
    VkInstance       instance = VK_NULL_HANDLE;
    VkDebugUtilsMessengerEXT debugMessenger = VK_NULL_HANDLE;
    VkSurfaceKHR     surface = VK_NULL_HANDLE;
    VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
    VkDevice         device = VK_NULL_HANDLE;
    VkQueue          graphicsQueue = VK_NULL_HANDLE;
    VkQueue          computeQueue  = VK_NULL_HANDLE;
    VkQueue          presentQueue  = VK_NULL_HANDLE;
    VkSwapchainKHR   swapchain = VK_NULL_HANDLE;
    VkFormat         swapchainFormat = VK_FORMAT_UNDEFINED;
    VkExtent2D       swapchainExtent{};
    std::vector<VkImage>     swapchainImages;
    std::vector<VkImageView> swapchainImageViews;
    VkRenderPass     renderPass = VK_NULL_HANDLE;
    std::vector<VkFramebuffer> swapchainFramebuffers;
    VkCommandPool    commandPool = VK_NULL_HANDLE;
    std::vector<VkCommandBuffer> commandBuffers;

    // Synchronization
    std::vector<VkSemaphore> imageAvailableSemaphores;
    std::vector<VkSemaphore> renderFinishedSemaphores;
    std::vector<VkFence>     inFlightFences;
    size_t currentFrame = 0;

    // Helper methods
    VkCommandBuffer beginSingleTimeCommands();
    void endSingleTimeCommands(VkCommandBuffer cb);
    void dispatchCompute(VkPipeline computePipe, uint32_t x, uint32_t y, uint32_t z,
                         const std::vector<VkDescriptorSet>& sets = {});
    VkShaderModule createShaderModule(const std::vector<char>& code);

private:
    GLFWwindow* window = nullptr;
    QueueFamilyIndices findQueueFamilies(VkPhysicalDevice dev);
    void createInstance();
    void setupDebugMessenger();
    void createSurface();
    void pickPhysicalDevice();
    void createLogicalDevice();
    void createSwapchain();
    void createImageViews();
    void createRenderPass();
    void createFramebuffers();
    void createCommandPool();
    void createCommandBuffers();
    void createSyncObjects();
};
