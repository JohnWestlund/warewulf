/*
 * Copyright (c) 2001-2003 Gregory M. Kurtzer
 * 
 * Copyright (c) 2003-2011, The Regents of the University of California,
 * through Lawrence Berkeley National Laboratory (subject to receipt of any
 * required approvals from the U.S. Dept. of Energy).  All rights reserved.
 *
 * Contributed by Anthony Salgado & Krishna Muriki
 * Warewulf Monitor (util.c)
 *
 */

#include "config.h"

#include <assert.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <time.h>
#include <ctype.h>
#include <json/json.h>
#include <sqlite3.h>
#include <sys/utsname.h>

#include "globals.h"
#include "util.h"

/* Any forward declarations */
static int
nothing_todo(void *NotUsed UNUSED, int argc, char **argv, char **azColName)
{
    int i;

    for (i = 0; i < argc; i++) {
        printf("%s = %s\n", azColName[i], argv[i] ? argv[i] : "NULL");
    }
    //printf("\n");
    return 0;
}

static int
getjson_callback(void *void_json, int argc, char **argv, char **azColName UNUSED)
{
    json_object *json_db = (json_object *) void_json;

    json_object_object_add(json_db, "NODE-JSON", json_object_new_string(argv[argc - 1]));
    return 0;
}

static int
getint_callback(void *void_int, int argc, char **argv, char **azColName UNUSED)
{
    int *int_value = (int *) void_int;

    *int_value = atoi(argv[argc - 1]);
    return 0;
}

void
update_insertLookups(int blobid, json_object *jobj, sqlite3 *db, int overwrite)
{
    //TODO : Can we assume 64 bits for rowid ?
    char blobID[65];
    char *sqlite_cmd = malloc(MAX_SQL_SIZE + 1);
    enum json_type type;
    int slen, rc;
    int rowid = -1;
    char *emsg = 0;

    sprintf(blobID, "%d", blobid);
    json_object_object_foreach(jobj, key, value)
    {
        char vals[65]; //TODO: check the length

        type = json_object_get_type(value);
        switch (type) {
          case json_type_int:
              sprintf(vals, "%d", json_object_get_int(value));
              break;
          case json_type_string:
              sprintf(vals, "'%s'", json_object_get_string(value));
              break;
          default:
              /* If we reach this line, the following assert() will fail. */
              assert(type == json_type_int || type == json_type_string);
              break;
        }

        //First check if the key exisits in the table
        slen = snprintf(sqlite_cmd, MAX_SQL_SIZE + 1, "select rowid from %s where key='%s'", SQLITE_DB_TB2NAME, key);
        //printf("UIL SQL CMD - %s\n",sqlite_cmd);
        rc = sqlite3_exec(db, sqlite_cmd, getint_callback, &rowid, &emsg);
        if (rc != SQLITE_OK) {
            fprintf(stderr, "UIL : SQL error: %s\n", emsg);
            sqlite3_free(emsg);
        }

        if (rowid > 0 && overwrite == 1) {
            // Existing entry in the table and permission to overwrite
            slen = snprintf(sqlite_cmd, MAX_SQL_SIZE + 1,
                            "update %s set value=%s where key='%s' and blobid='%s'", SQLITE_DB_TB2NAME, vals, key, blobID);
        } else if (rowid < 0) {
            // This is a new key, value to be inserted
            slen = snprintf(sqlite_cmd, MAX_SQL_SIZE + 1,
                            "insert into %s(blobid, key, value) values('%s','%s',%s)", SQLITE_DB_TB2NAME, blobID, key, vals);
            // TODO : Make a note of this key value pairs so that we can merge into JSON
            // Call a routine to get the jsonblob for this blobid from TB1 and json add this key, value pair
        }
        //printf("UIL SQL CMD - %s\n",sqlite_cmd);
        rc = sqlite3_exec(db, sqlite_cmd, nothing_todo, 0, &emsg);
        if (rc != SQLITE_OK) {
            fprintf(stderr, "UIL : SQL error: %s\n", emsg);
            sqlite3_free(emsg);
        }

    }  // end json_foreach
    free(sqlite_cmd);
}

