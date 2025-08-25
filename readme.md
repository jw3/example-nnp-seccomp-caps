seccomp nnp caps
===

## tests 

1. NNP suppresses file-cap elevation; bounding set masks file caps entirely
2. Ambient caps survive exec under NNP for plain binaries (userns)
3. Installing seccomp needs NNP or CAP_SYS_ADMIN; we prove both branches, incl. userns and file-cap paths
4. After seccomp, file caps work only when NNP is OFF; NNP ON suppresses them

tested on rocky 9, hardcoded to "rocky" user

## prep

needs cmake and build tools, seccomp and caps dev libs

## run

as rocky run ./run.sh
