#include <cstdint>
#include <cuda_runtime.h>
#include <stdio.h>

// Removed the trailing semicolon
#define MINECRAFT_SALT 987234911
#define sum64(x, y)    (static_cast<int64_t>(x)) + (static_cast<int64_t>(y))

#define LINE_SIZE              16
#define chunksToBlocks(chunks) (chunks * 16)

class JavaRandom
{
private:
    uint64_t       seed;
    const uint64_t MULTIPLIER = 0x5DEECE66DULL;
    const uint64_t ADDEND     = 0x0BULL;
    const uint64_t MASK       = (1ULL << 48) - 1;

public:
    __device__ JavaRandom(int64_t initial_seed)
    {
        // Cast to unsigned for bitwise XOR, then mask to 48 bits
        seed = (static_cast<uint64_t>(initial_seed) ^ MULTIPLIER) & MASK;
    }

    __device__ int32_t next(int32_t bits)
    {
        seed = (seed * MULTIPLIER + ADDEND) & MASK;
        // Because 'seed' is uint64_t, '>>' perfectly mimics Java's '>>>'
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
            // Standard Java rejection sampling loop
        } while (bits - val + (bound - 1) < 0);

        return val;
    }
};

__device__ int64_t slime_seed(int64_t world_seed, int32_t x, int32_t z, int64_t salt)
{
    int32_t a1 = 4987142;
    int32_t a2 = 5947611;
    int64_t a3 = 4392871;
    int32_t a4 = 389711;

    int32_t first_operation   = x * x * a1;
    int32_t second_operation  = x * a2;
    int32_t third_operation_1 = z * z;

    int64_t third_operation_2 = (static_cast<int64_t>(third_operation_1)) * a3;
    int32_t fourth_operation  = z * a4;

    int64_t addition_0 = sum64(world_seed, first_operation);
    int64_t addition_1 = sum64(addition_0, second_operation);
    int64_t addition_2 = sum64(addition_1, third_operation_2);
    int64_t addition_3 = sum64(addition_2, fourth_operation);

    return addition_3 ^ salt;
}

__global__ void checkSlimeChunk(const int64_t world_seed,
                                const int32_t x,
                                const int32_t z,
                                const int64_t salt,
                                int32_t      *isSlimeChunk,
                                const int32_t N)
{
    int32_t bIdx             = blockIdx.x;
    int32_t threadIdxOnBlock = threadIdx.x;

    if (bIdx < N) {
        int32_t    x_init = x + bIdx * LINE_SIZE;
        int32_t    x_iter = threadIdxOnBlock % LINE_SIZE;
        int32_t    z_iter = threadIdxOnBlock / LINE_SIZE;
        int64_t    sseed  = slime_seed(world_seed, x_init + x_iter, z + z_iter, salt);
        JavaRandom jr(sseed);
        atomicAdd(&isSlimeChunk[bIdx], (jr.nextInt(10) == 0));
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

    int32_t x = -30000000L / 16;
    int32_t z = -30000000L / 16;
    printf("Starting at %d and %d\n", x, z);


    const int total_number_of_chunks = 30000000 / 16 * 2;
    const int threadsPerBlock        = 256;
    const int cudaBlocksToUse        = (total_number_of_chunks + threadsPerBlock - 1) / (threadsPerBlock);


    int32_t *isSlimeChunkGPU = NULL;
    size_t   N               = cudaBlocksToUse;
    cudaMalloc((void **)&isSlimeChunkGPU, N * sizeof(int32_t));

    int32_t *isSlimeChunkCPU = (int32_t *)malloc(N * sizeof(int32_t));
    int32_t  min;
    int32_t  iter_min;

    min           = INT_MAX;
    iter_min      = 0;
    int32_t z_min = 0;
    for (int major_iter = 0; major_iter < total_number_of_chunks / 16; major_iter++) {
        z += threadsPerBlock / LINE_SIZE;

        cudaMemset(isSlimeChunkGPU, 0, N * sizeof(int32_t));
        checkSlimeChunk<<<cudaBlocksToUse, threadsPerBlock>>>(world_seed, x, z, salt, isSlimeChunkGPU, N);
        cudaMemcpy(isSlimeChunkCPU, isSlimeChunkGPU, N * sizeof(int32_t), cudaMemcpyDeviceToHost);
        for (int iter = 0; iter < N; iter++) {
            if (min > isSlimeChunkCPU[iter]) {
                min      = isSlimeChunkCPU[iter];
                iter_min = iter;
                z_min    = z;
            }
        }
    }
    printf("Stop getting z at %d\n", z);
    printf("%d\t%d\t%d\n", chunksToBlocks(x + iter_min * LINE_SIZE), chunksToBlocks(z_min), min);
    showLink(world_seed, chunksToBlocks(x + iter_min * LINE_SIZE), chunksToBlocks(z_min));

    cudaFree(isSlimeChunkGPU);

    return 0;
}