void
insertLookups(int blobid, json_object *jobj, sqlite3 *db)
{
    //TODO : Can we assume 64 bits for rowid ?
    char blobID[65];
    char *sqlite_cmd = malloc(MAX_SQL_SIZE + 1);
    enum json_type type;
    int slen, rc;
    char *emsg = 0;

    sprintf(blobID, "%d", blobid);
    json_object_object_foreach(jobj, key, value)
    {
        char vals[65]; //TODO: Check the length

        type = json_object_get_type(value);
        switch (type) {
          case json_type_int:
              sprintf(vals, "%d", json_object_get_int(value));
              break;
          case json_type_string:
              sprintf(vals, "'%s'", json_object_get_string(value));
              break;
          default:
              /* If we reach this line, the following assert() will fail. */
              assert(type == json_type_int || type == json_type_string);
              break;
        }
        slen = snprintf(sqlite_cmd, MAX_SQL_SIZE + 1,
                        "insert into %s(blobid, key, value) values('%s','%s',%s)", SQLITE_DB_TB2NAME, blobID, key, vals);
        //printf("IL SQL CMD - %s\n",sqlite_cmd);
        rc = sqlite3_exec(db, sqlite_cmd, nothing_todo, 0, &emsg);
        if (rc != SQLITE_OK) {
            fprintf(stderr, "SQL error: %s\n", emsg);
            sqlite3_free(emsg);
        }

    }  // end json_foreach
    free(sqlite_cmd);
}

void
insert_json(char *nodename, time_t timestamp, json_object *jobj, sqlite3 *db)
{

    char *sqlcmd = malloc(MAX_SQL_SIZE + 1);
    int slen, rc;
    char *emsg = 0;

    slen = snprintf(sqlcmd, MAX_SQL_SIZE + 1,
                    "insert into %s(jsonblob, timestamp, nodename) values('%s',%ld,'%s')",
                    SQLITE_DB_TB1NAME, json_object_to_json_string(jobj), (long) timestamp, nodename);
    //printf("IJ CMD - %s\n",sqlcmd);
    if ((rc = sqlite3_exec(db, sqlcmd, nothing_todo, 0, &emsg) != SQLITE_OK)) {
        fprintf(stderr, "SQL error: %s\n", emsg);
        sqlite3_free(emsg);
    }
    free(sqlcmd);

    return;
}

void
update_json(char *nodename, time_t timestamp, json_object *jobj, sqlite3 *db, int overwrite)
{
    char *sqlcmd = malloc(MAX_SQL_SIZE + 1);
    int slen, rc;
    char *emsg = 0;

    if (overwrite == 1) {
        slen =
            snprintf(sqlcmd, MAX_SQL_SIZE + 1, "update %s set jsonblob='%s', timestamp=%ld where nodename='%s'", SQLITE_DB_TB1NAME,
                     json_object_to_json_string(jobj), (long) timestamp, nodename);
    } else if (overwrite == 0) {
        slen =
            snprintf(sqlcmd, MAX_SQL_SIZE + 1, "update %s set jsonblob='%s' where nodename='%s'", SQLITE_DB_TB1NAME,
                     json_object_to_json_string(jobj), nodename);
    }
    //printf("UJ - %s\n",sqlcmd);
    if ((rc = sqlite3_exec(db, sqlcmd, nothing_todo, 0, &emsg) != SQLITE_OK)) {
        fprintf(stderr, "UJ : SQL error: %s\n", emsg);
        sqlite3_free(emsg);
    }
    free(sqlcmd);
    return;
}

