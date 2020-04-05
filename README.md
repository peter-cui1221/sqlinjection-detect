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

# vs libinjection
sqlinjection-detect is a kind of sql injection library based on tokenizing and syntax analysis, which can effectively improve the detection rate and reduce false positives. In contrast, libinjection is base on tokenizing.

sqlinjection-detect是一款基于语义分析的SQL注册检测库，能够有效的提高检出率，减少误报。相比之下，libinjection是一款基于词法分析SQL注入检测库。

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
