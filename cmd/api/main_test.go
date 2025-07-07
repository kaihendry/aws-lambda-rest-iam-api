package main

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/aws/aws-lambda-go/events"
)

func TestHandler(t *testing.T) {
	tests := []struct {
		name           string
		request        events.APIGatewayProxyRequest
		expectedStatus int
	}{
		{
			name: "GET root endpoint",
			request: events.APIGatewayProxyRequest{
				HTTPMethod: "GET",
				Path:       "/",
			},
			expectedStatus: 200,
		},
		{
			name: "GET health endpoint",
			request: events.APIGatewayProxyRequest{
				HTTPMethod: "GET",
				Path:       "/health",
			},
			expectedStatus: 200,
		},
		{
			name: "GET data endpoint",
			request: events.APIGatewayProxyRequest{
				HTTPMethod: "GET",
				Path:       "/data",
			},
			expectedStatus: 200,
		},
		{
			name: "POST data endpoint",
			request: events.APIGatewayProxyRequest{
				HTTPMethod: "POST",
				Path:       "/data",
				Body:       `{"message":"test"}`,
			},
			expectedStatus: 201,
		},
		{
			name: "404 for unknown endpoint",
			request: events.APIGatewayProxyRequest{
				HTTPMethod: "GET",
				Path:       "/unknown",
			},
			expectedStatus: 404,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			response, err := handler(context.Background(), tt.request)
			if err != nil {
				t.Errorf("handler returned error: %v", err)
				return
			}

			if response.StatusCode != tt.expectedStatus {
				t.Errorf("expected status %d, got %d", tt.expectedStatus, response.StatusCode)
			}

			// Verify response body is valid JSON
			var responseData map[string]interface{}
			if err := json.Unmarshal([]byte(response.Body), &responseData); err != nil {
				t.Errorf("response body is not valid JSON: %v", err)
			}
		})
	}
}