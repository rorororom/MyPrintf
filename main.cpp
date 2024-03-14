#include <stdio.h>
#include <stdint.h>

extern "C" int MyPrintf (char* s, ...);

int main() {
    int len = MyPrintf("hahahaha %d %s %x %d %o %% %b %c\n", 1, "lolol", 123, 456, 56, 1111, 33);
    printf("len = %d\n", len);
    return 0;
}

