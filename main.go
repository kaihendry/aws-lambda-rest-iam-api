package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/apex/gateway"
)

type HealthResponse struct {
	Status    string      `json:"status"`
	Timestamp string      `json:"timestamp"`
	Message   string      `json:"message"`
	Caller    *CallerInfo `json:"caller,omitempty"`
}

type DataResponse struct {
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
	Method  string      `json:"method"`
	Path    string      `json:"path"`
	Caller  *CallerInfo `json:"caller,omitempty"`
}

type CallerInfo struct {
	UserARN     string `json:"user_arn,omitempty"`
	UserID      string `json:"user_id,omitempty"`
	AccountID   string `json:"account_id,omitempty"`
	PrincipalID string `json:"principal_id,omitempty"`
	RoleName    string `json:"role_name,omitempty"`
	SessionName string `json:"session_name,omitempty"`
}

// AWS STS Token structure (simplified)
type STSTokenPayload struct {
	Arn         string `json:"arn"`
	AssumedRole string `json:"assumedRole"`
	SessionName string `json:"sessionName"`
}

// Extract role information from available headers and context
func extractRoleInfo(r *http.Request) (roleName, sessionName string) {
	// Try to get role info from environment variables that might be set by Lambda/API Gateway
	if awsRoleArn := os.Getenv("AWS_EXECUTION_ROLE_ARN"); awsRoleArn != "" {
		if strings.Contains(awsRoleArn, "role/") {
			parts := strings.Split(awsRoleArn, "/")
			if len(parts) > 1 {
				roleName = parts[len(parts)-1] // Get the last part (role name)
				return
			}
		}
	}
	
	// Check various headers that might contain role information
	headers := []string{
		"Authorization",
		"X-Amz-User-Agent", 
		"X-Amzn-RequestContext-Identity-Arn",
		"X-Amzn-RequestContext-Identity-UserArn",
		"X-Amzn-RequestContext-Identity-User",
		"X-Amzn-RequestContext-Identity-PrincipalId",
	}
	
	for _, header := range headers {
		value := r.Header.Get(header)
		if value != "" && len(value) > 10 { // Only log non-trivial headers
			slog.Info("Checking header for role info", "header", header, "value", value[:min(len(value), 100)])
			
			// Look for assumed-role patterns in any header
			if strings.Contains(value, "assumed-role") {
				parts := strings.Split(value, "/")
				for i, part := range parts {
					if part == "assumed-role" && i+1 < len(parts) {
						roleName = parts[i+1]
						if i+2 < len(parts) {
							sessionName = parts[i+2]
						}
						return
					}
				}
			}
			
			// Look for role name patterns
			if strings.Contains(value, "role/") {
				if idx := strings.Index(value, "role/"); idx != -1 {
					remaining := value[idx+5:] // Skip "role/"
					if endIdx := strings.IndexAny(remaining, "/,; "); endIdx != -1 {
						roleName = remaining[:endIdx]
					} else {
						roleName = remaining
					}
					return
				}
			}
		}
	}
	
	// Check if this looks like an STS temporary credential
	if securityToken := r.Header.Get("X-Amz-Security-Token"); securityToken != "" {
		if strings.HasPrefix(securityToken, "IQoJ") {
			// For now, just indicate it's an assumed role
			// We could potentially make an STS GetCallerIdentity call here
			roleName = "STS-AssumedRole"
			
			// Try to get session name from token structure 
			// (this is a simplified approach)
			if len(securityToken) > 100 {
				// Use a portion of the token as session identifier
				sessionName = "session-" + securityToken[50:60]
			}
		}
	}
	
	return
}

