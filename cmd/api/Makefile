build-ApiFunction:
	@echo "Building Go Lambda function for SAM..."
	@echo "Current directory: $$(pwd)"
	@echo "Files in directory: $$(ls -la)"
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bootstrap main.go
	@echo "Bootstrap created: $$(ls -la bootstrap)"
	@echo "Copying bootstrap to artifacts directory..."
	cp bootstrap $(ARTIFACTS_DIR)/bootstrap
	@echo "Files in artifacts directory: $$(ls -la $(ARTIFACTS_DIR)/)"