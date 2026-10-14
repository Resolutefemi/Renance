// Memory probe: boots the real content library exactly like cmd/api does
// (Load + a walk of every key through the lazy cache) and prints peak RSS.
// Diagnostic tool for the 2026-10-14 memory doctrine - not shipped in the
// Docker image (dockerignore covers cmd/ except api).
package main

import (
	"fmt"
	"os"
	"runtime"
	"runtime/debug"
	"strconv"
	"strings"

	"renance.dev/study-api/internal/cbtdata"
	"renance.dev/study-api/internal/grading"
)

func peakRSS() uint64 {
	raw, err := os.ReadFile("/proc/self/status")
	if err != nil {
		return 0
	}
	for _, line := range strings.Split(string(raw), "\n") {
		if strings.HasPrefix(line, "VmHWM:") {
			fields := strings.Fields(line)
			if len(fields) >= 2 {
				kb, _ := strconv.ParseUint(fields[1], 10, 64)
				return kb * 1024
			}
		}
	}
	return 0
}

func main() {
	debug.SetMemoryLimit(420 << 20)
	lib, err := cbtdata.Load("/home/z/my-project/renance/data")
	if err != nil {
		panic(err)
	}
	fmt.Printf("after Load:            peak RSS %6.1f MiB  (banks %d, keyed %d)\n",
		float64(peakRSS())/(1<<20), len(lib.Manifest().Exams), lib.KeyedBankCount())

	// Simulate a busy server: pull keys for every keyed bank through the
	// lazy cache (worst-case walk, bounded by the cache caps).
	kc := grading.NewLazyKeyCache(lib)
	n := 0
	for _, ex := range lib.Manifest().Exams {
		if keys, ok := kc.Get(ex.Code); ok {
			n += len(keys)
		}
	}
	runtime.GC()
	fmt.Printf("after full key walk:   peak RSS %6.1f MiB  (keys served %d)\n", float64(peakRSS())/(1<<20), n)

	// And a burst of bundle parses past the LRU cap.
	for i, ex := range lib.Manifest().Exams {
		if i >= 200 {
			break
		}
		lib.Bundle(ex.Code)
	}
	runtime.GC()
	fmt.Printf("after 200 bank parses: peak RSS %6.1f MiB\n", float64(peakRSS())/(1<<20))
}
