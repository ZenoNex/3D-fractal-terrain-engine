int main() {
    VulkanContext ctx;
    ChunkScheduler scheduler;
    TerrainPipeline pipeline(ctx);

    Camera cam;
    while (!ctx.shouldClose()) {
        float dt = ctx.updateTimer();
        cam.update(dt);

        scheduler.update(cam, dt);
        auto jobs = scheduler.getPendingJobs();

        for (auto* chunk : jobs) {
            // 1. Evaluate field
            ctx.dispatchCompute(FieldEvaluator, chunk);
            vkQueueWaitIdle(ctx.computeQueue);

            // 2. Dual contour
            ctx.dispatchCompute(DualContour, chunk);
            vkQueueWaitIdle(ctx.computeQueue);

            // 3. (optional) DAG compress
            if (useDAG) ctx.dispatchCompute(DAGCompressor, chunk);

            // 4. Upload to GPU memory (mapped persistent SSBOs)
            chunk->upload();
        }

        VkCommandBuffer cb = ctx.beginFrame();
        pipeline.record(cb, visibleChunks);
        ctx.endFrame(cb);
    }
}
