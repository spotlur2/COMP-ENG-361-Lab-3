/* Tier 1 C test: Nested loops (bubble sort & prefix XOR/sum on stack array) */
typedef int int32_t;
typedef unsigned int uint32_t;

__attribute__((noinline))
void sort_array(int32_t *arr, int32_t n) {
    for (int32_t i = 0; i < n - 1; i++) {
        for (int32_t j = 0; j < n - 1 - i; j++) {
            if (arr[j] > arr[j + 1]) {
                int32_t tmp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = tmp;
            }
        }
    }
}

int main(void) {
    int32_t data[6];
    data[0] = 42;
    data[1] = -17;
    data[2] = 105;
    data[3] = -3;
    data[4] = 0;
    data[5] = 19;

    sort_array(data, 6);

    int32_t acc = 0;
    for (int32_t i = 0; i < 6; i++) {
        acc = (acc << 1) ^ (data[i] + i);
    }
    return acc;
}
