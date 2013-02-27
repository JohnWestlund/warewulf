/*
 * Copyright (c) 2001-2003 Gregory M. Kurtzer
 * 
 * Copyright (c) 2003-2011, The Regents of the University of California,
 * through Lawrence Berkeley National Laboratory (subject to receipt of any
 * required approvals from the U.S. Dept. of Energy).  All rights reserved.
 *
 * Contributed by Anthony Salgado & Krishna Muriki
 * Warewulf Monitor (wwmon_aggregator.c)
 *
 */

#include "config.h"

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
#include <sys/utsname.h>

#include <json/json.h>
#include <sqlite3.h>

#include "config.h"
#include "globals.h"
#include "util.h"

// Database to hold data of each socket -- To be passed all over the place.
static sqlite3 *db;

int
json_from_db(void *void_json, int ncolumns, char **col_values, char **col_names)
{
    int i;
    json_object *json_db = (json_object *) void_json;
    int nodename_idx = -1, jsonblob_idx = -1, json_ct;

    // Find the indices
    for (i = 0; i < ncolumns; i++) {
        if (!strcmp(col_names[i], "nodename")) {
            nodename_idx = i;
        } else if (!strcmp(col_names[i], "jsonblob")) {
            jsonblob_idx = i;
        }
    }

    if (nodename_idx < 0) {
        // There are no nodes to be returned just return.
        return 0;
    }

    json_object_object_add(json_db, col_values[nodename_idx], json_object_new_string(col_values[jsonblob_idx]));
    json_ct = get_int_from_json(json_db, "JSON_CT");
    json_ct++;
    json_object_object_add(json_db, "JSON_CT", json_object_new_int(json_ct));

    return 0;
}

void
update_dbase(time_t TimeStamp, char *NodeName, json_object *jobj)
{
    int DBTimeStamp = -1;
    int blobid = -1;
    int overwrite = 0;
    //printf("NodeName - %s, TimeStamp - %ld\n", NodeName, TimeStamp);

    // Now check if the NodeName exists in the datastore table 
    // If so compare the timestamp values and decide what to do.
    if ((DBTimeStamp = NodeTS_fromDB(NodeName, db)) == -1) {
        // PKT with data from a new node 
        insert_json(NodeName, TimeStamp, jobj, db);
        blobid = NodeBID_fromDB(NodeName, db);
        insertLookups(blobid, jobj, db);
    } else if (DBTimeStamp < TimeStamp) {
        // PKT with newer time stamp
        blobid = NodeBID_fromDB(NodeName, db);
        overwrite = 1;
        update_insertLookups(blobid, jobj, db, overwrite);
        merge_json(NodeName, TimeStamp, jobj, db, overwrite);
#ifdef WWDEBUG
        printf("Just finished processing PKT with newer time stamp\n");
#endif
    } else if (DBTimeStamp >= TimeStamp) {
        // PKT with same time stamp or with older time stamp
        blobid = NodeBID_fromDB(NodeName, db);
        overwrite = 0;
#ifdef WWDEBUG
        printf("About to update & insert\n");
#endif
        update_insertLookups(blobid, jobj, db, overwrite);
#ifdef WWDEBUG
        printf("Just finished half processing PKT with older or same time stamp\n");
#endif
        merge_json(NodeName, TimeStamp, jobj, db, overwrite);
#ifdef WWDEBUG
        printf("Just finished processing PKT with older or same time stamp\n");
#endif
    }
}

void
read_and_dump_data(int fd)
{
    struct sockaddr_in their_addr;
    socklen_t addr_len;
    int numbytes;
    char buf[MAXPKTSIZE], *db_err;
    const char *json_obj_str = NULL;
    json_object *json_db;

    addr_len = sizeof(struct sockaddr);
    numbytes = recvfrom(fd, buf, MAXPKTSIZE - 1, 0, (struct sockaddr *) &their_addr, &addr_len);
    if (numbytes < 0) {
        perror("recvfrom");
        return;
    }
    buf[numbytes] = 0;
#ifdef WWDEBUG
    printf("got packet from %s\n", inet_ntoa(their_addr.sin_addr));
    printf("packet is %d bytes long\n", numbytes);
    printf("packet contains \"%s\"\n", buf);
#endif

    json_db = json_object_new_object();
    if (sqlite3_exec(db, "SELECT rowid,NodeName,key,value FROM wwstats", json_from_db, json_db, &db_err)) {
        /* FIXME:  Error handling! */
        fprintf(stderr, "SQLite3 DB Query failed:  %s\n", db_err);
        sqlite3_free(db_err);
        json_object_put(json_db);
        return;
    }
    json_obj_str = json_object_to_json_string(json_db);

    /* Send object over socket.  FIXME:  Use json_object_get_string() and json_object_get_string_len()? */
    if ((numbytes = sendto(fd, json_obj_str, strlen(json_obj_str), 0,
                           (struct sockaddr *) &their_addr, sizeof(struct sockaddr))) == -1) {
        perror("sendto");
    }
#ifdef WWDEBUG
    printf("sent %d bytes to %s\n", numbytes, inet_ntoa(their_addr.sin_addr));
#endif

    json_object_put(json_db);
    return;
}

