#!/usr/bin/env bash

set -euo pipefail

TMPDIR="$1"

need() { command -v "$1" >/dev/null 2>&1 || { echo "MISSING: $1"; exit 1; }; }
have() { command -v "$1" >/dev/null 2>&1; }
say()  { printf "\n\033[1m==> %s\033[0m\n" "$*"; }
ok()   { printf "  [\033[32mPASS\033[0m] %s\n" "$*"; }
bad()  { printf "  [\033[31mFAIL\033[0m] %s\n" "$*"; }
info() { printf "      %s\n" "$*"; }

need capsh
need setpriv
need getcap
need mktemp
need setcap

SCHELPER="$TMPDIR/bin/sc_demo"         # loads filter, blocks uname, prints NNP before/after
SCEXEC="$TMPDIR/bin/sc_demo_exec"      # loads filter, prints NNP before/after, then execs given program
SCPROBE="$TMPDIR/bin/probe_uname"      # probe for uname EPERM
SCSTACK2="$TMPDIR/bin/sc_stack2"       # add 2nd filter (block gettid), prints NNP before/after
NOCAP="$TMPDIR/bin/nocap_exec"         # clear E/P/I/A then exec target
AMBEX="$TMPDIR/bin/amb_exec"           # raise ambient cap_net_bind_service and set NNP then exec

# File-cap tagged copies for 'rocky' tests:
SCHELPER_CAP="$TMPDIR/bin/sc_demo_cap"       # sc_demo with cap_sys_admin=ep (used earlier)
SCEXEC_CAP="$TMPDIR/bin/sc_demo_exec_cap"    # sc_demo_exec with cap_sys_admin=ep (wrapper with exec)
BINDCAP="$TMPDIR/bin/bindcap"                # program that checks CAP_NET_BIND_SERVICE and binds low port
BINDCAP_CAP="$TMPDIR/bin/bindcap_cap"        # same, tagged with cap_net_bind_service=ep

# Prepare file-cap tagged copies (root needed)
if [ "$(id -u)" -eq 0 ]; then
  cp "$SCHELPER" "$SCHELPER_CAP" 2>/dev/null || true
  cp "$SCEXEC"   "$SCEXEC_CAP"   2>/dev/null || true
  cp "$BINDCAP"  "$BINDCAP_CAP"  2>/dev/null || true
  chown root:root "$SCHELPER_CAP" "$SCEXEC_CAP" "$BINDCAP_CAP" 2>/dev/null || true
  chmod 755 "$SCHELPER_CAP" "$SCEXEC_CAP" "$BINDCAP_CAP" 2>/dev/null || true
  setcap cap_sys_admin=ep "$SCHELPER_CAP" 2>/dev/null || true
  setcap cap_sys_admin=ep "$SCEXEC_CAP"   2>/dev/null || true
  setcap cap_net_bind_service=ep "$BINDCAP_CAP" 2>/dev/null || true
  info "File caps:"
  getcap "$SCHELPER_CAP" "$SCEXEC_CAP" "$BINDCAP_CAP" 2>/dev/null || true
else
  info "Not root; file-cap based tests may be skipped."
fi

# Test 1: File capabilities vs no_new_privs
say "Test 1: File capabilities vs no_new_privs"
CAN_SETCAP=0
if capsh --has-p=cap_setfcap >/dev/null 2>&1 || [ "$(id -u)" -eq 0 ]; then CAN_SETCAP=1; fi

if [ "$CAN_SETCAP" -eq 1 ]; then
  CAPBASH="$TMPDIR/capbash"
  cp /bin/bash "$CAPBASH"
  setcap cap_sys_admin=ep "$CAPBASH"
  info "Tagged $CAPBASH with cap_sys_admin=ep"

  say "1A) NNP OFF -> expect CAP_SYS_ADMIN appears via file cap"
  if "$CAPBASH" -c 'capsh --has-p=cap_sys_admin' >/dev/null 2>&1; then
    ok "NNP off: CAP_SYS_ADMIN observed"
  else
    bad "NNP off: CAP_SYS_ADMIN not observed"
  fi

  say "1B) NNP ON (demoted uid/gid) -> file-cap elevation should be suppressed"
  if setpriv --reuid 65534 --regid 65534 --clear-groups --no-new-privs -- \
       "$CAPBASH" -c 'capsh --has-p=cap_sys_admin' >/dev/null 2>&1; then
    bad "NNP on: CAP_SYS_ADMIN still present (unexpected)"
  else
    ok "NNP on: CAP_SYS_ADMIN suppressed as expected"
  fi

  say "1C) Drop from bounding set -> elevation blocked even with NNP OFF"
  if setpriv --bounding-set=~cap_sys_admin -- \
       "$CAPBASH" -c 'capsh --has-p=cap_sys_admin' >/dev/null 2>&1; then
    bad "Bounding set dropped but CAP_SYS_ADMIN appeared"
  else
    ok "Bounding set drop prevented elevation"
  fi