void
merge_json(char *nodename, time_t timestamp, json_object *jobj, sqlite3 *db, int overwrite)
{
    int slen, rc;
    char *emsg = 0;
    json_object *nodejobj;
    json_object *json_db = json_object_new_object();
    char *sqlcmd = malloc(MAX_SQL_SIZE + 1);
    json_object *newjobj, *oldjobj;
    int found = 0;
    enum json_type oldkey_type;

    slen = snprintf(sqlcmd, MAX_SQL_SIZE + 1, "select jsonblob from %s where nodename='%s'", SQLITE_DB_TB1NAME, nodename);
    //printf("JB CMD - %s\n",sqlcmd);
    if ((rc = sqlite3_exec(db, sqlcmd, getjson_callback, json_db, &emsg) != SQLITE_OK)) {
        fprintf(stderr, "MJ : SQL error : %s\n", emsg);
        sqlite3_free(emsg);
    }
    free(sqlcmd);

    json_object_object_foreach(json_db, key, value)
    {
        if (strcmp(key, "NODE-JSON") == 0) {
            nodejobj = json_tokener_parse(json_object_get_string(value));
        }
    }
    //printf("Obtained string - %s\n", json_object_to_json_string(nodejobj));

    if (overwrite == 1) {
        newjobj = jobj;
        oldjobj = nodejobj;
    } else {
        newjobj = nodejobj;
        oldjobj = jobj;
    }

    json_object_object_foreach(oldjobj, oldkey, oldval)
    {
        found = 0;
        json_object_object_foreach(newjobj, newkey, newval)
        {
            if (strcmp(oldkey, newkey) == 0) {
                found = 1;
            }
        }

        if (found == 0) {
            //printf("Exisiting old key %s is missing from new Json Object, lets add it now \n", oldkey);
            oldkey_type = json_object_get_type(oldval);
            switch (oldkey_type) {
              case json_type_string:
                  json_object_object_add(newjobj, oldkey, json_object_new_string(json_object_get_string(oldval)));
                  break;
              case json_type_int:
                  json_object_object_add(newjobj, oldkey, json_object_new_int(json_object_get_int(oldval)));
                  break;
              default:
                  /* If we reach this line, the following assert() will fail. */
                  assert(oldkey_type == json_type_int || oldkey_type == json_type_string);
                  break;
            }
        }
    }

    // Add the newjobj back in the table
    update_json(nodename, timestamp, newjobj, db, overwrite);
    json_object_put(nodejobj);
    json_object_put(json_db);
    return;
}

void
insert_update_json(int dbts, char *nodename, time_t timestamp, json_object *jobj, sqlite3 *db)
{
    char TimeStamp[11];
    int rc;
    char *emsg = 0;
    char *sqlcmd;

    sqlcmd = (char *) malloc(MAX_SQL_SIZE);
    if (dbts < 0) {             // First time create a new row
        strcpy(sqlcmd, "insert into ");
    } else {                    // Not the first time no need to create a new row, just update
        strcpy(sqlcmd, "update ");
    }
    strcat(sqlcmd, SQLITE_DB_TB1NAME);

    if (dbts < 0) {
        strcat(sqlcmd, "(jsonblob, timestamp, nodename) values('");
    } else {
        strcat(sqlcmd, " set jsonblob='");
    }
    strcat(sqlcmd, json_object_to_json_string(jobj));
    strcat(sqlcmd, "', ");

    if (dbts < 0) {
        strcat(sqlcmd, "'");
    } else {
        strcat(sqlcmd, "timestamp='");
    }
    sprintf(TimeStamp, "%ld", (long) timestamp);
    strcat(sqlcmd, TimeStamp);
    strcat(sqlcmd, "'");

    if (dbts < 0) {
        strcat(sqlcmd, ",");
    } else {
        strcat(sqlcmd, " where nodename=");
    }
    strcat(sqlcmd, "'");
    strcat(sqlcmd, nodename);
    strcat(sqlcmd, "'");

    if (dbts < 0) {
        strcat(sqlcmd, ")");
    }
    //printf("CMD - %s\n",sqlcmd);
    if ((rc = sqlite3_exec(db, sqlcmd, nothing_todo, 0, &emsg) != SQLITE_OK)) {
        fprintf(stderr, "SQL error: %s\n", emsg);
        sqlite3_free(emsg);
    }
    free(sqlcmd);

    return;
}