int
write_handler(int fd)
{
    json_object *jobj;

    // Should we assume that even the TCP send's cannot be made when we want ?
    // In other words is it possible that TCP send's would wait or get stuck ? 
    // If so we cannot use send_json instead improve the logic here -- kmuriki
#ifdef WWDEBUG
    fprintf(stderr, "About to write on FD - %d, type - %d\n", fd, sock_data[fd].ctype);
#endif

    jobj = json_object_new_object();
    if (sock_data[fd].ctype == UNKNOWN) {
        json_object_object_add(jobj, "COMMAND", json_object_new_string("Send Type"));
    } else if (sock_data[fd].ctype == COLLECTOR) {
        json_object_object_add(jobj, "COMMAND", json_object_new_string("Send Data"));
    } else if (sock_data[fd].ctype == APPLICATION) {
        if (sock_data[fd].sqlite_cmd != NULL) {
            //printf("SQL cmd - %s\n", sock_data[fd].sqlite_cmd);
            json_object_object_add(jobj, "JSON_CT", json_object_new_int(0));
            sqlite3_exec(db, sock_data[fd].sqlite_cmd, json_from_db, jobj, NULL);
            //printf("JSON - %s\n",json_object_to_json_string(jobj));
            free(sock_data[fd].sqlite_cmd);
        } else {
            json_object_object_add(jobj, "COMMAND", json_object_new_string("Send SQL query"));
        }
    }

    send_json(fd, jobj);
    json_object_put(jobj);
    //printf("send successful!\n");

    FD_CLR(fd, &wfds);
    FD_SET(fd, &rfds);

    return 0;
}