else
  info "Skipping Test 1 (need CAP_SETFCAP/root to set file capabilities)."
fi

# Test 2: Ambient capabilities survive exec under NNP (userns)
say "Test 2: Ambient capabilities survive exec under NNP (inside user namespace)"
if [ -x "$AMBEX" ] && have unshare; then
  MAP=""; unshare --map-current-user -Urpf --mount-proc sh -c 'exit 0' 2>/dev/null && MAP="--map-current-user"
  if unshare $MAP -Urpf --mount-proc -- "$AMBEX" /bin/sh -c 'capsh --has-p=cap_net_bind_service >/dev/null 2>&1 && echo PASS || echo FAIL' | grep -q PASS; then
    ok "Ambient capability preserved across exec with NNP (via amb_exec)"
  else
    bad "Ambient capability check failed (verify libcap-devel/gcc and userns support)"
  fi
else
  info "Skipping Test 2 (need unshare + gcc + libcap-devel)."
fi

if [ -x "$SCHELPER" ]; then
  say "Test 3: Seccomp install paths (CAP_SYS_ADMIN avoids needing NNP)"

  say "3A) Truly unprivileged, NNP OFF -> should FAIL"
  OUT="$( setpriv --reuid 65534 --regid 65534 --clear-groups \
                 --bounding-set=-all --inh-caps=-all --ambient-caps=-all \
                 -- env SC_DEMO_NNP=0 "$NOCAP" "$SCHELPER" 2>&1 || true )"
  echo "$OUT" | grep -q 'before_load NNP=0' >/dev/null || info "note: NNP-before not observed (older kernel/libseccomp?)"
  if echo "$OUT" | grep -q SECCOMP_OK; then
    bad "Unexpected success installing seccomp without CAP_SYS_ADMIN and without NNP"
  else
    ok "Failed as expected without CAP_SYS_ADMIN and without NNP"
  fi

  say "3B) Unprivileged, NNP ON -> should SUCCEED"
  if setpriv --reuid 65534 --regid 65534 --clear-groups --no-new-privs -- "$SCHELPER" | grep -q SECCOMP_OK; then
    ok "Seccomp installed with NNP (unprivileged path)"
  else
    bad "Seccomp with NNP failed (verify libseccomp/kernel support)"
  fi

  say "3C) In user namespace, keep NNP OFF via libseccomp attr -> should SUCCEED with CAP_SYS_ADMIN-in-userns"
  if have unshare; then
    MAP=""; unshare --map-current-user -Urpf --mount-proc sh -c 'exit 0' 2>/dev/null && MAP="--map-current-user"
    if unshare $MAP -Urpf --mount-proc -- env SC_DEMO_NNP=0 "$SCHELPER" | grep -q SECCOMP_OK; then
      ok "Seccomp installed with NNP=0 using CAP_SYS_ADMIN in user namespace"
    else
      bad "Userns CAP_SYS_ADMIN path failed (check userns/libseccomp availability)"
    fi
  else
    info "Skipping 3C: unshare not available."
  fi

  say "3D) Host root with CAP_SYS_ADMIN, keep NNP OFF via libseccomp attr -> should SUCCEED"
  if [ "$(id -u)" -eq 0 ]; then
    if env SC_DEMO_NNP=0 "$SCHELPER" | grep -q SECCOMP_OK; then ok "Host CAP_SYS_ADMIN path succeeded with NNP kept off (attr disabled)"; else bad "Host CAP_SYS_ADMIN path failed"; fi
  else
    info "Not root; skipping 3D."
  fi

  say "3D-user) Non-root 'rocky' with NNP kept OFF (no CAP_SYS_ADMIN) -> should FAIL"
  if have runuser && id rocky >/dev/null 2>&1; then
    if runuser -u rocky -- sh -c 'set -e; setpriv --bounding-set=-all --inh-caps=-all --ambient-caps=-all -- env SC_DEMO_NNP=0 '"$SCHELPER"' 2>/dev/null'; then
      bad "Unexpected success installing seccomp as non-root without NNP and without CAP_SYS_ADMIN"
    else
      ok "Failed as expected as non-root when NNP is off and no CAP_SYS_ADMIN"
    fi
  else
    info "Skipping 3D-user (no runuser or user \"rocky\" not found)."
  fi

  say "3D-fcaps) Non-root 'rocky' with CAP_SYS_ADMIN via file caps, NNP kept OFF -> should SUCCEED"
  if id rocky >/dev/null 2>&1 && [ -x "$SCHELPER_CAP" ]; then
    if runuser -u rocky -- env SC_DEMO_NNP=0 "$SCHELPER_CAP" | grep -q SECCOMP_OK; then
      ok "Seccomp installed as non-root using file-cap CAP_SYS_ADMIN with NNP kept off"
    else
      bad "File-cap path failed (check xattrs/bounding set/SELinux/AppArmor)"
    fi
  else
    info "Skipping 3D-fcaps (no 'rocky' user or cap-tagged sc_demo missing)."
  fi

  # 3E: persistence across exec
  if [ -x "$SCEXEC" ] && [ -x "$SCPROBE" ]; then
    say "3E) Persistence across exec -> filter should still block uname in the exec'd program"
    if setpriv --no-new-privs -- "$SCEXEC" "$SCPROBE" | grep -q PROBE_UNAME_EPERM; then ok "Filter persisted across exec"; else bad "Persistence check failed"; fi
  else
    info "Skipping 3E (missing sc_demo_exec or probe_uname)."
  fi

  # 3F: monotonic tightening
  if [ -x "$SCEXEC" ] && [ -x "$SCSTACK2" ]; then
    say "3F) Monotonic tightening -> add second filter; uname and gettid should be blocked"
    OUT="$(setpriv --no-new-privs -- "$SCEXEC" "$SCSTACK2" || true)"
    echo "$OUT" | grep -q STACK_UNAME_EPERM  && A=1 || A=0
    echo "$OUT" | grep -q STACK_GETTID_EPERM && B=1 || B=0
    if [ $A -eq 1 ] && [ $B -eq 1 ]; then ok "Second filter loaded; uname and gettid both blocked"; else printf "%s\n" "$OUT" | sed 's/^/      out: /'; bad "Monotonic check failed"; fi
  else
    info "Skipping 3F (missing sc_demo_exec or sc_stack2)."
  fi
