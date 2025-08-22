#include <sys/capability.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>

int main(void) {
  int eff = 0, perm = 0;
  cap_t c = cap_get_proc();
  if (c) {
    cap_flag_value_t fv;
    cap_get_flag(c, CAP_NET_BIND_SERVICE, CAP_EFFECTIVE, &fv);
    eff = (fv == CAP_SET);
    cap_get_flag(c, CAP_NET_BIND_SERVICE, CAP_PERMITTED, &fv);
    perm = (fv == CAP_SET);
    cap_free(c);
  }
  printf("CAP_BIND_EFF=%d PERM=%d\n", eff, perm);
  int s = socket(AF_INET, SOCK_STREAM, 0);
  if (s < 0) {
    perror("socket");
    return 1;
  }
  int on = 1;
  setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));
  struct sockaddr_in a = {0};
  a.sin_family = AF_INET;
  a.sin_port = htons(602);
  a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  if (bind(s, (struct sockaddr *) &a, sizeof(a)) == 0) {
    puts("BIND_PRIV_OK");
    close(s);
    return 0;
  } else {
    printf("BIND_PRIV_ERRNO_%d\n", errno);
    close(s);
    return 0;
  }
}