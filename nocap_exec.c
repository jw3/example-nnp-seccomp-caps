#include <sys/capability.h>
#include <sys/prctl.h>
#include <linux/prctl.h>
#include <unistd.h>
#include <stdio.h>

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: nocap_exec <program> [args...]\n");
    return 2;
  }
  cap_t c = cap_init();
  cap_clear(c);
  cap_set_proc(c);
  cap_free(c);
#ifndef PR_CAP_AMBIENT
#define PR_CAP_AMBIENT 47
#define PR_CAP_AMBIENT_CLEAR_ALL 5
#endif
  prctl(PR_CAP_AMBIENT, PR_CAP_AMBIENT_CLEAR_ALL, 0, 0, 0);
  execvp(argv[1], &argv[1]);
  perror("execvp");
  return 127;
}