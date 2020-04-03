#include <stdio.h>
#include <string.h>
#include "sqli_detect.h"

int main(int argc, char* argv[]) {
    char *str = "1' or '1'='1";
    int ret = sqli_detect(str, strlen(str));
    if (ret > 0) {
        printf("sqli found\n");
    }
    return ret;
}
