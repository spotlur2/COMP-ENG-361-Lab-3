/* Tier 1 C test: Recursive function calls with a real stack frame */
typedef int int32_t;
typedef unsigned int uint32_t;

__attribute__((noinline))
int32_t fib_rec(int32_t n) {
    if (n <= 1) {
        return n;
    }
    return fib_rec(n - 1) + fib_rec(n - 2);
}

__attribute__((noinline))
uint32_t shift_mix(uint32_t a, uint32_t b) {
    uint32_t x = (a << 3) ^ (b >> 2);
    int32_t sx = (int32_t)(x ^ 0x80000000u) >> 4;
    return (uint32_t)sx + a - b;
}

int main(void) {
    volatile int32_t out[4];
    int32_t f5 = fib_rec(5);
    int32_t f6 = fib_rec(6);
    out[0] = f5;
    out[1] = f6;
    out[2] = (int32_t)shift_mix((uint32_t)f5, (uint32_t)f6);
    out[3] = out[0] + out[1] + out[2];
    return out[3];
}