int
NodeBID_fromDB(char *nodename, sqlite3 *db)
{
    int slen, rc;
    char *emsg = 0;
    int blobid = -1;
    char *sqlcmd = malloc(MAX_SQL_SIZE + 1);

    slen = snprintf(sqlcmd, MAX_SQL_SIZE + 1, "select rowid from %s where nodename='%s'", SQLITE_DB_TB1NAME, nodename);
    //printf("BID CMD - %s\n",sqlcmd);
    if ((rc = sqlite3_exec(db, sqlcmd, getint_callback, &blobid, &emsg) != SQLITE_OK)) {
        fprintf(stderr, "SQL error : %s\n", emsg);
        sqlite3_free(emsg);
    }
    free(sqlcmd);
    return (blobid);
}

int
NodeTS_fromDB(char *nodename, sqlite3 *db)
{
    int slen, rc;
    char *emsg = 0;
    int timestamp = -1;
    char *sqlcmd = malloc(MAX_SQL_SIZE + 1);

    slen = snprintf(sqlcmd, MAX_SQL_SIZE + 1, "select timestamp from %s where nodename='%s'", SQLITE_DB_TB1NAME, nodename);
//  printf("TS CMD - %s\n",sqlcmd);
    if ((rc = sqlite3_exec(db, sqlcmd, getint_callback, &timestamp, &emsg) != SQLITE_OK)) {
        fprintf(stderr, "SQL error : %s\n", emsg);
        sqlite3_free(emsg);
    }
    free(sqlcmd);
    return (timestamp);
}

char *
recvall(int sock)
{
    int count, r_payloadlen, numtoread;
    char *rbuf, *buffer;
    apphdr *app_h;
    appdata *app_d;

    rbuf = (char *) malloc(MAXPKTSIZE);
    app_h = (apphdr *) rbuf;
    app_d = (appdata *) (rbuf + sizeof(apphdr));

    /* block to receive the whole header */
    if ((count = recv(sock, rbuf, sizeof(apphdr), MSG_WAITALL)) == -1) {
        perror("recv");
        exit(1);
    }
#ifdef WWDEBUG
    printf("Received %d-byte header from %s into %lu-byte struct:  len %d, ts %d\n", count, app_h->nodename, sizeof(apphdr),
           app_h->len, (int) app_h->timestamp);
#endif

    /* plus 1 to store the NULL char */
    buffer = (char *) malloc(app_h->len + 1);
    buffer[0] = '\0';

    r_payloadlen = app_h->len;

    numtoread = MAXPKTSIZE - 1;
    while (r_payloadlen > 0) {
        if (r_payloadlen < MAXPKTSIZE - 1)
            numtoread = r_payloadlen;

        if ((count = recv(sock, rbuf, numtoread, 0)) == -1) {
            perror("recv");
            exit(1);
        }
        rbuf[count] = '\0';
        strcat(buffer, rbuf);
        r_payloadlen -= count;
    }
    free(rbuf);

#ifdef WWDEBUG
    printf("Payload:  %s\n", buffer);
#endif
    return buffer;
}

/* Handle any partial sends */
int
sendall(int s, char *buf, int total)
{
    int sendbytes = 0;
    int bytesleft = total;
    int n = 0;

    while (sendbytes < total) {
        if ((n = send(s, buf + sendbytes, bytesleft, MSG_NOSIGNAL)) == -1) {
            perror("send");
            break;
        }
        sendbytes = sendbytes + n;
        bytesleft = bytesleft - n;
    }
    return n == -1 ? errno : 0;
}

