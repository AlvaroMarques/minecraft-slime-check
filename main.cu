#include <climits>
#include <cstdint>
#include <cuda_runtime.h>
#include <iostream>

#define MINECRAFT_SALT           987234911LL
#define LINE_SIZE                16
#define CHUNKS_TO_BLOCKS(chunks) ((chunks) * 16)

class JavaRandom
{
private:
    uint64_t       seed;
    const uint64_t MULTIPLIER = 0x5DEECE66DULL;
    const uint64_t ADDEND     = 0x0BULL;
    const uint64_t MASK       = (1ULL << 48) - 1;

public:
    __device__ JavaRandom(int64_t initial_seed) { seed = (static_cast<uint64_t>(initial_seed) ^ MULTIPLIER) & MASK; }

    __device__ int32_t next(int32_t bits)
    {
        seed = (seed * MULTIPLIER + ADDEND) & MASK;
        return static_cast<int32_t>(seed >> (48 - bits));
    }

    __device__ int32_t nextInt(int32_t bound)
    {
        if (bound <= 0)
            return 0;
        int32_t bits, val;
        do {
            bits = next(31);
            val  = bits % bound;
        } while (bits - val + (bound - 1) < 0);
        return val;
    }
};

// FIXED: Re-implemented strict uint32_t casting to prevent C++ Undefined Behavior
__device__ int64_t slime_seed(int64_t world_seed, int32_t x, int32_t z, int64_t salt)
{
    uint32_t ux = static_cast<uint32_t>(x);
    uint32_t uz = static_cast<uint32_t>(z);

    uint32_t p1_u = ux * ux * 4987142;
    uint32_t p2_u = ux * 5947611;
    uint32_t p3_u = uz * uz;
    uint32_t p4_u = uz * 389711;

    int64_t part1 = static_cast<int64_t>(static_cast<int32_t>(p1_u));
    int64_t part2 = static_cast<int64_t>(static_cast<int32_t>(p2_u));
    int64_t part3 = static_cast<int64_t>(static_cast<int32_t>(p3_u)) * 4392871LL;
    int64_t part4 = static_cast<int64_t>(static_cast<int32_t>(p4_u));

    return world_seed + part1 + part2 + part3 + part4 ^ salt;
}

__global__ void checkSlimeChunk(const int64_t world_seed,
                                const int32_t start_x,
                                const int32_t current_z,
                                const int64_t salt,
                                int32_t      *isSlimeChunk,
                                const int32_t N)
{

    // FIXED: Use Shared Memory for fast, collision-free addition inside the Block
    __shared__ int32_t blockSlimeCount;

    // Thread 0 initializes the shared counter
    if (threadIdx.x == 0) {
        blockSlimeCount = 0;
    }
    __syncthreads(); // Wait for initialization

    int32_t bIdx = blockIdx.x;
    if (bIdx < N) {
        int32_t x_init = start_x + (bIdx * LINE_SIZE);
        int32_t x_iter = threadIdx.x % LINE_SIZE;
        int32_t z_iter = threadIdx.x / LINE_SIZE;

        int64_t    sseed = slime_seed(world_seed, x_init + x_iter, current_z + z_iter, salt);
        JavaRandom jr(sseed);

        if (jr.nextInt(10) == 0) {
            // Atomic add to ultra-fast shared memory, NOT global memory
            atomicAdd(&blockSlimeCount, 1);
        }
    }
    __syncthreads(); // Wait for all 256 threads to finish counting

    // Thread 0 writes the final sum to global memory once
    if (threadIdx.x == 0 && bIdx < N) {
        isSlimeChunk[bIdx] = blockSlimeCount;
    }
}

void showLink(int64_t seed, int32_t x, int32_t z)
{
    printf("https://www.chunkbase.com/apps/"
           "seed-map#seed=%ld&platform=java_1_18&dimension=overworld&x=%d&z=%d&zoom=1.617\n",
           seed,
           x,
           z);
}

int main(void)
{
    int64_t world_seed = 9876543210LL;
    int64_t salt       = MINECRAFT_SALT;

    // Minecraft world boundaries in blocks: -30M to +30M
    // Boundary in Chunks: -1,875,000 to +1,875,000
    int32_t start_x = -30000000 / 16;
    int32_t start_z = -30000000 / 16;
    int32_t end_z   = 30000000 / 16;

    // Total chunks across the X axis = 3,750,000
    // Number of 16x16 grids along the X axis
    const int32_t total_x_grids = (30000000 / 16 * 2) / LINE_SIZE;

    const int threadsPerBlock = 256;           // 16x16 threads
    const int cudaBlocksToUse = total_x_grids; // One block per 16x16 grid

    size_t N = cudaBlocksToUse; // Number of grids being processed per Z-row

    printf("Initializing GPU memory for %zu grids per row...\n", N);

    int32_t *isSlimeChunkGPU = NULL;
    cudaMalloc((void **)&isSlimeChunkGPU, N * sizeof(int32_t));
    int32_t *isSlimeChunkCPU = (int32_t *)malloc(N * sizeof(int32_t));

    int32_t global_min = INT_MAX;
    int32_t best_x     = 0;
    int32_t best_z     = 0;

    int32_t current_z = start_z;

    // Loop down the Z axis, stepping by 16 chunks at a time
    while (current_z <= end_z - LINE_SIZE) {

        checkSlimeChunk<<<cudaBlocksToUse, threadsPerBlock>>>(world_seed, start_x, current_z, salt, isSlimeChunkGPU, N);

        cudaMemcpy(isSlimeChunkCPU, isSlimeChunkGPU, N * sizeof(int32_t), cudaMemcpyDeviceToHost);

        // Scan the CPU array for the "deadest" chunk
        for (int i = 0; i < N; i++) {
            if (isSlimeChunkCPU[i] < global_min) {
                global_min = isSlimeChunkCPU[i];
                best_x     = start_x + (i * LINE_SIZE);
                best_z     = current_z;

                // If we found a grid with 0 slime chunks, we can't get any lower!
                if (global_min == 0) {
                    printf("\nFound a perfectly dead 16x16 grid early!\n");
                    goto search_finished;
                }
            }
        }

        current_z += LINE_SIZE;

        // Progress printout every ~1000 rows
        if ((current_z - start_z) % (16 * 1000) == 0) {
            printf("Scanned down to Z: %d\n", current_z);
        }
    }

search_finished:
    printf("\n=== SEARCH COMPLETE ===\n");
    printf("Minimum Slime Chunks found in a 16x16 area: %d\n", global_min);
    printf("Chunk Coordinates: X: %d, Z: %d\n", best_x, best_z);
    printf("Block Coordinates: X: %d, Z: %d\n", CHUNKS_TO_BLOCKS(best_x), CHUNKS_TO_BLOCKS(best_z));

    showLink(world_seed, CHUNKS_TO_BLOCKS(best_x), CHUNKS_TO_BLOCKS(best_z));

    cudaFree(isSlimeChunkGPU);
    free(isSlimeChunkCPU);

    return 0;
}
