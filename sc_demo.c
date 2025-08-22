#include <seccomp.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/utsname.h>
#include <sys/prctl.h>

#ifndef PR_GET_NO_NEW_PRIVS
#define PR_GET_NO_NEW_PRIVS 39
#endif

static void print_nnp(const char *tag) {
  int r = prctl(PR_GET_NO_NEW_PRIVS, 0, 0, 0, 0);
  if (r == -1) perror("PR_GET_NO_NEW_PRIVS"); else printf("%s NNP=%d\n", tag, r);
}

int main(void) {
  scmp_filter_ctx ctx = seccomp_init(SCMP_ACT_ALLOW);
  if (!ctx) {
    perror("seccomp_init");
    return 1;
  }
  const char *nnp = getenv("SC_DEMO_NNP");
  if (nnp && nnp[0] == '0') {
    if (seccomp_attr_set(ctx, SCMP_FLTATR_CTL_NNP, 0) != 0) {
      perror("seccomp_attr_set(CTL_NNP=0)");
      return 90;
    }
  }
  if (seccomp_rule_add(ctx, SCMP_ACT_ERRNO(EPERM), SCMP_SYS(uname), 0)) {
    perror("seccomp_rule_add");
    return 2;
  }
  print_nnp("before_load");
  if (seccomp_load(ctx)) {
    perror("seccomp_load");
    return 3;
  }
  print_nnp("after_load");
  struct utsname u;
  errno = 0;
  int r = uname(&u);
  if (r == -1 && errno == EPERM) {
    puts("SECCOMP_OK");
    return 0;
  }
  if (r == 0) {
    fputs("uname unexpectedly succeeded\n", stderr);
    return 4;
  }
  fprintf(stderr, "uname failed errno=%d\n", errno);
  return 5;
}