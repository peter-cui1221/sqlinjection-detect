# sqlinjection-detect
SQL injection detection engine built on of SQL tokenizing and syntax analysis written in C 

Simple example:
```c
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
```

# usage
```
$ ./build.sh
$ cmake .
$ make

$ gcc -I src/include/ sqli_test.c -o sqli_test -L. -lsqli_detect
$ ./sqli_test 
$ sqli found
```

# thanks
this project is base on https://github.com/winkyao/lemon
