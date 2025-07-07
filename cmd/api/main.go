package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type Response struct {
	StatusCode int               `json:"statusCode"`
	Headers    map[string]string `json:"headers"`
	Body       string            `json:"body"`
}

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

func handler(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	log.Printf("Processing request: %s %s", request.HTTPMethod, request.Path)
	
	headers := map[string]string{
		"Content-Type":                "application/json",
		"Access-Control-Allow-Origin": "*",
		"Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
		"Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
	}

	// Handle CORS preflight requests
	if request.HTTPMethod == "OPTIONS" {
		return events.APIGatewayProxyResponse{
			StatusCode: 200,
			Headers:    headers,
			Body:       "",
		}, nil
	}

	var response interface{}
	var statusCode int

	switch request.Path {
	case "/":
		response = DataResponse{
			Message: "Welcome to AWS Lambda REST API with IAM Authentication",
			Method:  request.HTTPMethod,
			Path:    request.Path,
		}
		statusCode = 200

	case "/health":
		response = HealthResponse{
			Status:    "healthy",
			Timestamp: time.Now().UTC().Format(time.RFC3339),
			Message:   "API is running successfully",
		}
		statusCode = 200

	case "/data":
		switch request.HTTPMethod {
		case "GET":
			response = DataResponse{
				Message: "Data retrieved successfully",
				Data: map[string]interface{}{
					"items": []string{"item1", "item2", "item3"},
					"count": 3,
				},
				Method: request.HTTPMethod,
				Path:   request.Path,
			}
			statusCode = 200

		case "POST":
			var requestData map[string]interface{}
			if request.Body != "" {
				if err := json.Unmarshal([]byte(request.Body), &requestData); err != nil {
					response = DataResponse{
						Message: "Invalid JSON in request body",
						Method:  request.HTTPMethod,
						Path:    request.Path,
					}
					statusCode = 400
				} else {
					response = DataResponse{
						Message: "Data received successfully",
						Data:    requestData,
						Method:  request.HTTPMethod,
						Path:    request.Path,
					}
					statusCode = 201
				}
			} else {
				response = DataResponse{
					Message: "No data provided",
					Method:  request.HTTPMethod,
					Path:    request.Path,
				}
				statusCode = 400
			}

		default:
			response = DataResponse{
				Message: fmt.Sprintf("Method %s not allowed", request.HTTPMethod),
				Method:  request.HTTPMethod,
				Path:    request.Path,
			}
			statusCode = 405
		}

	default:
		response = DataResponse{
			Message: "Endpoint not found",
			Method:  request.HTTPMethod,
			Path:    request.Path,
		}
		statusCode = 404
	}

	responseBody, err := json.Marshal(response)
	if err != nil {
		log.Printf("Error marshaling response: %v", err)
		return events.APIGatewayProxyResponse{
			StatusCode: 500,
			Headers:    headers,
			Body:       `{"message":"Internal server error"}`,
		}, nil
	}

	return events.APIGatewayProxyResponse{
		StatusCode: statusCode,
		Headers:    headers,
		Body:       string(responseBody),
	}, nil
}

func main() {
	lambda.Start(handler)
}