int
send_json(int sock, json_object *jobj)
{
    time_t timer;
    struct utsname unameinfo;
    char *buffer, *json_str;
    int json_len, bytes_left, buffer_len, bytestocopy, bytes_read, rval = 0;

    timer = time(NULL);
    uname(&unameinfo);
    buffer = (char *) malloc(MAXPKTSIZE);
    json_len = (int) strlen(json_object_to_json_string(jobj));
    // plus 1 for NULL char
    json_str = (char *) malloc(json_len + 1);
    strcpy(json_str, json_object_to_json_string(jobj));

    bytes_read = 0;
    bytes_left = json_len;

    while (bytes_read < json_len) {
        buffer_len = 0;

        if (bytes_read == 0) {
            apphdr *app_h = (apphdr *) buffer;
            appdata *app_d = (appdata *) (buffer + sizeof(apphdr));

            app_h->len = json_len;
            app_h->timestamp = timer;
            strcpy(app_h->nodename, unameinfo.nodename);

            bytestocopy = (MAXDATASIZE < bytes_left ? MAXDATASIZE : bytes_left);
            strncpy(app_d->payload, json_str, bytestocopy);

            buffer_len = sizeof(apphdr);  // to accomodate the header size
        } else {
            bytestocopy = (MAXPKTSIZE < bytes_left ? MAXPKTSIZE : bytes_left);
            strncpy(buffer, json_str + bytes_read, bytestocopy);
        }

        buffer_len += bytestocopy;

#ifdef WWDEBUG
        printf("Sending data ..\n");
#endif
        if ((rval = sendall(sock, buffer, buffer_len)) != 0) {
            //printf("Remote pipe has been severed \n");
            break;
        }

        bytes_read += bytestocopy;
        bytes_left -= bytestocopy;
    }

    free(json_str);
    free(buffer);
    return rval;
}

void
array_list_print(array_list *ls)
{
    int i;

    printf("[");
    for (i = 0; i < array_list_length(ls); i++) {
        printf("%d: %s", i, (char *) array_list_get_idx(ls, i));
        if (i != array_list_length(ls) - 1)
            printf(",");
    }
    printf(" ]\n");
}

/* void json_parse_complete(json_object *jobj); */

void
json_parse_complete(json_object *jobj)
{
    enum json_type type;

    json_object_object_foreach(jobj, key, val)
    {
        type = json_object_get_type(val);
        switch (type) {
          case json_type_string:
              printf("%s : %s\n", key, json_object_get_string(val));
              break;
          case json_type_int:
              printf("%s : %d\n", key, json_object_get_int(val));
              break;
          case json_type_object:
              printf("%s :\n", key);
              json_parse_complete(json_object_object_get(jobj, key));
              printf("\n");
              break;
          default:
              /* If we reach this line, the following assert() will fail. */
              assert(type == json_type_int || type == json_type_string || type == json_type_object);
              break;
        }
    }
}

void
json_parse(json_object *jobj)
{
    json_object_object_foreach(jobj, key, value)
    {
        printf("%s: %s\n", key, json_object_get_string(value));
    }
}

/*
 * Removes the new line character from the end of the 
 * string if it exists.
 */
char *
chomp(char *s)
{
    size_t slen;

    slen = strlen(s);
    if ((slen > 0) && (s[slen - 1] == '\n')) {
        s[slen - 1] = '\0';
    }
    return s;
}

/*
 * More efficient version of file_parser. Instead of accessing a file 
 * number of keys times, opens a file only once and collects
 * data as it parses. Upon successful location of the key and value,
 * function places kv-pair in json_object whose pointer is the return
 * value.
 */
json_object *
fast_data_parser(char *file_name, array_list *keys, int num_keys)
{
    FILE *fp;
    int i, keys_found = 0;
    json_object *jobj;

    jobj = json_object_new_object();
    if ((fp = fopen(file_name, "r")) != NULL) {
        char *line, *data;

        line = malloc(100);
        data = malloc(100);

        while (fgets(line, 100, fp)) {
            for (i = 0; i < num_keys; i++) {
                if ((data = strstr(line, array_list_get_idx(keys, i))) != NULL) {
                    while (*data != ':') {
                        data++;
                    }
                    while (isspace(*data) || ispunct(*data)) {
                        data++;
                    }
                    json_object_object_add(jobj, array_list_get_idx(keys, i), (json_object *) json_object_new_string(chomp(data)));
                    keys_found += 1;
                    if (keys_found == num_keys) {
                        break;
                    }
                }
            }
        }
        free(line);
        free(data);
        fclose(fp);
        return jobj;
    } else {
        printf("I/O ERROR: could not access file\n");
        return NULL;
    }
}

