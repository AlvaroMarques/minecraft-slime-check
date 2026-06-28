import java.util.Random;

public class SlimeRangeScanner {

    public static boolean isSlimeChunk(long worldSeed, int x, int z) {
        long salt = 987234911L;

        // This relies entirely on the JVM's native order of operations and implicit 32-bit overflow.
        // The lack of (long) casting on the 'x' variables is intentional and critical.
        long slimeSeed = worldSeed + x * x * 4987142 + x * 5947611 + z * z * 4392871L + z * 389711 ^ salt;
		System.out.println(slimeSeed);

        Random rng = new Random(slimeSeed);
        return rng.nextInt(10) == 0;
    }

    public static void main(String[] args) {
        long worldSeed = 9876543210L;


        // Safely map blocks to chunks (equivalent to div_euclid)
        int chunkXStart = 182;
        int chunkXEnd = 185;
        int chunkZStart = 195;
        int chunkZEnd = 200;

        System.out.println("=== PURE JAVA RANGE SCANNER ===");
        System.out.println("World Seed: " + worldSeed);
        System.out.println("Chunk X Range: [" + chunkXStart + " to " + chunkXEnd + "]");
        System.out.println("Chunk Z Range: [" + chunkZStart + " to " + chunkZEnd + "]\n");

        System.out.printf("| %-7s | %-7s | %-15s |\n", "Chunk X", "Chunk Z", "Status");
        System.out.println("|---------|---------|-----------------|");

        for (int cx = chunkXStart; cx <= chunkXEnd; cx++) {
            for (int cz = chunkZStart; cz <= chunkZEnd; cz++) {
                boolean isSlime = isSlimeChunk(worldSeed, cx, cz);
                String status = isSlime ? "🟩 Slime Chunk" : "⬜ Regular";
                System.out.printf("| %-7d | %-7d | %-15s |\n", cx, cz, status);
            }
        }
    }
}
