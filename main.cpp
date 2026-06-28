#include <iostream>
#include <cstdint>
#define MINECRAFT_SALT 987234911;
#define sum64(x, y) (static_cast<int64_t>(x)) + (static_cast<int64_t>(y))


class JavaRandom {
private:
    uint64_t seed;
    const uint64_t MULTIPLIER = 0x5DEECE66DULL;
    const uint64_t ADDEND = 0x0BULL;
    const uint64_t MASK = (1ULL << 48) - 1;

public:
    JavaRandom(int64_t initial_seed) {
        // Cast to unsigned for bitwise XOR, then mask to 48 bits
        seed = (static_cast<uint64_t>(initial_seed) ^ MULTIPLIER) & MASK;
    }

    int32_t next(int32_t bits) {
        seed = (seed * MULTIPLIER + ADDEND) & MASK;
        // Because 'seed' is uint64_t, '>>' perfectly mimics Java's '>>>'
        return static_cast<int32_t>(seed >> (48 - bits));
    }

    int32_t nextInt(int32_t bound) {
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

int64_t slime_seed(int64_t world_seed, int32_t x, int32_t z, int64_t salt) {
	int32_t a1, a2, a4;
	int64_t a3;

    a1 = 4987142;
	a2 = 5947611;
	a3 = 4392871;
	a4 = 389711;

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

int main() {
	int64_t world_seed = 9876543210;
	int64_t salt = MINECRAFT_SALT;

	int32_t x, z;
	x = 185;
	z = 196;

	std::cout << "x: " << x << " z: " << z << " slime seed: " << slime_seed(world_seed, x, z, salt) << std::endl;

	int64_t sseed = slime_seed(world_seed, x, z, salt);

	JavaRandom jr(sseed);

	std::cout << "Is slime chunk? " << (jr.nextInt(10) == 0) << std::endl;


	return 0;
}
