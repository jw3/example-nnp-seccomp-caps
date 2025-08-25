#include <sys/capability.h>
#include <sys/prctl.h>
#include <linux/prctl.h>
#include <linux/capability.h>
#include <unistd.h>
#include <stdio.h>

extern char **environ;

static void die(const char *m) {
  perror(m);
  _exit(127);
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: amb_exec <program> [args...]\n");
    return 2;
  }
  cap_t c = cap_get_proc();
  if (!c) die("cap_get_proc");
  cap_value_t v = CAP_NET_BIND_SERVICE;
  if (cap_set_flag(c, CAP_INHERITABLE, 1, &v, CAP_SET) == -1) die("cap_set_flag INH");
  if (cap_set_proc(c) == -1) die("cap_set_proc");
  cap_free(c);
  if (prctl(PR_CAP_AMBIENT, PR_CAP_AMBIENT_RAISE, CAP_NET_BIND_SERVICE, 0, 0) == -1) die("prctl AMBIENT_RAISE");
  if (prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) == -1) die("prctl NNP");
  execve(argv[1], &argv[1], environ);
  die("execve");
}