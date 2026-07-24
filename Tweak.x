// FixWANotifs — raises the Jetsam memory limit of WhatsApp's notification ServiceExtension.
//
// runningboardd assigns the extension a 24 MiB limit via memorystatus_control(). A heavy
// account can exceed 24 MiB while decoding an incoming push, so iOS terminates the extension
// with a per-process-limit JetsamEvent and the notification is lost while WhatsApp is closed.
//
// The tweak injects into runningboardd and hooks memorystatus_control().
// When runningboardd sets the exact 24 MiB limit on the WhatsApp ServiceExtension, the request
// is rewritten to FIXWA_TARGET_MIB. All other processes, commands, and limit values pass
// through unchanged; unrecognised buffer layouts pass through unmodified.

#import <substrate.h>
#import <string.h>
#import <stdbool.h>
#import <stdint.h>
#import <mach-o/dyld.h>
#import <os/log.h>
#import <dispatch/dispatch.h>

// iOS's default limit for the extension; only a request equal to this is rewritten.
#define FIXWA_CANDIDATE_MIB 24

// New limit. If notifications still drop and a per-process-limit JetsamEvent still
// appears for the extension, raise this (48 / 64 / 96) and rebuild.
#define FIXWA_TARGET_MIB    40

// ---- memorystatus_control -----------------------------------------------------
#define MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK 5
#define MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT      6
#define MEMORYSTATUS_CMD_SET_MEMLIMIT_PROPERTIES    7

typedef struct memorystatus_memlimit_properties {
    int32_t  memlimit_active;         // limit (MiB) while process is foreground/active
    uint32_t memlimit_active_attr;
    int32_t  memlimit_inactive;       // limit (MiB) while process is background/inactive
    uint32_t memlimit_inactive_attr;
} memorystatus_memlimit_properties_t;

extern int memorystatus_control(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t buffersize);

#define PROC_PIDPATHINFO_MAXSIZE 4096

extern int proc_pidpath(int pid, void *buffer, uint32_t buffersize);

static int (*orig_memorystatus_control)(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t buffersize);

// static os_log_t fixwa_log(void) {
//     static os_log_t log;
//     static dispatch_once_t once;
//     dispatch_once(&once, ^{ log = os_log_create("com.0xkuj.fixwanotifs", "jetsam"); });
//     return log;
// }

// True only for the WhatsApp notification ServiceExtension executable.
static bool fixwa_is_target_pid(int32_t pid) {
    if (pid < 2) return false;
    char path[PROC_PIDPATHINFO_MAXSIZE];
    int n = proc_pidpath(pid, path, sizeof(path));
    if (n <= 0) return false;

    static const char suffix[] = "/WhatsApp.app/PlugIns/ServiceExtension.appex/ServiceExtension";
    size_t plen = strlen(path);
    size_t slen = sizeof(suffix) - 1;
    if (plen >= slen && strcmp(path + (plen - slen), suffix) == 0) return true;

    if (strstr(path, "/WhatsApp") && strstr(path, "ServiceExtension.appex")) return true;
    return false;
}

static int hooked_memorystatus_control(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t buffersize) {
    // Primary path: full memory-limit properties (what runningboardd uses on iOS 15/16).
    if (command == MEMORYSTATUS_CMD_SET_MEMLIMIT_PROPERTIES &&
        buffer != NULL && buffersize == sizeof(memorystatus_memlimit_properties_t)) {

        memorystatus_memlimit_properties_t *props =
            (memorystatus_memlimit_properties_t *)buffer;
        bool active_is_candidate   = (props->memlimit_active   == FIXWA_CANDIDATE_MIB);
        bool inactive_is_candidate = (props->memlimit_inactive == FIXWA_CANDIDATE_MIB);

        if ((active_is_candidate || inactive_is_candidate) && fixwa_is_target_pid(pid)) {
            // Local copy — the caller's buffer is never mutated.
            memorystatus_memlimit_properties_t local = *props;
            if (active_is_candidate)   local.memlimit_active   = FIXWA_TARGET_MIB;
            if (inactive_is_candidate) local.memlimit_inactive = FIXWA_TARGET_MIB;

            int rv = orig_memorystatus_control(command, pid, flags, &local, buffersize);
            //os_log(fixwa_log(), "FixWANotifs: rewrote WhatsApp SE (pid %d) %d MiB -> %d MiB (rv=%d)", pid, FIXWA_CANDIDATE_MIB, FIXWA_TARGET_MIB, rv);
            return rv;
        }
    }

    // Secondary path: legacy single-value high-water / task limit (limit carried in flags).
    // if ((command == MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK ||
    //      command == MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT) &&
    //     (int32_t)flags == FIXWA_CANDIDATE_MIB && fixwa_is_target_pid(pid)) {

    //     int rv = orig_memorystatus_control(command, pid, (uint32_t)FIXWA_TARGET_MIB,
    //                                        buffer, buffersize);
    //     //os_log(fixwa_log(), "FixWANotifs: rewrote WhatsApp SE (pid %d) high-water %d -> %d MiB (rv=%d)", pid, FIXWA_CANDIDATE_MIB, FIXWA_TARGET_MIB, rv);
    //     return rv;
    // }

    return orig_memorystatus_control(command, pid, flags, buffer, buffersize);
}

static bool fixwa_in_runningboardd(void) {
    char path[PROC_PIDPATHINFO_MAXSIZE];
    uint32_t size = sizeof(path);
    if (_NSGetExecutablePath(path, &size) != 0) return false;
    size_t plen = strlen(path);
    static const char name[] = "/runningboardd";
    size_t nlen = sizeof(name) - 1;
    return (plen >= nlen && strcmp(path + (plen - nlen), name) == 0);
}

%ctor {
    if (!fixwa_in_runningboardd()) return;
    MSHookFunction((void *)memorystatus_control,
                   (void *)hooked_memorystatus_control,
                   (void **)&orig_memorystatus_control);

    //os_log(fixwa_log(), "FixWANotifs: hook installed in runningboardd (target %d MiB)", FIXWA_TARGET_MIB);
}
