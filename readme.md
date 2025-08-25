seccomp nnp caps
===

## tests 

1. NNP suppresses file-cap elevation; bounding set masks file caps entirely
2. Ambient caps survive exec under NNP for plain binaries (user namespace)
3. Installing seccomp needs NNP or CAP_SYS_ADMIN
    - prove both branches; including user namespace and file-cap paths
4. After seccomp, file caps work only when NNP is OFF; NNP ON suppresses file caps

tested on rocky 9, hardcoded to "rocky" user

## prep

needs cmake and build tools, seccomp and caps dev libs

## run

running with sudo will execute all tests, running as rocky will skip 1, 3D, 3D-fcaps, 4

`run.sh`

## references

* **seccomp syscall & filter mode**

   * `seccomp(2)` man page — semantics of `SECCOMP_SET_MODE_FILTER`, inheritance across `fork()`/persistence across `execve()`, TSYNC, and the “NNP or CAP\_SYS\_ADMIN” precondition. ([man7.org][1])
   * Kernel docs: *Seccomp BPF (userspace API)* — overview and design notes. ([Kernel Documentation][2])
   * `prctl(PR_SET_SECCOMP, SECCOMP_MODE_FILTER)` wrapper docs. ([man7.org][3])

* **no\_new\_privs (NNP)**

   * `PR_SET_NO_NEW_PRIVS` — definition and “exec will not grant new privileges (setuid and file caps disabled)”; inheritance and irreversibility. ([man7.org][4], [Arch Manual Pages][5])
   * Kernel text note on NNP interactions/caveats. ([Kernel][6])

* **Linux capabilities (general, ambient, file)**

   * `capabilities(7)` — core model; ambient capabilities (preserved across *non-privileged* exec; cleared on setuid/file-caps exec); bounding set behavior; file caps and versioning (VFS\_CAP\_REVISION\_3 w/ namespaced rootid). ([man7.org][7])
   * `PR_CAP_AMBIENT` operations (raise/lower/clear). ([man7.org][8])

* **Bounding set specifics**

   * `PR_CAPBSET_DROP` / `PR_CAPBSET_READ` man pages — dropping is one-way; bounding set constrains file-cap gains on future `execve()`. ([man7.org][9])
   * Additional discussion in `capabilities(7)`. ([man7.org][10], [Debian Manpages][11])

* **User namespaces & namespaced file caps**

   * `user_namespaces(7)` — capabilities are scoped to the userns; creator/owner semantics. ([man7.org][12], [Ubuntu Manpages][13])
   * Namespaced (v3) file capabilities and rootid encoding in `security.capability`. ([Arch Manual Pages][14])
   * Background explainer on unprivileged file capabilities. ([Personal blog of Christian Brauner][15])

* **Fork vs exec effects (caps/NNP/seccomp)**

   * `seccomp(2)` — filters inherited on `fork()` and preserved across `execve()`. ([man7.org][1])
   * `PR_SET_NO_NEW_PRIVS` — NNP inherited on fork; blocks new privs on exec. ([Arch Manual Pages][5])
   * `capabilities(7)` — capability sets copied on `fork()`; recomputed on `execve()` w/ ambient/file caps rules. ([man7.org][7])

* **libseccomp specifics**

   * `seccomp_attr_set(3)` — `SCMP_FLTATR_CTL_NNP` attribute (default ON; disable if you intend to keep NNP=0 and rely on CAP\_SYS\_ADMIN to load). ([Debian Manpages][16])
   * `seccomp_init(3)` / `seccomp_load(3)` / `seccomp_rule_add(3)` man pages. ([man7.org][17], [Arch Manual Pages][18])

* **Tooling man pages used in tests**

   * `setpriv(1)` — manipulating bounding/inheritable/ambient sets and `--no-new-privs`. ([Arch Manual Pages][19])
   * `unshare(1)` — (for creating user namespaces; see also the userns man page linked above). ([man7.org][12])

