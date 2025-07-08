package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/apex/gateway/v2"
)

type HealthResponse struct {
	Status    string `json:"status"`
	Timestamp string `json:"timestamp"`
	Message   string `json:"message"`
}

type DataResponse struct {
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
	Method  string      `json:"method"`
	Path    string      `json:"path"`
}

func main() {
	mux := http.NewServeMux()
	
	// Define routes
	mux.HandleFunc("/", handleRoot)
	mux.HandleFunc("/health", handleHealth)
	mux.HandleFunc("/data", handleData)

	var err error
	if _, ok := os.LookupEnv("AWS_LAMBDA_FUNCTION_NAME"); ok {
		err = gateway.ListenAndServe("", mux)
	} else {
		slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, nil)))
		port := os.Getenv("PORT")
		if port == "" {
			port = "8080"
		}
		slog.Info("Starting server", "port", port)
		err = http.ListenAndServe(fmt.Sprintf(":%s", port), mux)
	}
	
	if err != nil {
		slog.Error("Server error", "error", err)
		os.Exit(1)
	}
}

func handleRoot(w http.ResponseWriter, r *http.Request) {
	slog.Info("Processing request", "method", r.Method, "path", r.URL.Path)
	
	response := DataResponse{
		Message: "Welcome to AWS Lambda REST API with IAM Authentication",
		Method:  r.Method,
		Path:    r.URL.Path,
	}
	
	writeJSONResponse(w, response, http.StatusOK)
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	slog.Info("Processing request", "method", r.Method, "path", r.URL.Path)
	
	response := HealthResponse{
		Status:    "healthy",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Message:   "API is running successfully",
	}
	
	writeJSONResponse(w, response, http.StatusOK)
}

func handleData(w http.ResponseWriter, r *http.Request) {
	slog.Info("Processing request", "method", r.Method, "path", r.URL.Path)
	
	switch r.Method {
	case http.MethodGet:
		response := DataResponse{
			Message: "Data retrieved successfully",
			Data: map[string]interface{}{
				"items": []string{"item1", "item2", "item3"},
				"count": 3,
			},
			Method: r.Method,
			Path:   r.URL.Path,
		}
		writeJSONResponse(w, response, http.StatusOK)
		
	case http.MethodPost:
		var requestData map[string]interface{}
		if err := json.NewDecoder(r.Body).Decode(&requestData); err != nil {
			response := DataResponse{
				Message: "Invalid JSON in request body",
				Method:  r.Method,
				Path:    r.URL.Path,
			}
			writeJSONResponse(w, response, http.StatusBadRequest)
			return
		}
		
		response := DataResponse{
			Message: "Data received successfully",
			Data:    requestData,
			Method:  r.Method,
			Path:    r.URL.Path,
		}
		writeJSONResponse(w, response, http.StatusCreated)
		
	default:
		response := DataResponse{
			Message: fmt.Sprintf("Method %s not allowed", r.Method),
			Method:  r.Method,
			Path:    r.URL.Path,
		}
		writeJSONResponse(w, response, http.StatusMethodNotAllowed)
	}
}

func writeJSONResponse(w http.ResponseWriter, data interface{}, statusCode int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	
	if err := json.NewEncoder(w).Encode(data); err != nil {
		slog.Error("Error encoding JSON response", "error", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}