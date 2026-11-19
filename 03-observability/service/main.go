package main

import (
	"encoding/json"
	"log/slog"
	"math/rand/v2"
	"net/http"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type faultConfig struct {
	errorRate float64
	delay     time.Duration
}

var faults atomic.Pointer[faultConfig]

var requests = prometheus.NewCounterVec(prometheus.CounterOpts{
	Name: "http_requests_total",
	Help: "Completed work requests grouped by response class.",
}, []string{"code_class"})

var duration = prometheus.NewHistogram(prometheus.HistogramOpts{
	Name:    "http_request_duration_seconds",
	Help:    "Time spent serving work requests.",
	Buckets: []float64{0.05, 0.1, 0.2, 0.3, 0.5, 1, 2.5},
})

func main() {
	faults.Store(&faultConfig{})
	prometheus.MustRegister(requests, duration)

	publicMux := http.NewServeMux()
	publicMux.HandleFunc("GET /work", work)
	publicMux.HandleFunc("GET /healthz", health)
	publicMux.Handle("GET /metrics", promhttp.Handler())

	adminMux := http.NewServeMux()
	adminMux.HandleFunc("POST /faults", setFaults)

	server := &http.Server{
		Addr:              ":8080",
		Handler:           publicMux,
		ReadHeaderTimeout: 5 * time.Second,
	}
	adminServer := &http.Server{
		Addr:              ":8081",
		Handler:           adminMux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		slog.Info("admin server starting", "addr", adminServer.Addr)
		if err := adminServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("admin server stopped", "error", err)
		}
	}()

	slog.Info("service starting", "addr", server.Addr)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		slog.Error("service stopped", "error", err)
	}
}

func work(w http.ResponseWriter, _ *http.Request) {
	started := time.Now()
	config := faults.Load()
	time.Sleep(time.Duration(20+rand.IntN(61))*time.Millisecond + config.delay)

	if rand.Float64() < config.errorRate {
		requests.WithLabelValues("5xx").Inc()
		http.Error(w, "simulated failure", http.StatusInternalServerError)
		elapsed := time.Since(started)
		duration.Observe(elapsed.Seconds())
		slog.Error("work request failed", "status", http.StatusInternalServerError, "duration_ms", elapsed.Milliseconds())
		return
	}

	requests.WithLabelValues("2xx").Inc()
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok\n"))
	elapsed := time.Since(started)
	duration.Observe(elapsed.Seconds())
	if elapsed > 300*time.Millisecond {
		slog.Warn("work request slow", "status", http.StatusOK, "duration_ms", elapsed.Milliseconds())
	}
}

func health(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok\n"))
}

func setFaults(w http.ResponseWriter, r *http.Request) {
	errorRate, err := strconv.ParseFloat(r.URL.Query().Get("error"), 64)
	if err != nil || errorRate < 0 || errorRate > 1 {
		http.Error(w, "error must be a number from 0 to 1", http.StatusBadRequest)
		return
	}
	delayMS, err := strconv.Atoi(r.URL.Query().Get("delay_ms"))
	if err != nil || delayMS < 0 || delayMS > 10_000 {
		http.Error(w, "delay_ms must be a number from 0 to 10000", http.StatusBadRequest)
		return
	}

	config := &faultConfig{errorRate: errorRate, delay: time.Duration(delayMS) * time.Millisecond}
	faults.Store(config)
	slog.Warn("fault configuration changed", "error_rate", errorRate, "delay_ms", delayMS)
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"error": errorRate, "delay_ms": delayMS})
}
