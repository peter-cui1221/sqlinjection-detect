#include "sqliteInt.h"
#include "sqli_detect.h"
#include "sqli_debug.h"

static int do_check_sqli(char *prefix, char *postfix, char *input, int len) 
{
    Parse parseObj;
    char *errMsg = 0;
    memset(&parseObj, 0, sizeof (parseObj));
    int total_len = 64 + len;
    char *buf;
    
    buf = malloc(total_len);
    if (!buf) {
        return -1;
    }
    snprintf(buf, total_len, "%s%s%s", prefix, input, postfix);
    SQLI_DEBUG("buf = %s\n", buf);
    sqlite3RunParser(&parseObj, buf, &errMsg);
    if (sqlite3MallocFailed()) {
	    parseObj.rc = SQLITE_NOMEM;
    }
    if (parseObj.rc == SQLITE_DONE) {
	    parseObj.rc = SQLITE_OK;
    }
    if (errMsg != NULL) {
	    SQLI_DEBUG("error: %s, error_code:%d \n", errMsg, parseObj.rc);
        sqliteFree(errMsg);
        free(buf);
        return 0;
    }
    SQLI_DEBUG("sqli detect, sflag 0x%x, select %d\n", parseObj.sflag, parseObj.select_num);
    free(buf);
    if (parseObj.select_num > 0 && parseObj.sflag != SQL_FLAG_EXPR) {
        return 1;
    }
    return 0;

}

static int
check_sqli_number(char *input, int len)
{
    return do_check_sqli("select * from abc where xx=", "", input, len);
}

static int
check_sqli_quota(char *input, int len)
{    
    return do_check_sqli("select * from abc where xx=\"", "\"", input, len);
}

static int
check_sqli_signle_quota(char *input, int len)
{    
    return do_check_sqli("select * from abc where xx='", "'", input, len);
}

typedef int (*check_func_t)(char *input, int len);

static check_func_t sqli_check_array[] = {
    check_sqli_number,
    check_sqli_quota,
    check_sqli_signle_quota,
};

/*
 * check input is sqli
 * return
 *  if errors, return < 0
 *  if not found sqli, return == 0
 *  if found sqli return > 0
 */
int
sqli_detect(char *input, int len)
{
    int ret, i;
    check_func_t func;
    
    for (i = 0; i < sizeof(sqli_check_array)/sizeof(check_func_t); i++) {
        func = sqli_check_array[i];
        ret = func(input, len);
        if (ret != 0) {
            return ret;
        }
    }
    return 0;
}
