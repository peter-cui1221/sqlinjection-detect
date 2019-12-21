cd lemon
gcc -o lemon lemon.c
./lemon parse.y

mv parse.h parse.h.temp
awk -f addopcodes.awk parse.h.temp > parse.h

mv parse.h ../src/parse.h
mv parse.c ../src/parse.c
cd ..
