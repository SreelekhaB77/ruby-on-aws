#!/bin/bash

# Function to deploy resources
deploy() {
    kubectl create secret docker-registry regcred --docker-server=https://index.docker.io/v1/ --docker-username="$DOCKER_USERNAME" --docker-password="$DOCKER_PASSWORD" --docker-email="$DOCKER_EMAIL"
    kubectl create secret generic my-secret --from-env-file=.env-new

    echo "Deploying PostgreSQL..."
    kubectl apply -f deploy/pg-pv.yaml
    kubectl apply -f deploy/pg-deployment.yaml
    kubectl apply -f deploy/pg-service.yaml

    echo "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app=currency-pg --timeout=60s

    echo "Deploying Rails application..."
    kubectl apply -f deploy/app-pv.yaml
    kubectl apply -f deploy/app-deployment.yaml
    kubectl apply -f deploy/app-service.yaml

    echo "Deployment process completed successfully."

    # minikube service currency-app-service
}

# Function to reverse deployment
reverse() {
    echo "Deleting Rails application resources..."
    kubectl delete -f deploy/app-service.yaml
    kubectl delete -f deploy/app-deployment.yaml
    kubectl delete -f deploy/app-pv.yaml

    echo "Waiting for Rails resources to be deleted..."
    sleep 10

    echo "Deleting PostgreSQL resources..."
    kubectl delete -f deploy/pg-service.yaml
    kubectl delete -f deploy/pg-deployment.yaml
    kubectl delete -f deploy/pg-pv.yaml

    echo "Waiting for PostgreSQL resources to be deleted..."
    sleep 10

    echo "Deleting created secrets..."
    kubectl delete secret my-secret
    kubectl delete secret regcred

    echo "Reversal process completed successfully."
}

# Check for command line argument
case "$1" in
    deploy)
        deploy
        ;;
    reverse)
        reverse
        ;;
    *)
        echo "Usage: $0 {deploy|reverse}"
        exit 1
        ;;
esac

