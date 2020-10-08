#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "sqli_detect.h"

int
main(int argc, char *argv[])
{
	char data[4096];
	FILE *fp;
	int ret;

	if (argc != 2) {
		printf("usage %s filename", argv[0]);
		exit(-1);
	}
	fp = fopen(argv[1], "r");
	if (fp == NULL) {
		printf("open file %s failed\n", argv[1]);
		exit(-2);
	}
	while (!feof(fp)) {
		fscanf(fp, "%s", &data);
		ret = sqli_detect(data, strlen(data));
		if (ret > 0) {
			printf("PASS: %s sqli found\n", data);
		} else {
			printf("ERROR: %s sqli not found\n", data);
		}
	}
	fclose(fp);
	return 0;
}
