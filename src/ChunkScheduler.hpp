// ChunkScheduler.hpp
struct Chunk {
    glm::vec3 origin;   // world corner
    float     size;     // edge length (power-of-two)
    uint32_t  lod;      // 0 = finest
    VkBuffer  fieldBuf; // SSBO filled by FieldEvaluator
    VkBuffer  meshBuf;  // vertex/index after DualContour
    bool      dirty = true;
};

class ChunkScheduler {
public:
    void update(const Camera& cam, float dt);
    std::vector<Chunk*> getPendingJobs(); // for dispatch
private:
    std::unordered_map<uint64_t, Chunk> chunks;
    float targetError = 0.8f; // screen-space error threshold
    // Morton-key encoding for fast lookup
    uint64_t morton(const glm::ivec3& p) const;
    float computePriority(const Chunk& c, const Camera& cam) const;
};
