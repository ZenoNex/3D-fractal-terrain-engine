// VulkanContext.cpp
#define VULKAN_HPP_DISPATCH_LOADER_DYNAMIC 1
#include "VulkanContext.hpp"
#include <fstream>
#include <set>
#include <iostream>

static std::vector<char> readFile(const std::string& filename) {
    std::ifstream file(filename, std::ios::ate | std::ios::binary);
    if (!file.is_open()) throw std::runtime_error("failed to open file: " + filename);
    size_t fileSize = (size_t)file.tellg();
    std::vector<char> buffer(fileSize);
    file.seekg(0);
    file.read(buffer.data(), fileSize);
    return buffer;
}

// ------------------------------------------------------------------
// Validation layers & extensions
const std::vector<const char*> validationLayers = {
    "VK_LAYER_KHRONOS_validation"
};
const std::vector<const char*> deviceExtensions = {
    VK_KHR_SWAPCHAIN_EXTENSION_NAME
};

#ifdef NDEBUG
const bool enableValidationLayers = false;
#else
const bool enableValidationLayers = true;
#endif

// ------------------------------------------------------------------
VulkanContext::VulkanContext() { /* everything created in initWindow */ }
VulkanContext::~VulkanContext() {
    for (size_t i = 0; i < imageAvailableSemaphores.size(); ++i) {
        vkDestroySemaphore(device, renderFinishedSemaphores[i], nullptr);
        vkDestroySemaphore(device, imageAvailableSemaphores[i], nullptr);
        vkDestroyFence(device, inFlightFences[i], nullptr);
    }
    vkDestroyCommandPool(device, commandPool, nullptr);
    for (auto fb : swapchainFramebuffers) vkDestroyFramebuffer(device, fb, nullptr);
    for (auto iv : swapchainImageViews) vkDestroyImageView(device, iv, nullptr);
    vkDestroyRenderPass(device, renderPass, nullptr);
    vkDestroySwapchainKHR(device, swapchain, nullptr);
    vkDestroyDevice(device, nullptr);
    if (enableValidationLayers) {
        auto func = (PFN_vkDestroyDebugUtilsMessengerEXT)vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT");
        if (func) func(instance, debugMessenger, nullptr);
    }
    vkDestroySurfaceKHR(instance, surface, nullptr);
    vkDestroyInstance(instance, nullptr);
    glfwDestroyWindow(window);
    glfwTerminate();
}

// ------------------------------------------------------------------
void VulkanContext::initWindow(uint32_t w, uint32_t h, const char* title) {
    glfwInit();
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    window = glfwCreateWindow(w, h, title, nullptr, nullptr);
    createInstance();
    setupDebugMessenger();
    createSurface();
    pickPhysicalDevice();
    createLogicalDevice();
    createSwapchain();
    createImageViews();
    createRenderPass();
    createFramebuffers();
    createCommandPool();
    createCommandBuffers();
    createSyncObjects();
}

// ------------------------------------------------------------------
// (All the boiler-plate functions – createInstance, pickPhysicalDevice, etc.
//  are standard Vulkan tutorial code.  Only the **dispatchCompute** helper
//  is shown below because it is used by the terrain engine.)

void VulkanContext::dispatchCompute(VkPipeline computePipe,
                                    uint32_t x, uint32_t y, uint32_t z,
                                    const std::vector<VkDescriptorSet>& sets) {
    VkCommandBuffer cb = beginSingleTimeCommands();

    vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, computePipe);
    if (!sets.empty())
        vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE,
                                pipelineLayoutForCompute, // you must set this per-pipeline
                                0, (uint32_t)sets.size(), sets.data(), 0, nullptr);
    vkCmdDispatch(cb, x, y, z);

    endSingleTimeCommands(cb);
}

// ------------------------------------------------------------------
VkCommandBuffer VulkanContext::beginSingleTimeCommands() {
    VkCommandBufferAllocateInfo allocInfo{};
    allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocInfo.commandPool = commandPool;
    allocInfo.commandBufferCount = 1;

    VkCommandBuffer cb;
    vkAllocateCommandBuffers(device, &allocInfo, &cb);

    VkCommandBufferBeginInfo beginInfo{};
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    vkBeginCommandBuffer(cb, &beginInfo);
    return cb;
}

void VulkanContext::endSingleTimeCommands(VkCommandBuffer cb) {
    vkEndCommandBuffer(cb);

    VkSubmitInfo submitInfo{};
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &cb;

    vkQueueSubmit(computeQueue, 1, &submitInfo, VK_NULL_HANDLE);
    vkQueueWaitIdle(computeQueue);

    vkFreeCommandBuffers(device, commandPool, 1, &cb);
}

// ------------------------------------------------------------------
VkShaderModule VulkanContext::createShaderModule(const std::vector<char>& code) {
    VkShaderModuleCreateInfo createInfo{};
    createInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    createInfo.codeSize = code.size();
    createInfo.pCode = reinterpret_cast<const uint32_t*>(code.data());

    VkShaderModule module;
    if (vkCreateShaderModule(device, &createInfo, nullptr, &module) != VK_SUCCESS)
        throw std::runtime_error("failed to create shader module");
    return module;
}
