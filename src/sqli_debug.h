#ifndef __SQLI_DEBUG_H__
#define __SQLI_DEBUG_H__

#ifdef DEBUG
#define SQLI_DEBUG(format, args...) printf(format, ##args)
#else
#define SQLI_DEBUG(format, args...) do { } while (0)
#endif

#endif /* sqli_debug.h */