// Extract caller information from API Gateway request context headers
func extractCallerInfo(r *http.Request) *CallerInfo {
	caller := &CallerInfo{}
	
	// Extract Request ID as a unique identifier for the request
	if requestID := r.Header.Get("X-Request-Id"); requestID != "" {
		caller.PrincipalID = "Request: " + requestID
	}
	
	// Extract trace ID for correlation
	if traceID := r.Header.Get("X-Amzn-Trace-Id"); traceID != "" && caller.PrincipalID == "" {
		caller.PrincipalID = "Trace: " + traceID
	}
	
	// Extract stage information
	if stage := r.Header.Get("X-Stage"); stage != "" {
		caller.AccountID = "Stage: " + stage
	}
	
	// Determine which API Gateway this request came from by looking at the Host header
	if host := r.Header.Get("Host"); host != "" {
		// Parse out which API Gateway this request came from
		// Note: These IDs will be different after deployment, but logic remains the same
		if strings.Contains(host, "7pxbysogui") {
			caller.UserARN = "API A (Open Access)"
		} else if strings.Contains(host, "cqst45pam7") {
			caller.UserARN = "API B (Restricted Access)"
		} else if strings.Contains(host, "vo9f4c6gj4") {
			caller.UserARN = "API C (IAM + API Key)"
		} else {
			// Check if this request has an API key header (indicates API C)
			if apiKey := r.Header.Get("X-API-Key"); apiKey != "" {
				caller.UserARN = "API C (IAM + API Key)"
			} else {
				caller.UserARN = "API Gateway: " + host
			}
		}
	}
	
	// Check if this request has AWS credentials by looking for security token
	if securityToken := r.Header.Get("X-Amz-Security-Token"); securityToken != "" {
		// Extract role information from request headers
		roleName, sessionName := extractRoleInfo(r)
		if roleName != "" {
			caller.RoleName = roleName
			caller.UserID = "Role: " + roleName
		} else {
			caller.UserID = "Token: " + securityToken[:min(len(securityToken), 20)] + "..."
		}
		
		if sessionName != "" {
			caller.SessionName = sessionName
		}
		
		// If we identified this as API B, it means they used the restricted role
		if strings.Contains(caller.UserARN, "API B") {
			caller.RoleName = "aws-lambda-rest-iam-api-api-b-restricted-role"
			caller.UserID = "Role: aws-lambda-rest-iam-api-api-b-restricted-role"
		}
		
	} else if authHeader := r.Header.Get("Authorization"); authHeader != "" {
		caller.UserID = "Auth: " + authHeader[:min(len(authHeader), 20)] + "..."
	} else {
		if caller.UserARN == "" {
			caller.UserARN = "Unauthenticated Request"
		}
	}

	// Always return caller info since we extract request metadata
	return caller
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func main() {
	mux := http.NewServeMux()

	// Define routes (same endpoints for both APIs)
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
	caller := extractCallerInfo(r)
	slog.Info("Processing request", "method", r.Method, "path", r.URL.Path, "caller", caller)

	response := DataResponse{
		Message: "Welcome to AWS Lambda REST API with IAM Authentication",
		Method:  r.Method,
		Path:    r.URL.Path,
		Caller:  caller,
	}

	writeJSONResponse(w, response, http.StatusOK)
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	caller := extractCallerInfo(r)
	slog.Info("Processing request", "method", r.Method, "path", r.URL.Path, "caller", caller)

	response := HealthResponse{
		Status:    "healthy",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Message:   "API is running successfully",
		Caller:    caller,
	}

	writeJSONResponse(w, response, http.StatusOK)
}

func handleData(w http.ResponseWriter, r *http.Request) {
	caller := extractCallerInfo(r)
	slog.Info("Processing request", "method", r.Method, "path", r.URL.Path, "caller", caller)

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
			Caller: caller,
		}
		writeJSONResponse(w, response, http.StatusOK)

	case http.MethodPost:
		var requestData map[string]interface{}
		if err := json.NewDecoder(r.Body).Decode(&requestData); err != nil {
			response := DataResponse{
				Message: "Invalid JSON in request body",
				Method:  r.Method,
				Path:    r.URL.Path,
				Caller:  caller,
			}
			writeJSONResponse(w, response, http.StatusBadRequest)
			return
		}

		response := DataResponse{
			Message: "Data received successfully",
			Data:    requestData,
			Method:  r.Method,
			Path:    r.URL.Path,
			Caller:  caller,
		}
		writeJSONResponse(w, response, http.StatusCreated)

	default:
		response := DataResponse{
			Message: fmt.Sprintf("Method %s not allowed", r.Method),
			Method:  r.Method,
			Path:    r.URL.Path,
			Caller:  caller,
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