else
  info "Skipping Test 3 (seccomp helper not built)."
fi

# Test 4: File caps after seccomp load (NNP off vs on)
say "Test 4: File-cap CAP_NET_BIND_SERVICE after seccomp load (rocky, with/without NNP)"
if id rocky >/dev/null 2>&1 && [ -x "$SCEXEC_CAP" ] && [ -x "$BINDCAP_CAP" ]; then
  say "4A) rocky + CAP_SYS_ADMIN via file cap + NNP OFF -> file-cap elevation should work after seccomp"
  OUT="$(runuser -u rocky -- env SC_DEMO_NNP=0 "$SCEXEC_CAP" "$BINDCAP_CAP" 2>&1 || true)"
  echo "$OUT" | sed 's/^/      out: /'
  if echo "$OUT" | grep -q 'CAP_BIND_EFF=1' || echo "$OUT" | grep -q 'BIND_PRIV_OK'; then
    ok "With NNP off, file-cap CAP_NET_BIND_SERVICE applied post-seccomp (cap present and/or bind succeeded)"
  else
    bad "Expected CAP_NET_BIND_SERVICE after exec with NNP off; none observed"
  fi

  say "4B) rocky + CAP_SYS_ADMIN via file cap + NNP ON (default) -> file-cap elevation should be suppressed"
  OUT="$(runuser -u rocky -- "$SCEXEC_CAP" "$BINDCAP_CAP" 2>&1 || true)"
  echo "$OUT" | sed 's/^/      out: /'
  if echo "$OUT" | grep -q 'CAP_BIND_EFF=1\|BIND_PRIV_OK'; then
    bad "Unexpected file-cap elevation with NNP on (should have been suppressed)"
  else
    ok "With NNP on, file-cap CAP_NET_BIND_SERVICE was suppressed after seccomp (as expected)"
  fi
else
  info "Skipping Test 4 (need user 'rocky' and cap-tagged sc_demo_exec + bindcap)."
fi

say "Summary"
echo "  • Test 1: NNP suppresses file-cap elevation; bounding set masks file caps entirely."
echo "  • Test 2: Ambient caps survive exec under NNP for plain binaries (userns)."
echo "  • Test 3: Installing seccomp needs NNP or CAP_SYS_ADMIN; we prove both branches, incl. userns and file-cap paths."
echo "  • Test 4: After seccomp, file caps work only when NNP is OFF; NNP ON suppresses them."
echo "Done."





echo "$TMPDIR"