long
get_jiffs(cpu_data *cd)
{
    long total_jiffs, work_jiffs;
    int i = 0;
    FILE *fp;

    total_jiffs = 0;
    work_jiffs = 0;
    if ((fp = fopen("/proc/stat", "r")) != NULL) {
        char *line, *data;

        line = malloc(100);
        data = malloc(100);
        while (fgets(line, 100, fp)) {
            if ((data = strstr(line, "cpu")) != NULL) {
                char *result;

                result = strtok(data, " ");
                while (result != NULL) {
                    chomp(result);
                    if (strcmp("cpu", result)) {
                        if (i++ < 3) {
                            work_jiffs += atoi(result); // calculating work_jiffs
                        }
                        total_jiffs += atoi(result); // calculating total_jiffs
                    }
                    result = strtok(NULL, " ");
                }
            }
            i = 0;  // reset i to get each cpu's work_jiffs added
        }
        free(line);
        free(data);
        fclose(fp);
        cd->tj = total_jiffs;
        cd->wj = work_jiffs;

        return 0;
    } else {
#ifdef WWDEBUG
        printf("I/O ERROR: Could not access file (get_jiffs)\n");
#endif
        return -1;
    }
}

/*
float
get_cpu_util_old()
{
  struct cpu_data *fin = malloc(sizeof(struct cpu_data *));
  struct cpu_data *init = malloc(sizeof(struct cpu_data *));
  get_jiffs(init);
  sleep(2);
  get_jiffs(fin);
  
  long work_diff = fin->wj - init->wj;
  long  total_diff = fin->tj - init->tj;
  
  free(fin);
  free(init);
  
  return (float) work_diff/total_diff*100;

}
*/

int
key_exists_in_json(json_object *jobj, char *kname)
{
    json_object_object_foreach(jobj, key, value)
    {
        if (strcmp(key, kname) == 0) {
            return 1;
        }
    }
    return 0;
}

int
get_int_from_json(json_object *jobj, char *kname)
{
    json_object_object_foreach(jobj, key, value) 
    {
        if (strcmp(key, kname) == 0) {
            return json_object_get_int(value);
        }
    }
    return -1;
}

void
get_string_from_json(json_object *jobj, char *kname, char *str)
{
    json_object_object_foreach(jobj, key, value) 
    {
        if (strcmp(key, kname) == 0) {
            strcpy(str, json_object_get_string(value));
            return;
        }
    }
}

int
registerConntype(int sock, int type)
{
    json_object *jobj;

    jobj = json_object_new_object();
    json_object_object_add(jobj, "CONN_TYPE", json_object_new_int(type));

    send_json(sock, jobj);
    json_object_put(jobj);

    return (0);
}

int
setup_ConnectSocket(char *hostname, int port)
{
    int sock;
    struct sockaddr_in server_addr;
    struct hostent *host;

    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
        perror("socket");
        return -1;
    }

    // get the host info
    if ((host = gethostbyname(hostname)) == NULL) {
        perror("gethostbyname");
        return -1;
    }

    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(port);
    server_addr.sin_addr = *((struct in_addr *) host->h_addr);
    bzero(&(server_addr.sin_zero), 8);

    if (connect(sock, (struct sockaddr *) &server_addr, sizeof(struct sockaddr)) == -1) {
        perror("connect");
        return -1;
    }

    return sock;
}

int
createTable(sqlite3 *db, char tbl)
{
    int rc;
    char *eMsg = 0;
    char sqlcmd[MAX_SQL_SIZE];

    if (tbl == 1) {
        strcpy(sqlcmd, "CREATE TABLE IF NOT EXISTS " SQLITE_DB_TB1NAME " (nodename, timestamp, jsonblob, PRIMARY KEY(nodename))");
    } else if (tbl == 2) {
        strcpy(sqlcmd, "CREATE TABLE IF NOT EXISTS " SQLITE_DB_TB2NAME " (blobid, key, value, PRIMARY KEY(blobid, key))");
    } else {
        printf("createTable : Error - Unsupported table name \n");
        return 1;
    }
//  printf("SQL cmd : %s\n",sqlcmd);

    if ((rc = sqlite3_exec(db, sqlcmd, nothing_todo, 0, &eMsg) != SQLITE_OK)) {
        fprintf(stderr, "SQL error: %s\n", eMsg);
        sqlite3_free(eMsg);
    }

    return 0;
}

/*
 * vim:filetype=c:syntax=c:expandtab:ts=4:sw=4
 */
