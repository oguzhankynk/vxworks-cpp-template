if(HELLO_VX_DKM)
  # Kernel module: adds a helloGreet("name") command to the kernel shell.
  add_executable(greet_dkm greet_dkm.cpp)
  target_link_libraries(greet_dkm PRIVATE hello::hello)
  hello_set_warnings(greet_dkm)
  return()
endif()

# Host program or VxWorks RTP (greet_cli.vxe): the same source either way.
add_executable(greet_cli greet_cli.cpp)
target_link_libraries(greet_cli PRIVATE hello::hello)
hello_set_warnings(greet_cli)
