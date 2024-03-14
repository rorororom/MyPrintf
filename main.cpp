#include <stdio.h>
#include <stdint.h>

extern "C" int MyPrintf (char* s, ...);

int main() {
    int len = MyPrintf("hahahaha %d %s %x %d %o %% %b %c %o\n %d %s %x %d%%%c%b\n",

                        1, "lolol", 123, 456, 56, 1111, 33, 0, -1, "love", 3802, 100, 33, 30);
    printf("len = %d\n", len);

    return 0;
}

