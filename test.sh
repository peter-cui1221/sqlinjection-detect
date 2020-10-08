#!/bin/sh

find tests/ -name "*.txt" | xargs -L 1 ./sqli_test
