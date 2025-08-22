cmake_minimum_required(VERSION 3.10)
project(example_nnp_seccomp_caps C)

set(CMAKE_C_STANDARD 11)

add_executable(amb_exec amb_exec.c)
target_link_libraries(amb_exec cap)

add_executable(bindcap bindcap.c)
target_link_libraries(bindcap cap)

add_executable(nocap_exec nocap_exec.c)
target_link_libraries(nocap_exec cap)

add_executable(probe_uname probe_uname.c)

add_executable(sc_demo sc_demo.c)
target_link_libraries(sc_demo seccomp)

add_executable(sc_demo_exec sc_demo_exec.c)
target_link_libraries(sc_demo_exec seccomp)

add_executable(sc_stack2 sc_stack2.c)
target_link_libraries(sc_stack2 seccomp)

install(TARGETS amb_exec bindcap nocap_exec probe_uname sc_demo sc_demo_exec sc_stack2 DESTINATION bin)