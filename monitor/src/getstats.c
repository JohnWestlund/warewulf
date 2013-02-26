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

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <string.h>
#include <limits.h>
#include <sys/socket.h>
#include <sys/sysinfo.h>
#include <sys/utsname.h>
#include <ctype.h>

#include "getstats.h"
#include "util.h"

// The Generic Buffersize to use
#define BUFFERSIZE 512

// Where is the status file to determine the node status
#define STATUSFILE "/.nodestatus"

// Sleep time inbetween loops
#define REFRESH 1

char *
get_cpu_info(json_object *jobj)
{
    FILE *fd;
    unsigned int cpu_count = 0;
    unsigned int cpu_clock = 0;
    char *tmp;
    char buffer[BUFFERSIZE];
    char cpu_model[BUFFERSIZE] = "";
    static char ret[BUFFERSIZE];

    if ((fd = fopen("/proc/cpuinfo", "r")) == NULL) {
        printf("could not open /proc/cpuinfo!\n");
        exit(EXIT_FAILURE);  /* FIXME:  Bad idea! */
    }

    while (fgets(buffer, sizeof(buffer), fd)) {
        if (!BEG_STRCMP(buffer, "processor  ")) {
//      printf("found: %s\n", buffer);
            cpu_count++;
        } else if (!cpu_clock && !BEG_STRCMP(buffer, "cpu MHz  ")) {
            tmp = strchr(buffer, ':') + 1;
            cpu_clock = atoll(tmp);
//      printf("clock: -%d-\n", cpu_clock);
        } else if (!*cpu_model && !BEG_STRCMP(buffer, "model name  ")) {
            tmp = strchr(buffer, ':') + 1;
            while (isspace(*tmp)) {
                tmp++;
            }
            strcpy(cpu_model, tmp);
//      printf("model: %s\n", cpu_model);
        }
    }
    fclose(fd);

    json_object_object_add(jobj, "CPUCOUNT", json_object_new_int(cpu_count));
    json_object_object_add(jobj, "CPUCLOCK", json_object_new_int(cpu_clock));
    json_object_object_add(jobj, "CPUMODEL", json_object_new_string(cpu_model));

//  printf("CPUCOUNT=%d\nCPUCLOCK=%d\n", cpu_count, cpu_clock);
    snprintf(ret, sizeof(ret), "CPUCOUNT=%d\nCPUCLOCK=%d\nCPUMODEL=%s\n", cpu_count, cpu_clock, cpu_model);
    return ret;
}

char *
get_load_avg(json_object *jobj)
{
    FILE *fd;
    char buffer[BUFFERSIZE];
    static char ret[BUFFERSIZE];
    char *ptr;

    if ((fd = fopen("/proc/loadavg", "r")) == NULL) {
        printf("could not open /proc/loadavg!\n");
        exit(EXIT_FAILURE);  /* FIXME:  Bad idea! */
    }
    fgets(buffer, sizeof(buffer), fd);
    fclose(fd);

    ptr = (char *) strtok(buffer, " ");
    json_object_object_add(jobj, "LOADAVG", json_object_new_string(ptr));

    snprintf(ret, sizeof(ret), "LOADAVG=%s\n", ptr);
    return ret;
}

char *
get_cpu_util(json_object *jobj)
{
    FILE *fd;
    char buffer[BUFFERSIZE];
    static char ret[BUFFERSIZE];
    char *tmp;
    unsigned long u_ticks = 0, n_ticks = 0, s_ticks = 0, i_ticks = 0, t_ticks = 0;
    static unsigned long u_ticks_o = 0, n_ticks_o = 0, s_ticks_o = 0, i_ticks_o = 0;
    unsigned int result;

    if ((fd = fopen("/proc/stat", "r")) == NULL) {
        printf("could not open /proc/stat!\n");
        exit(EXIT_FAILURE);  /* FIXME:  Bad idea! */
    }

    while (fgets(buffer, sizeof(buffer), fd)) {
        if (!BEG_STRCMP(buffer, "cpu ")) {
//      printf("found: %s\n", buffer);

            /* FIXME:  Use sscanf() here? */
            // skip 'cpu'
            tmp = (char *) strtok(buffer, " ");

            // user
            tmp = (char *) strtok(NULL, " ");
            u_ticks = atoll(tmp);

            // nice
            tmp = (char *) strtok(NULL, " ");
            n_ticks = atoll(tmp);

            // system
            tmp = (char *) strtok(NULL, " ");
            s_ticks = atoll(tmp);

            // idle
            tmp = (char *) strtok(NULL, " ");
            i_ticks = atoll(tmp);

            break;
        }
    }
    fclose(fd);

    t_ticks = ((u_ticks + s_ticks + i_ticks + n_ticks) - (u_ticks_o + s_ticks_o + i_ticks_o + n_ticks_o));

    if (t_ticks == 0) {
        /* No ticks have accrued. */
        result = 0;
    } else {
        /* Calculate CPU utilization percentage */
        if ((result = (int) (((u_ticks - u_ticks_o + n_ticks - n_ticks_o) * 100) / t_ticks)) > 100) {
            /* In the event we get CPU utilization of >100%, cap it at 100% */
            result = 100;
        }

        // Save tick counts for the next loop
        u_ticks_o = u_ticks;
        n_ticks_o = n_ticks;
        s_ticks_o = s_ticks;
        i_ticks_o = i_ticks;
    }
    /* FIXME:  This was commented out, but without this, the return value will always be empty. */
    snprintf(ret, sizeof(ret), "CPUUTIL=%d\n", result);
    json_object_object_add(jobj, "CPUUTIL", json_object_new_int(result));

    return ret;
}

