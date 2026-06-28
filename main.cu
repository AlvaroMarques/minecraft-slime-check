#include <stdio.h>
#include <cuda_runtime.h>
#include <cstdint>

// Removed the trailing semicolon
#define MINECRAFT_SALT 987234911
#define sum64(x, y) (static_cast<int64_t>(x)) + (static_cast<int64_t>(y))

class JavaRandom {
private:
    uint64_t seed;
    const uint64_t MULTIPLIER = 0x5DEECE66DULL;
    const uint64_t ADDEND = 0x0BULL;
    const uint64_t MASK = (1ULL << 48) - 1;

public:
    __device__ JavaRandom(int64_t initial_seed) {
        // Cast to unsigned for bitwise XOR, then mask to 48 bits
        seed = (static_cast<uint64_t>(initial_seed) ^ MULTIPLIER) & MASK;
    }

    __device__ int32_t next(int32_t bits) {
        seed = (seed * MULTIPLIER + ADDEND) & MASK;
        // Because 'seed' is uint64_t, '>>' perfectly mimics Java's '>>>'
        return static_cast<int32_t>(seed >> (48 - bits));
    }

    __device__ int32_t nextInt(int32_t bound) {
        if (bound <= 0) return 0;

        int32_t bits, val;
        do {
            bits = next(31);
            val = bits % bound;
            // Standard Java rejection sampling loop
        } while (bits - val + (bound - 1) < 0);

        return val;
    }
};

__device__ int64_t slime_seed(int64_t world_seed, int32_t x, int32_t z, int64_t salt) {
    int32_t a1 = 4987142;
    int32_t a2 = 5947611;
    int64_t a3 = 4392871;
    int32_t a4 = 389711;

    int32_t first_operation = x * x * a1;
    int32_t second_operation = x * a2;
    int32_t third_operation_1 = z * z;

    int64_t third_operation_2 = (static_cast<int64_t>(third_operation_1)) * a3;
    int32_t fourth_operation = z * a4;

    int64_t addition_0 = sum64(world_seed, first_operation);
    int64_t addition_1 = sum64(addition_0, second_operation);
    int64_t addition_2 = sum64(addition_1, third_operation_2);
    int64_t addition_3 = sum64(addition_2, fourth_operation);

    return addition_3 ^ salt;
}

__global__ void checkSlimeChunk(const int64_t world_seed, const int32_t x, const int32_t z, const int64_t salt, bool *isSlimeChunk) {
    // i is unused right now, but kept here assuming you plan to scale this to process grids of chunks later
    // int i = blockDim.x * blockIdx.x + threadIdx.x;

    int64_t sseed = slime_seed(world_seed, x, z, salt);
    JavaRandom jr(sseed);
    *isSlimeChunk = jr.nextInt(10) == 0;
}

int main(void) {
    bool isSlimeChunk = false;

    int64_t world_seed = 9876543210LL;
    int64_t salt = MINECRAFT_SALT;

    int32_t x = 185;
    int32_t z = 196;

    bool *isSlimeChunkGPU = NULL;

    // FIXED: Target the GPU pointer's address, not the host bool's address
    cudaMalloc((void**) &isSlimeChunkGPU, sizeof(bool));

    checkSlimeChunk<<<1, 1>>>(world_seed, x, z, salt, isSlimeChunkGPU);

    // FIXED: Destination is host pointer, Source is device pointer
    cudaMemcpy(&isSlimeChunk, isSlimeChunkGPU, sizeof(bool), cudaMemcpyDeviceToHost);

    printf("x: %d, z: %d, is slime? %d\n", x, z, isSlimeChunk);

    cudaFree(isSlimeChunkGPU);

    return 0;
}
