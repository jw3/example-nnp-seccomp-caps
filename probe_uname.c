#include <sys/utsname.h>
#include <errno.h>
#include <stdio.h>

int main(void) {
  struct utsname u;
  errno = 0;
  if (uname(&u) == -1 && errno == EPERM) {
    puts("PROBE_UNAME_EPERM");
    return 0;
  }
  if (errno == 0) {
    puts("PROBE_UNAME_OK");
    return 0;
  }
  printf("PROBE_UNAME_ERRNO_%d\n", errno);
  return 1;
}