char *
get_mem_stats(json_object *jobj)
{
    FILE *fd;
    char buffer[BUFFERSIZE];
    static char ret[BUFFERSIZE];
    char *tmp = 0;
    unsigned long int memt = 0, memf = 0, memb = 0, mema = 0, memc = 0, swapt = 0, swapf = 0;
    float memp = 0.00, swapp = 0.00;

    if ((fd = fopen("/proc/meminfo", "r")) == NULL) {
        perror("could not open /proc/meminfo!\n");
        exit(EXIT_FAILURE);  /* FIXME:  Bad idea! */
    }

    while (fgets(buffer, sizeof(buffer), fd)) {
        if (!BEG_STRCMP(buffer, "MemTotal:")) {
            tmp = strchr(buffer, ':') + 1;
            memt = atoll(tmp);
        } else if (!BEG_STRCMP(buffer, "MemFree:")) {
            tmp = strchr(buffer, ':') + 1;
            memf = atoll(tmp);
        } else if (!BEG_STRCMP(buffer, "Buffers:")) {
            tmp = strchr(buffer, ':') + 1;
            memb = atoll(tmp);
        } else if (!BEG_STRCMP(buffer, "Cached:")) {
            tmp = strchr(buffer, ':') + 1;
            memc = atoll(tmp);
        } else if (!BEG_STRCMP(buffer, "SwapTotal:")) {
            tmp = strchr(buffer, ':') + 1;
            swapt = atoll(tmp);
        } else if (!BEG_STRCMP(buffer, "SwapFree:")) {
            tmp = strchr(buffer, ':') + 1;
            swapf = atoll(tmp);
        }
    }
    fclose(fd);

    /* Memory Avail */
    mema = memf + memb + memc;
//  printf("MEMTOTAL=%lu\nMEMAVAIL=%lu\n", memt, memf + memb + memc );
    if (memt > 0) {
        memp = 1.0 * (memt - mema) / memt * 100;
    }
    if (swapt > 0) {
        swapp = 1.0 * (swapt - swapf) / swapt * 100;
    }
    /* FIXME:  Why is this commented out?
       snprintf(ret, sizeof(ret), 
       "MEMTOTAL=%lu\nMEMAVAIL=%lu\nMEMUSED=%lu\nMEMPERCENT=%.0f\n"
       "SWAPTOTAL=%lu\nSWAPFREE=%lu\nSWAPUSED=%lu\nSWAPPERCENT=%.0f\n", 
       memt / 1024,
       mema / 1024,
       ( memt - mema ) / 1024,
       memp,
       swapt / 1024,
       swapf / 1024,
       ( swapt - swapf ) / 1024,
       swapp );
     */

    json_object_object_add(jobj, "MEMTOTAL", json_object_new_int(memt / 1024));
    json_object_object_add(jobj, "MEMAVAIL", json_object_new_int(mema / 1024));
    json_object_object_add(jobj, "MEMUSED", json_object_new_int((memt - mema) / 1024));
    json_object_object_add(jobj, "MEMPERCENT", json_object_new_int(memp));
    json_object_object_add(jobj, "SWAPTOTAL", json_object_new_int(swapt / 1024));
    json_object_object_add(jobj, "SWAPFREE", json_object_new_int(swapf / 1024));
    json_object_object_add(jobj, "SWAPUSED", json_object_new_int((swapt - swapf) / 1024));
    json_object_object_add(jobj, "SWAPPERCENT", json_object_new_int(swapp));

    return ret;
}

