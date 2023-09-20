cmake_minimum_required(VERSION 3.0.2)

set(PROJECT_NAME
        xmrblocks)


project(${PROJECT_NAME})

set(CMAKE_CXX_STANDARD 11)

if (WIN32)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wa,-mbig-obj -O3")
endif()


if (NOT PEPENET_DIR)
    set(PEPENET_DIR "ext/pepenet")
endif()

message(STATUS PEPENET_DIR ": ${PEPENET_DIR}")

if (NOT PEPENET_SOURCE_DIR)
    set(PEPENET_SOURCE_DIR ${PEPENET_DIR}
          CACHE PATH "Path to the root directory for Pepenet")
endif()

if (NOT PEPENET_BUILD_DIR)
    # set location of pepenet build tree
    set(PEPENET_BUILD_DIR ${PEPENET_SOURCE_DIR}/build/release/
          CACHE PATH "Path to the build directory for Pepenet")

   if (NOT EXISTS ${PEPENET_BUILD_DIR})   
        # try different location   
        message(STATUS "Trying different folder for pepenet libraries")
        set(PEPENET_BUILD_DIR ${PEPENET_SOURCE_DIR}/build/Linux/master/release/
            CACHE PATH "Path to the build directory for Pepenet" FORCE)
    endif()

endif()

if (NOT EXISTS ${PEPENET_BUILD_DIR})   
  message(FATAL_ERROR "Pepenet libraries not found in: ${PEPENET_BUILD_DIR}")
endif()

set(MY_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}/cmake"
        CACHE PATH "The path to the cmake directory of the current project")

list(APPEND CMAKE_MODULE_PATH "${MY_CMAKE_DIR}")

set(CMAKE_LIBRARY_PATH ${CMAKE_LIBRARY_PATH} "${PEPENET_BUILD_DIR}"
        CACHE PATH "Add Pepenet directory for library searching")
include(MyUtils)

find_package(Pepenet)

# find boost
find_package(Boost COMPONENTS
        system
        filesystem
        thread
        date_time
        chrono
        regex
        serialization
        program_options
        date_time
        REQUIRED)

#info https://github.com/arsenm/sanitizers-cmake
find_package(Sanitizers)

if(APPLE)
    include_directories(/usr/local/opt/openssl@1.1/include)
    link_directories(/usr/local/opt/openssl@1.1/lib)
    link_directories(/usr/local/lib)
endif()

MESSAGE(STATUS "Looking for libunbound") # FindUnbound.cmake from pepenet repo

FIND_PATH(UNBOUND_INCLUDE_DIR
  NAMES unbound.h
  PATH_SUFFIXES include/ include/unbound/
  PATHS "${PROJECT_SOURCE_DIR}"
  ${UNBOUND_ROOT}
  $ENV{UNBOUND_ROOT}
  /usr/local/
  /usr/
)

find_library (UNBOUND_LIBRARY unbound)
if (WIN32 OR (${UNBOUND_LIBRARY} STREQUAL "UNBOUND_LIBRARY-NOTFOUND"))
    add_library(unbound STATIC IMPORTED)
    set_property(TARGET unbound PROPERTY IMPORTED_LOCATION ${PEPENET_BUILD_DIR}/external/unbound/libunbound.a)
endif()

if("${Xmr_WALLET-CRYPTO_LIBRARIES}" STREQUAL "Xmr_WALLET-CRYPTO_LIBRARY-NOTFOUND")
  set(WALLET_CRYPTO "")
else()
  set(WALLET_CRYPTO ${Xmr_WALLET-CRYPTO_LIBRARIES})
endif()

# include boost headers
include_directories(${Boost_INCLUDE_DIRS})

# include pepenet
include_directories(${PEPENET_SOURCE_DIR}/build)
find_package(Protobuf REQUIRED)
find_package(Boost COMPONENTS iostreams serialization system filesystem thread program_options regex chrono REQUIRED)

include_directories("ext/mstch/include")
include_directories("ext/mstch/include/src")
include_directories("ext/crow")

# add ext/ subfolder
add_subdirectory(ext/)

# add src/ subfolder
add_subdirectory(src/)


set(SOURCE_FILES
        main.cpp)

#ADD_CUSTOM_TARGET(driver DEPENDS src/templates/index.html)

add_executable(pnetblocks
        ${SOURCE_FILES})

add_sanitizers(${PROJECT_NAME})

create_git_version()

configure_files(${CMAKE_CURRENT_SOURCE_DIR}/src/templates ${CMAKE_CURRENT_BINARY_DIR}/templates)
configure_files(${CMAKE_CURRENT_SOURCE_DIR}/src/templates/css ${CMAKE_CURRENT_BINARY_DIR}/templates/css)
configure_files(${CMAKE_CURRENT_SOURCE_DIR}/src/templates/partials ${CMAKE_CURRENT_BINARY_DIR}/templates/partials)
configure_files(${CMAKE_CURRENT_SOURCE_DIR}/src/templates/js ${CMAKE_CURRENT_BINARY_DIR}/templates/js)

set(LIBRARIES
        myxrm
        myext
        mstch
        wallet
        cryptonote_core
        cryptonote_basic
        cryptonote_protocol
        cryptonote_format_utils_basic
        blockchain_db
        device
        ${WALLET_CRYPTO} 
        multisig
        daemonizer
        blocks
        lmdb
        ringct
        ringct_basic
        common
        mnemonics
        easylogging
        checkpoints
        cncrypto        
        miniupnpc
        version
        epee
        hardforks
        randomx
        sodium
        ${Boost_LIBRARIES}
        pthread
        unbound
        curl
        crypto
        ssl
        pepenet_social
        ${Protobuf_LIBRARIES}
        Boost::iostreams
        Boost::serialization
        Boost::program_options
        Boost::system
        Boost::filesystem
        Boost::thread
        Boost::regex
        Boost::chrono
        lzma
        )

if(APPLE)
    set(LIBRARIES ${LIBRARIES} "-framework IOKit -framework Foundation")
else()
    set(LIBRARIES ${LIBRARIES} atomic)
endif()

find_library(UNWIND_LIBRARY unwind)
if (${UNWIND_LIBRARY} STREQUAL "UNWIND_LIBRARY-NOTFOUND")
  message (STATUS "unwind library not found")
  set (UNWIND_LIBRARY "")
else ()
  message (STATUS "Found unwind library: ${UNWIND_LIBRARY}")
endif ()

if (NOT ${CMAKE_SYSTEM_NAME} MATCHES "Darwin" AND NOT WIN32)
    set(LIBRARIES ${LIBRARIES} ${UNWIND_LIBRARY})
endif()

if (WIN32)
    set(LIBRARIES ${LIBRARIES}
            wsock32
            ntdll
            ws2_32
            Iphlpapi
            )
else()
    set(LIBRARIES ${LIBRARIES} dl)
endif()

find_package(HIDAPI)
set(LIBRARIES ${LIBRARIES} ${HIDAPI_LIBRARIES})

target_link_libraries(pnetblocks ${LIBRARIES})
