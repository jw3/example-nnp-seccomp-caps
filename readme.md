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