char *
get_node_status(json_object *jobj)
{
    FILE *fd;
    unsigned int tmp = 0;
    char buffer[BUFFERSIZE] = "unavailable";
    static char ret[BUFFERSIZE];

    if ((fd = fopen(STATUSFILE, "r")) != NULL) {
        fgets(buffer, sizeof(buffer), fd);
        fclose(fd);
    }

    while (!isspace(buffer[tmp])) {
        tmp++;
    }
    buffer[tmp] = '\0';
    json_object_object_add(jobj, "NODESTATUS", json_object_new_string(buffer));

    snprintf(ret, sizeof(ret), "NODESTATUS=%s\n", buffer);
    return ret;
}

char *
get_net_stats(json_object *jobj)
{
    FILE *fd;
    char buffer[BUFFERSIZE];
    static char ret[BUFFERSIZE];
    char *ifname, *data;
    unsigned long long receive = 0, transmit = 0;
    unsigned long long t_receive = 0, t_transmit = 0;
    static unsigned long long receive_o = 0, transmit_o = 0;

    if ((fd = fopen("/proc/net/dev", "r")) == NULL) {
        perror("Could not open /proc/net/dev!\n");
        exit(EXIT_FAILURE);  /* FIXME:  Bad idea! */
    }
    while (fgets(buffer, sizeof(buffer), fd)) {
        unsigned long long r, t;

        data = strchr(buffer, ':');
        if (!data) {
            continue;
        }
        *data = 0;
        data++;
        for (ifname = buffer; isspace(*ifname); ifname++) ;
        if (!strcmp(ifname, "lo")) {
            /* Ignore loopback interface */
            continue;
        }
        if (sscanf(data, "%Lu %*u %*u %*u %*u %*u %*u %*u %Lu", &r, &t) == 2) {
            receive += r;
            transmit += t;
        }
    }
    fclose(fd);

    if (receive_o) {
        // Handle counter rollover
        t_receive = ((receive_o > receive) ? (UINT_MAX - receive_o + receive) : (receive - receive_o));
        t_receive = (((t_receive / REFRESH) + 512) / 1024);
    }
    if (transmit_o) {
        // Handle counter rollover
        t_transmit = ((transmit_o > transmit) ? (UINT_MAX - transmit_o + transmit) : (transmit - transmit_o));
        t_transmit = (((t_transmit / REFRESH) + 512) / 1024);
    }
    receive_o = receive;
    transmit_o = transmit;

    json_object_object_add(jobj, "NETTRANSMIT", json_object_new_int(t_transmit));
    json_object_object_add(jobj, "NETRECEIVE", json_object_new_int(t_receive));

    snprintf(ret, sizeof(ret), "NETTRANSMIT=%llu\nNETRECIEVE=%llu\n", t_transmit, t_receive);
    return ret;
}

char *
get_sysinfo(json_object *jobj)
{
    struct sysinfo sys_info = { 0 };
    static char ret[BUFFERSIZE];

    if (sysinfo(&sys_info)) {
        perror("Failure during sysinfo() call.");
    }

    json_object_object_add(jobj, "PROCS", json_object_new_int(sys_info.procs));
    json_object_object_add(jobj, "UPTIME", json_object_new_int(sys_info.uptime));

    snprintf(ret, sizeof(ret), "PROCS=%d\nUPTIME=%lu\n", sys_info.procs, sys_info.uptime);
    return ret;
}

char *
get_uname(json_object *jobj)
{
    struct utsname unameinfo = { 0 };
    static char ret[BUFFERSIZE];

    if (uname(&unameinfo)) {
        perror("Failure during uname() call.");
    }

    json_object_object_add(jobj, "SYSNAME", json_object_new_string(unameinfo.sysname));
    json_object_object_add(jobj, "NODENAME", json_object_new_string(unameinfo.nodename));
    json_object_object_add(jobj, "RELEASE", json_object_new_string(unameinfo.release));
    json_object_object_add(jobj, "VERSION", json_object_new_string(unameinfo.version));
    json_object_object_add(jobj, "MACHINE", json_object_new_string(unameinfo.machine));

    snprintf(ret, sizeof(ret), "SYSNAME=%s\nNODENAME=%s\nRELEASE=%s\nVERSION=%s\nMACHINE=%s\n",
             unameinfo.sysname, unameinfo.nodename, unameinfo.release, unameinfo.version, unameinfo.machine);
    return ret;
}

/*
 * vim:filetype=c:syntax=c:expandtab:ts=4:sw=4
 */
