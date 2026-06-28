fn slime_seed(world_seed: i64, x: i32, z: i32, salt: i64) -> i64 {
    // FIXED: Added the missing 9 to a1
    let (a1, a2, a3, a4) = (4987142i32, 5947611i32, 4392871i64, 389711i32);

    // Phase 1: 32-bit wrapping multiplications
    let first_operation: i32 = x.wrapping_mul(x).wrapping_mul(a1);
    let second_operation: i32 = x.wrapping_mul(a2);
    let third_operation_1: i32 = z.wrapping_mul(z);

    // Phase 2: 64-bit promotion and multiplication
    let third_operation_2: i64 = (third_operation_1 as i64).wrapping_mul(a3);
    let fourth_operation: i32 = z.wrapping_mul(a4);

    // Phase 3: 64-bit wrapping additions
    let addition_0: i64 = world_seed.wrapping_add(first_operation as i64);
    let addition_1: i64 = addition_0.wrapping_add(second_operation as i64);
    let addition_2: i64 = addition_1.wrapping_add(third_operation_2);
    let addition_3: i64 = addition_2.wrapping_add(fourth_operation as i64);

    return addition_3 ^ salt;
}
fn main() {
    println!("Hello world");

    let world_seed = 9876543210i64;
    let salt = 987234911i64;

    let (x, z) = (182i32, 182i32);

    println!(
        "x: {}, z: {}, slime seed: {}",
        x,
        z,
        slime_seed(world_seed, x, z, salt)
    );
}
