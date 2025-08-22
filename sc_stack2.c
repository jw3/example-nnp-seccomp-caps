#include <seccomp.h>
#include <sys/utsname.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/prctl.h>

#ifndef PR_GET_NO_NEW_PRIVS
#define PR_GET_NO_NEW_PRIVS 39
#endif

static void print_nnp(const char *tag) {
  int r = prctl(PR_GET_NO_NEW_PRIVS, 0, 0, 0, 0);
  if (r == -1) perror("PR_GET_NO_NEW_PRIVS"); else printf("%s NNP=%d\n", tag, r);
}

static void check_uname(void) {
  struct utsname u;
  errno = 0;
  if (uname(&u) == -1 && errno == EPERM) puts("STACK_UNAME_EPERM");
  else if (errno == 0)
    puts("STACK_UNAME_OK");
  else printf("STACK_UNAME_ERRNO_%d\n", errno);
}

int main(void) {
  check_uname();
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
  if (seccomp_rule_add(ctx, SCMP_ACT_ERRNO(EPERM), SCMP_SYS(gettid), 0)) {
    perror("seccomp_rule_add");
    return 2;
  }
  print_nnp("before_load");
  if (seccomp_load(ctx)) {
    perror("seccomp_load");
    return 3;
  }
  print_nnp("after_load");
  errno = 0;
  long t = syscall(SYS_gettid);
  if (t == -1 && errno == EPERM) {
    puts("STACK_GETTID_EPERM");
    return 0;
  }
  if (t > 0 && errno == 0) {
    puts("STACK_GETTID_OK");
    return 0;
  }
  printf("STACK_GETTID_ERRNO_%d\n", errno);
  return 4;
}