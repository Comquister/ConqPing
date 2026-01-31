cmake_minimum_required(VERSION 3.10)
project(conqping)

set(CMAKE_CXX_STANDARD 17)

add_executable(conqping conqping.cpp)

if(WIN32)
    target_link_libraries(conqping ws2_32)
endif()
