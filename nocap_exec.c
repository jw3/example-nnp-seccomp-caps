#include <sys/capability.h>
#include <sys/prctl.h>
#include <linux/prctl.h>
#include <unistd.h>
#include <stdio.h>

extern char **environ;

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: nocap_exec <program> [args...]\n");
    return 2;
  }
  cap_t c = cap_init();
  cap_clear(c);
  cap_set_proc(c);
  cap_free(c);
  prctl(PR_CAP_AMBIENT, PR_CAP_AMBIENT_CLEAR_ALL, 0, 0, 0);
  execve(argv[1], &argv[1], environ);
  perror("execve");
  return 127;
}