* **Extra, for color/confirmations**

   * Kerrisk slides (NDC TechTown): succinct statements that seccomp filters are additive and cannot be removed once installed. ([man7.org][20])
   * Ubuntu man mirror for `seccomp(2)` repeating inheritance/persistence text. ([Ubuntu Manpages][21])

[1]: https://man7.org/linux/man-pages/man2/seccomp.2.html "seccomp(2) - Linux manual page"
[2]: https://docs.kernel.org/userspace-api/seccomp_filter.html?utm_source=chatgpt.com "Seccomp BPF (SECure COMPuting with filters)"
[3]: https://man7.org/linux/man-pages/man2/pr_set_seccomp.2const.html?utm_source=chatgpt.com "PR_SET_SECCOMP(2const) - Linux manual page"
[4]: https://man7.org/linux/man-pages/man2/PR_SET_NO_NEW_PRIVS.2const.html?utm_source=chatgpt.com "PR_SET_NO_NEW_PRIVS(2const) - Linux manual page"
[5]: https://man.archlinux.org/man/core/man-pages/PR_SET_NO_NEW_PRIVS.2const.en?utm_source=chatgpt.com "PR_SET_NO_NEW_PRIVS(2const)"
[6]: https://www.kernel.org/doc/Documentation/prctl/no_new_privs.txt?utm_source=chatgpt.com "no_new_privs"
[7]: https://man7.org/linux/man-pages/man7/capabilities.7.html "capabilities(7) - Linux manual page"
[8]: https://man7.org/linux/man-pages/man2/pr_cap_ambient.2const.html?utm_source=chatgpt.com "PR_CAP_AMBIENT(2const) - Linux manual page"
[9]: https://man7.org/linux/man-pages/man2/pr_capbset_drop.2const.html?utm_source=chatgpt.com "PR_CAPBSET_DROP(2const) - Linux manual page"
[10]: https://man7.org/linux/man-pages/man7/capabilities.7.html?utm_source=chatgpt.com "capabilities(7) - Linux manual page"
[11]: https://manpages.debian.org/bookworm/manpages/capabilities.7.en.html?utm_source=chatgpt.com "capabilities(7) - bookworm"
[12]: https://man7.org/linux/man-pages/man7/user_namespaces.7.html?utm_source=chatgpt.com "user_namespaces(7) - Linux manual page"
[13]: https://manpages.ubuntu.com/manpages/focal/man7/user_namespaces.7.html?utm_source=chatgpt.com "user_namespaces - overview of Linux user namespaces"
[14]: https://man.archlinux.org/man/capabilities.7.en?utm_source=chatgpt.com "capabilities(7)"
[15]: https://brauner.io/2018/08/05/unprivileged-file-capabilities.html?utm_source=chatgpt.com "Unprivileged File Capabilities - Christian Brauner"
[16]: https://manpages.debian.org/unstable/libseccomp-dev/seccomp_attr_set.3.en.html?utm_source=chatgpt.com "seccomp_attr_set(3) — libseccomp-dev — Debian unstable"
[17]: https://man7.org/linux/man-pages/man3/seccomp_init.3.html?utm_source=chatgpt.com "seccomp_init(3) - Linux manual page - man7.org"
[18]: https://man.archlinux.org/man/seccomp_load.3.en?utm_source=chatgpt.com "seccomp_load(3) - Arch Linux manual pages"
[19]: https://man.archlinux.org/man/setpriv.1.en?utm_source=chatgpt.com "setpriv(1) — Arch manual pages"
[20]: https://man7.org/conf/ndctechtown2018/limiting-the-kernel-attack-surface-with-seccomp-NDC-TechTown-Kerrisk.pdf?utm_source=chatgpt.com "Using seccomp to limit the kernel attack surface"
[21]: https://manpages.ubuntu.com/manpages/bionic/man2/seccomp.2.html?utm_source=chatgpt.com "seccomp - operate on Secure Computing state of the process"
