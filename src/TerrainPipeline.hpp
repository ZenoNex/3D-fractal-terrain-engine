// TerrainPipeline.hpp
class TerrainPipeline {
    VkPipelineLayout layout;
    VkPipeline       graphics;
    VkDescriptorSetLayout dsl;

    void createGraphicsPipeline(VkDevice dev, VkRenderPass rp);
    void record(VkCommandBuffer cb, const Chunk& c);
};
