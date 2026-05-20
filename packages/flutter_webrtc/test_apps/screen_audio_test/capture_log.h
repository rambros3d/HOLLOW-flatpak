#ifndef SCREEN_AUDIO_TEST_CAPTURE_LOG_H_
#define SCREEN_AUDIO_TEST_CAPTURE_LOG_H_

#include <cstdio>

#define CAPLOG(fmt, ...) fprintf(stderr, "[CAPTURE] " fmt "\n", ##__VA_ARGS__)

#endif  // SCREEN_AUDIO_TEST_CAPTURE_LOG_H_