int
read_handler(int fd)
{
    char rbuf[MAXPKTSIZE] = "";
    int readbytes;
    json_object *jobj;
    int ctype;
    int is_reg_pkt = 0;
    int numtoread;

#ifdef WWDEBUG
    fprintf(stderr, "About to read on FD - %d, type - %d\n", fd, sock_data[fd].ctype);
#endif

    // First check if there is any remaining payload from previous
    // transmission for this socket and decide the # of bytes to read.
    if ((sock_data[fd].r_payloadlen > 0) && (sock_data[fd].r_payloadlen < MAXPKTSIZE - 1)) {
        numtoread = sock_data[fd].r_payloadlen;
    } else {
        numtoread = MAXPKTSIZE - 1;
    }

    if ((readbytes = recv(fd, rbuf, numtoread, 0)) == -1) {
        perror("recv");
        FD_CLR(fd, &rfds);
        close(fd);
        return 0;
    }
    rbuf[readbytes] = '\0';
    //fprintf(stderr, "Rx a string of size %d - %s\n",readbytes,rbuf);
    //fprintf(stderr, "Rx a string of size %d \n",readbytes);

    // Is this required ?
    if (strlen(rbuf) == 0) {
#ifdef WWDEBUG
        fprintf(stderr, "\nSeems like the remote client connected\n");
        fprintf(stderr, "to this socket has closed its connection\n");
        fprintf(stderr, "So I'm closing the socket\n");
#endif
        FD_CLR(fd, &rfds);
        close(fd);
        return 0;
    }
    // If the read buffer is from pending transmission append to accrualbuf
    // Or else treat it as a new packet.
    if (sock_data[fd].r_payloadlen > 0) {
        strcat(sock_data[fd].accrual_buf, rbuf);
        sock_data[fd].r_payloadlen = sock_data[fd].r_payloadlen - readbytes;
    } else {
        apphdr *app_h = (apphdr *) rbuf;
        appdata *app_d = (appdata *) (rbuf + sizeof(apphdr));

        //printf("Len of the payload - %d, %s\n", app_h->len,app_d->payload);

        // plus 1 to store the NULL char
        sock_data[fd].accrual_buf = (char *) malloc(app_h->len + 1);
        strcpy(sock_data[fd].accrual_buf, app_d->payload);
        sock_data[fd].r_payloadlen = app_h->len - strlen(sock_data[fd].accrual_buf);
        //printf("strlen(sock_data[%d].accrual_buf) = %d\n", fd, strlen(sock_data[fd].accrual_buf));
    }

    if (sock_data[fd].r_payloadlen > 0) {
        //Still has more reading to do
        //printf("r_payloadlen = %d\n", sock_data[fd].r_payloadlen);
        return (0);
    }
#ifdef WWDEBUG
    printf("Done reading totally, now processing the received data packet\n");
#endif

/*
  if(sock_data[fd].ctype == UNKNOWN) {
	int ctype;
	ctype = get_int_from_json(json_tokener_parse(sock_data[fd].accrual_buf),"CONN_TYPE");
	if(ctype == -1) {
	  printf("Not able to determine type\n");
	} else {
	  sock_data[fd].ctype = ctype;
	  //printf("Conn type - %d on sock - %d\n",ctype, fd);
	}
   } else if(sock_data[fd].ctype == COLLECTOR) {
*/

    jobj = json_tokener_parse(sock_data[fd].accrual_buf);
    ctype = get_int_from_json(jobj, "CONN_TYPE");
    if (ctype == -1) {
#ifdef WWDEBUG
        printf("Either not able to determine type or not a registration packet\n");
#endif
    } else {
        sock_data[fd].ctype = ctype;
        is_reg_pkt = 1;
        //printf("Conn type - %d on sock - %d\n",ctype, fd);
    }

    if (is_reg_pkt != 1) {
        if (sock_data[fd].ctype == COLLECTOR) {
            apphdr *app_h = (apphdr *) rbuf;

            //printf("%s\n",sock_data[fd].accrual_buf);
            update_dbase(app_h->timestamp, app_h->nodename, jobj);
        } else if (sock_data[fd].ctype == APPLICATION) {
            const char *sqlite_cmd;
            size_t cmd_len = 0;
            json_object *json_sqlite_cmd;

            json_sqlite_cmd = json_object_object_get(jobj, "sqlite_cmd");
            if (json_sqlite_cmd) {
                sqlite_cmd = json_object_get_string(json_sqlite_cmd);
                cmd_len = json_object_get_string_len(json_sqlite_cmd);
            }

            sock_data[fd].sqlite_cmd = malloc(MAX_SQL_SIZE);
            if (cmd_len) {
                char sql_stmt[] = "SELECT nodename,jsonblob FROM " SQLITE_DB_TB1NAME " LEFT JOIN " SQLITE_DB_TB2NAME " ON "
                    SQLITE_DB_TB1NAME ".rowid = " SQLITE_DB_TB2NAME ".blobid WHERE ";

                /* FIXME */
                strcpy(sock_data[fd].sqlite_cmd, sql_stmt);
                strcat(sock_data[fd].sqlite_cmd, sqlite_cmd);
            } else {
                // App sent an empty SQL command so we need to return all JSONs we have
                strcpy(sock_data[fd].sqlite_cmd, "SELECT nodename,jsonblob FROM " SQLITE_DB_TB1NAME);
            }
        }
    }
    json_object_put(jobj);

    if (sock_data[fd].accrual_buf != NULL) {
        free(sock_data[fd].accrual_buf);
        sock_data[fd].accrual_buf = NULL;
    }
    FD_CLR(fd, &rfds);
    FD_SET(fd, &wfds);
    return 0;
}

int
setup_sockets(int port, int *stcp, int *sudp)
{
    // new TCP socket
    if ((*stcp = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)) < 0) {
        perror("TCP socket");
        return -1;
    }
    // new UDP socket
    if ((*sudp = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0) {
        perror("UDP socket");
        return -1;
    }
    // don't whine about address already in use
    int n = 1;
    if (setsockopt(*stcp, SOL_SOCKET, SO_REUSEADDR, (char *) &n, sizeof(n)) < 0) {
        perror("TCP setsockopt");
        return -1;
    }
    if (setsockopt(*sudp, SOL_SOCKET, SO_REUSEADDR, (char *) &n, sizeof(n)) < 0) {
        perror("UDP setsockopt");
        return -1;
    }
    // bind socket to some port
    struct sockaddr_in sin;
    bzero(&sin, sizeof(sin));
    sin.sin_family = AF_INET;
    sin.sin_port = htons(port);
    sin.sin_addr.s_addr = INADDR_ANY;
    if (bind(*stcp, (struct sockaddr *) &sin, sizeof(sin)) < 0) {
        perror("TCP bind");
        return -1;
    }
    if (bind(*sudp, (struct sockaddr *) &sin, sizeof(sin)) < 0) {
        perror("UDP bind");
        return -1;
    }
    // listen for incoming connections
    if (listen(*stcp, 5) < 0) {
        perror("TCP listen");
        return -1;
    }

    return (0);
}

