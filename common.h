#include <sys/prctl.h>
#include <sys/utsname.h>
#include <errno.h>
#include <stdio.h>

#ifndef PR_GET_NO_NEW_PRIVS
#define PR_GET_NO_NEW_PRIVS 39
#endif

void print_nnp(const char *tag) {
  int r = prctl(PR_GET_NO_NEW_PRIVS, 0, 0, 0, 0);
  if (r == -1) perror("PR_GET_NO_NEW_PRIVS"); else printf("%s NNP=%d\n", tag, r);
}

void check_uname(void) {
  struct utsname u;
  errno = 0;
  if (uname(&u) == -1 && errno == EPERM) puts("STACK_UNAME_EPERM");
  else if (errno == 0)
    puts("STACK_UNAME_OK");
  else printf("STACK_UNAME_ERRNO_%d\n", errno);
}