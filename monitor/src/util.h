/*
 * Copyright (c) 2001-2003 Gregory M. Kurtzer
 * 
 * Copyright (c) 2003-2011, The Regents of the University of California,
 * through Lawrence Berkeley National Laboratory (subject to receipt of any
 * required approvals from the U.S. Dept. of Energy).  All rights reserved.
 *
 * Contributed by Anthony Salgado & Krishna Muriki
 * Warewulf Monitor (globals.h)
 *
 */

#ifndef _UTIL_H
#define _UTIL_H  1

#include <time.h>
#include <json/json.h>
#include <sqlite3.h>

#include "globals.h"

/****** MACROS ******/
/**
 * Returns the length of a literal string.
 *
 * This macro is like libc's strlen() function, except that it
 * requires the string parameter be a literal rather than a variable.
 * This makes calculating the string length for a literal easy without
 * incurring the speed penalty of a call to strlen().
 *
 * @param x The literal string (i.e., a fixed string in quotes, like
 *          "this.").
 * @return The length of the string.
 */
#define CONST_STRLEN(x)            (sizeof(x) - 1)
/**
 * Compares the beginning of a string with a literal.
 *
 * This macro, like the libc str*cmp() functions, returns an integer
 * less than, equal to, or greater than zero depending on if the
 * initial part of string @a s is found to be less than, to match, or
 * to be greater than the literal string.  Generally, this is used as
 * a boolean value (as !BEG_STRCMP()) to determine whether @a s starts
 * with @a constr or not.
 *
 * @param s      The string variable to compare to.
 * @param constr A literal string representing what should be the
 *               beginning of @a s.
 * @return See above.
 */
#define BEG_STRCMP(s, constr)  (strncmp((char *) (s), (constr), CONST_STRLEN(constr)))

/****** DATA STRUCTURES ******/
typedef struct cpu_data {
    long tj;  // Total Jiffs
    long wj;  //  Work Jiffs
} cpu_data;

/****** FUNCTION PROTOTYPES ******/
void insertLookups(int, json_object *, sqlite3 *);
void updateLookups(int, json_object *, sqlite3 *);
void fillLookups(int, json_object *, sqlite3 *);
void update_insertLookups(int, json_object *, sqlite3 *, int);
void insert_json(char *, time_t, json_object *, sqlite3 *);
void update_json(char *, time_t, json_object *, sqlite3 *, int);
void merge_json(char *, time_t, json_object *, sqlite3 *, int);
void insert_update_json(int, char *, time_t, json_object *, sqlite3 *);
int NodeBID_fromDB(char *, sqlite3 *);
int NodeTS_fromDB(char *, sqlite3 *);
char *recvall(int);
int sendall(int, char *, int);
int send_json(int, json_object *);
void array_list_print(array_list *);
void json_parse_complete(json_object *);
void json_parse(json_object *);
char *chomp(char *);
json_object *fast_data_parser(char *, array_list *, int);

long get_jiffs(cpu_data *);
/* float get_cpu_util_old(void); */

int key_exists_in_json(json_object *, char *);
int get_int_from_json(json_object *, char *);
void get_string_from_json(json_object *, char *, char *);

/* Connection Functions */
int registerConntype(int, int);
int setup_ConnectSocket(char *, int);

/* SQLite Functions */
int createTable(sqlite3 *, char *);

#endif /* _UTIL_H */


/*
 * vim:filetype=c:syntax=c:expandtab:ts=2:sw=2
 */