int
accept_conn(int fd)
{
    int c;
    struct sockaddr_in sin;
    socklen_t sinlen = sizeof(sin);

    bzero(&sin, sinlen);
    if ((c = accept(fd, (struct sockaddr *) &sin, &sinlen)) < 0) {
        perror("accept");
        return -1;
    }
    strcpy(sock_data[c].remote_sock_ipaddr, inet_ntoa(sin.sin_addr));

#ifdef WWDEBUG
    fprintf(stderr, "Accepted a new connection on fd - %d from %s\n", c, sock_data[c].remote_sock_ipaddr);
#endif

    // Initialize all the variables
    // Connection type unknown at this time
    sock_data[c].ctype = UNKNOWN;
    sock_data[c].r_payloadlen = 0;
    sock_data[c].sqlite_cmd = NULL;
    sock_data[c].accrual_buf = NULL;

    // Register interest in a read on this socket to know more about the connection.
    FD_SET(c, &rfds);

    return c;
}

int
main(int argc, char *argv[])
{
    int stcp = -1;
    int sudp = -1;

    int rc = -1;

    if (argc != 2) {
        fprintf(stderr, "Usage: %s [port]\n", argv[0]);
        exit(1);
    }

/* Include this only if we are *not* compiling a debug version */
#ifndef WWDEBUG
    /* Fork and background (basically) */
    pid_t pid = fork();
    if (pid != 0) {
        if (pid < 0) {
            perror("AGGREGATOR: Failed to fork");
            exit(1);
        }
        exit(0);
    }
#endif

    bzero(sock_data, sizeof(sock_data));

    // Get the database ready
    // Attempt to open database & check for failure
#ifdef WWDEBUG
    printf("Attempting to open database: %s\n", SQLITE_DB_FNAME);
#endif
    rc = sqlite3_open(SQLITE_DB_FNAME, &db);
    if (rc) {
        fprintf(stderr, "Can't open database: %s\n", sqlite3_errmsg(db));
        sqlite3_close(db);
        exit(1);
    } else {
        // Now check & create tables if required 
        createTable(db, SQLITE_DB_TB1NAME);
        createTable(db, SQLITE_DB_TB2NAME);
#ifdef WWDEBUG
        printf("Database ready for reading and writing...\n");
#endif
    }

    // Prepare to accept clients
    FD_ZERO(&rfds);
    FD_ZERO(&wfds);

    // Open TCP (SOCK_STREAM) & UDP (SOCK_DGRAM) sockets, bind to the port 
    // given and listen on TCP sock for connections
    if ((setup_sockets(atoi(argv[1]), &stcp, &sudp)) < 0) {
        perror("WWAGGREGATOR: Error setting up Sockets\n");
        exit(1);
    }
#ifdef WWDEBUG
    printf("Our listen sock # is - %d & UDP sock # is - %d \n", stcp, sudp);
#endif
    //printf("FD_SETSIZE - %d\n",FD_SETSIZE);

    //Add the created TCP & UDP sockets to the read set of file descriptors
    FD_SET(stcp, &rfds);
    FD_SET(sudp, &rfds);

    // Event loop
    while (1) {

        int n = 0;
        fd_set _rfds, _wfds;

        memcpy(&_rfds, &rfds, sizeof(fd_set));
        memcpy(&_wfds, &wfds, sizeof(fd_set));

        // Block until there's an event to handle
        // Select function call is made; return value 'n' gives the number of FDs ready to be serviced
        if (((n = select(FD_SETSIZE, &_rfds, &_wfds, NULL, 0)) < 0) && (errno != EINTR)) {
            perror("select");
            exit(1);
        }
        // Handle events
        for (int i = 0; (i < FD_SETSIZE) && n; i++) {

            if (FD_ISSET(i, &_rfds)) {
                // Handle our main mother, TCP listening socket differently
                if (i == stcp) {
                    if (accept_conn(stcp) < 0)
                        exit(1);
                    // Handle our UDP socket differently
                } else if (i == sudp) {
                    read_and_dump_data(sudp);
                } else {
#ifdef WWDEBUG
                    fprintf(stderr, "File descriptor %d is ready for reading .. call'g readHLR\n", i);
#endif
                    read_handler(i);
                }

                n--;
            }

            if (FD_ISSET(i, &_wfds)) {
#ifdef WWDEBUG
                fprintf(stderr, "File descriptor %d is ready for writing .. call'g writeHLR\n", i);
#endif
                write_handler(i);
                n--;
            }
        }
    }
}

/*
 * vim:filetype=c:syntax=c:expandtab:ts=4:sw=4
 */
