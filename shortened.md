## Deploying a Ruby on Rails API-Only Application using Kubernetes and Docker to Amazon Elastic Kubernetes Services

Author: Mba Uchenna

This report provides a comprehensive walkthrough for deploying a Rails API-only application using Docker and Kubernetes to EKS. I will cover the process of implementing a rails application that converts currency for a user based on the currency parameters passed. I will also containerize the application with Docker, creating a Kubernetes configuration file, and deploying the application. This setup is ideal for a Rails application that relies on a database service like postgres.

## The Application

The application to be deployed is a currency converter `api-only` application. This means that the application will take a `REST` request and return a `JSON` response. To develop this application, I started with creating a rails application with the command:

```sh
rails new currency_converter --api -d postgresql
```

This commands bootstraps the application with basic configuration to use `postgresql` as the preferred database.

Since the application is a currency converter application, created an `user accounts` table in the database, so users can `register`, or `login`, to get an authentication `token`. Token generation is handled by [`jwt`](https://jwt.io/) (JSON Web Tokens are an open, industry standard RFC 7519 method for representing claims securely between two parties) a popular token generator, and then this token is used as an authentication token in the header of all following requests to convert a currency pair.

As the focus of this report is on the deployment to a cloud service, I would not go into details of how the two functions above work.

For this application, I implemented an API provided by [freecurrencyapi.com](https://freecurrencyapi.com). On this application, sending a `POST` request, with a `base_currency` and a `target_currency` would provide a response like:

The application has been uploaded to a github repository for further inspection and also the endpoints samples are available [here](https://documenter.getpostman.com/view/18554619/2s9YeEbBkB)

![POST MAN SAMPLE REQUEST](https://awa-apps.fra1.cdn.digitaloceanspaces.com/uploads/Screenshot%202023-11-27%20at%204.26.51%E2%80%AFAM.png "Post Man Sample Request")

# The Deployment

**What you need:**

- **[Docker](https://docs.docker.com/get-docker/)**: Docker is essential for creating and managing application containers. Install Docker from its official website.
- **[Kubernetes](https://minikube.sigs.k8s.io/docs/start/)**: An open-source system for automating deployment, scaling, and management of containerized applications.
- **[Minikube](https://minikube.sigs.k8s.io/docs/start/)**: is recommended for setting up a local Kubernetes cluster.

## Step-by-Step Guide

### 1. Dockerizing the Rails Application

**Create a `Dockerfile`**

A Dockerfile is a script containing commands to assemble a Docker image for an application. The Dockerfile will outline the necessary steps to prepare the application environment.

I created a file named `Dockerfile` without any extensions and add it to the root of the rails application. The final file looks like this:

```Docker
FROM ruby:3.2.1

RUN apt-get update -qq && \
    apt-get install -y build-essential libvips bash bash-completion libffi-dev tzdata postgresql nodejs npm yarn && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

WORKDIR /rails

ENV RAILS_LOG_TO_STDOUT="1" \
    RAILS_SERVE_STATIC_FILES="true" \
    RAILS_ENV="production" \
    BUNDLE_WITHOUT="development"

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN chmod +x /rails/bin/docker-entrypoint.sh

# commands that run everytime during build
ENTRYPOINT ["/rails/bin/docker-entrypoint.sh"]

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
```

The purpose of this Dockerfile is to define in details and step how an image is built, in this case, we are building an image for a ruby application, we require the official `ruby image` with tag `3.2.1` and installed all other dependencies required for the application to run.

### 2. Kubernetes Configurations

**What you need**

To deploy an application or service to kubernetes, you need to first understand what components it depends on to run completely. For kubernetes setup, a few configurations are needed. A `persistent volume` which contains data that should be persistent across multiple instances of the application running on countless machines; A `deployment` configuration that defines how an application should be deployed, from what `image`, how many `CPUs`, `memory`, `replicas`, etc; a `service` configuration that defines how a deployment should be accessed, amongst other configurations. I have covered a few that are necessary for this application's deployment in this report.

- Deployment configuration - defines how to deploy a containerized application.
- Service Configuration - maps a deployment to a service name and port, allowing the application to be accessed
- Persistent Volume Storage - used for data that should persist across restarts and deployments of the cluster. They are particularly important for stateful applications like databases.
- ConfigMap - to store non-confidential data in key-value pairs. ConfigMaps can be used to store settings, configuration files, and other non-sensitive data required by pods.
- Secrets - intended for sensitive data like passwords, tokens, or keys.

Before configuring the application for kubernetes, minikube and kubectl should be installed on the machine(macOS is assumed in this case)

```zsh
$ brew install minikube
```

After installing minikube, `minikube kubectl` command will be available, but to make life easier, create an alias

```sh
alias kubectl="minikube kubectl --"
```

Now `kubectl` and `minikube` is available and can be used in the following instructions below.

## Deploying a rails application to kubernetes

Deploying the rails application to kubernetes requires, creating the components highlighted above for all the services that the application depends on like `rails application`, `postgres`, `redis`, `sidekiq`, etc. For the purpose of this implementation, the application would require a `rails` application deployment and the `postgres` deployment as in our docker-compose setup.

At this stage, it is assumed that the Docker `image` has been built successfully and pushed to the DockerHub registry. Kubernetes will attempt to pull the image from the official registry, using the driver that is specified.

### The Rails application configuration

Docker credentials is needed to authorize kubernetes pull requests as the deployment configuration would be pulling the image from the official DockerHub registry. Hence, run the following command (replace `<username>`, `<password>` and `<docker-email>`) to add these credentials to kubernetes.

```sh
kubectl create secret docker-registry regcred --docker-server=https://index.docker.io/v1/--docker-username=<username> --docker-password=<Password> --docker-email=<docker-email>
```

This command would create a kubernetes secret with the name `regcred` that would be referenced by the deployments. Also, environment variables can be created from an existing `.env` file to avoid manually converting all the environment variables into base64 encoded values and adding them to a `secret.yaml` configuration file. Run the following command to generate a kubernetes secret.

```sh
kubectl create secret generic my-secret --from-env-file=.env-new
```

This would create a kubernetes secret with the name `my-secret` from the `.env-new` file available in the rails application. Here is an example of the .env file:

```ruby
RAILS_ENV=production
POSTGRES_HOST=db
```

Create a a file to configure the application persistent storage `app-pv.yaml`

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: currency-app-pv
spec:
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  storageClassName: standard
  hostPath:
    path: /rails/storage
    type: DirectoryOrCreate
```

The `metadata.name` property specifies the name of the volume to be created for our rails application. `spec.hostPath` specifies the path to the directory where our application data will be stored. Please refer to the kubernetes document for more information about each of these properties.

Next, Create a file `app-deployment.yaml` that contains the configuration for the deployment of the application.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: currency-app # sets the name of the deployment
spec:
  replicas: 1 # defines the number of replicas per node
  selector:
    matchLabels:
      app: currency-app # defines which pod the deployment is for
  template: # defines a  template for each replica
    metadata:
      labels:
        app: currency-app # defines the label to be applied to pods created from this deployment
    spec:
      containers:
        - name: currency-app # defines the name of the container within each pod
          image: urchymanny/currency-converter:v3 # Image from which the container is created (usually from a registry)
          envFrom:
            - secretRef:
                name: my-secret # using the secret created from our .env file
          resources:
            limits:
              memory: "128Mi"
              cpu: "200m"
          ports:
            - containerPort: 3000
          volumeMounts:
            - mountPath: /rails/storage
              name: currency-app-pv # name of the persistent volume to be mounted for the container
      restartPolicy: Always
      imagePullSecrets:
        - name: regcred # using the secret created from our registry credentials
      volumes:
        - name: currency-app-pv
          persistentVolumeClaim:
            claimName: currency-app-pvc
```

Eventually creating a service for the container will be the last necessary step `app-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: currency-app-service # Sets the name of the Service
spec:
  selector:
    app: currency-app # Maps this service to a pod with a matching label
  ports:
    - protocol: TCP # Specifies the protocol used by the service (TCP/UDP)
      port: 3000 # The port on which the service will be exposed
      targetPort: 3000 # The port on the pod to which this service will forward traffic
      nodePort: 30000
  type: LoadBalancer # The type of service, LoadBalancer exposes the service externally
```

The most important property in the service is the `selector.app` which maps the created service to a pod with the same label.

In **conclusion**, A `deployment` was configured to run a single (1) `replica` of a `pod` that would be built from the `image` specified. Then a `service` is created for the `pod` with a `port` and `targetPort`.

### The Postgres Database configuration

Following the configuration of the rails application, the configuration for the database is going to be quite easy.
The needed components are more or less the same; a `deployment`, `service`, `persistent storage` and `persistent storage claim`. Code below shows the implementation for the postgres database service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: currency-pg-service
spec:
  selector:
    app: currency-pg
  ports:
    - protocol: TCP
      port: 5432
      targetPort: 5432
```

At this point, the rails application and a postgres database have been successfully configured for kubernetes, however we still need to configure the database to depend on the database service that is deployed by `pg-deployment.yaml`. This is relatively easy to do, just edit the rails application `config/database.yml` file to have the following:

```yml
...

production:
  ...
  host: currency-db # as the database host would be the service created.
  ...
```

The host of the production database would be the postgres service configured by `pg-service.yaml` that was created.

The application is ready to be deployed to kubernetes. The following command uses kubectl to apply the configurations to kubernetes `minikube` cluster.

```sh
kubectl apply -f <folder>

```

Assuming that all the configuration `yaml` files are in a folder named `/deploy/`, the command above will apply all configuration files to kubernetes.

However, This can be redundant, so a `.sh` script can me made to automatically execute the application of the configuration and removal of all configuration.

```sh
#!/bin/bash

deploy() {
    kubectl create secret docker-registry regcred --docker-server=https://index.docker.io/v1/ --docker-username="$DOCKER_USERNAME" --docker-password="$DOCKER_PASSWORD" --docker-email="$DOCKER_EMAIL"
    kubectl create secret generic my-secret --from-env-file=.env-new

    kubectl apply -f deploy

    echo "Deployment process completed successfully."

    # minikube service currency-app-service
}

# Function to reverse deployment
reverse() {
     kubectl delete -f deploy

    echo "Deleting created secrets..."
    kubectl delete secret my-secret
    kubectl delete secret regcred

    echo "Reversal process completed successfully."
}

```

This script can be saved in the root directory of the rails application

- Make sure docker is installed and running before running this script
- Start minikube before running this script

  ```sh
    minikube start
  ```

  To run the executable `deploy.sh`, permissions must be given to the file first.

  ```sh
  $ run chmod +x deploy.sh
  $ ./deploy.sh deploy
  ```

  The result of running the script above will be something similar to the table below

  ```sh
  |-----------|---------|-------------|---------------------------|
  | NAMESPACE | NAME    | TARGET PORT | URL                       |
  | --------- | ------- | ----------- | ------------------------- |
  | default   | ead-app | 3000        | http://192.168.49.2:30582 |
  |-----------|---------|-------------|---------------------------|
  🏃 Starting tunnel for service ead-app.
  |-----------|---------|-------------|---------------------------|
  | NAMESPACE | NAME    | TARGET PORT | URL                       |
  | --------- | ------- | ----------- | ------------------------- |
  | default   | ead-app |             | http://127.0.0.1:51975    |
  |-----------|---------|-------------|---------------------------|
  ```

  This shows us the IP address and port which our application is externally available from, in the example above, this address is `http://127.0.0.1:51975`

# Conclusion: Deploying Applications with Docker and Kubernetes

Deploying an application using Docker and Kubernetes involves a series of systematic steps to ensure a smooth and efficient process. This process can be summarized as follows:

1. **Create a Docker Image**: The initial step involves creating a Docker image for your application. This image encapsulates the application, its dependencies, and the runtime environment, ensuring consistency across various deployment stages.

2. **Prepare Kubernetes Configuration Files**: Once the Docker image is ready, the next step is to prepare a set of Kubernetes configuration files. These files define how your application should be deployed, managed, and scaled in a Kubernetes cluster. Key configurations include:

   - **Deployment**: Specifies how the application's containers should be run and managed.
   - **Service**: Defines how to expose the application (or a part of it) to the network, potentially making it accessible from outside the Kubernetes cluster.
   - **Persistent Volumes and Claims**: Ensure that data persists across container restarts and re-deployments.
   - **ConfigMaps and Secrets**: Manage configuration data and sensitive information securely.

3. **Apply Configurations to the Kubernetes Cluster**: With the configuration files ready, the next step is to apply them to your Kubernetes cluster. This step creates the necessary Kubernetes resources (like Deployments, Services, etc.) and starts the process of deploying your application within the cluster.

4. **Expose the Application to External Clients**: Finally, the application is made accessible to external clients. This is typically achieved through a Kubernetes Service of the type `LoadBalancer` or `NodePort`, which routes external traffic to the correct pods within the cluster.

In summary, deploying an application with Docker and Kubernetes requires careful planning and execution, involving image creation, configuration file preparation, application of these configurations to a Kubernetes cluster, and exposure of the application to the external world. This process ensures a scalable, manageable, and efficient deployment, leveraging the strengths of containerization and orchestration.

# Deploying the configuration to an EKS cluster

Once the configuration has been tested and deployed successfully in the minikube local cluster, we are sure that the application would run on any cluster or group of clusters. This makes it easy for us to deploy the applications to a kubernetes cluster on the cloud on a managed service like Amazon Elastic Kubernetes Service.

First, we need to add our aws account credentials to our local machine to be able to access aws cli commands from our shell. to do that, run the following commands

```sh
set AWS_ACCESS_KEY_ID <YOUR ACCESS KEY>
set AWS_SECRET_ACCESS_KEY <YOUR SECRET ACCESS KEY>
```

The command above adds your aws keys to your environment variables available to your shell. Next, install `eksctl` which is the official Amazon EKS command line tool. This tool speeds up the process of creating clusters by automating the creation of ECS and other requirements like a VPC needed to create a cluster.

By running the following command, a cluster will be created with the arguments passed:

```sh
eksctl create cluster \
--name currency-app-cluster \ # name of the cluster
--version 1.28 \
--region eu-west-2 \ # which represents London
--nodegroup-name linux-nodes \
--node-type t2.micro \ # free tier ec2 instances to be created
--nodes 2
```

This takes about 15 minutes to create all the nodes and services on my AWS account that are required to deploy the application.

Lastly, The application can be deployed to aws using the `deploy.sh` script used to deploy the application locally as now the kubernetes is connected to the EKS profile provisioned by aws credentials.

```sh
./deploy.sh deploy
```

Following this command, the application will be deployed to aws. as seen below.

![Deployments](https://awa-apps.fra1.cdn.digitaloceanspaces.com/uploads/Screenshot%202023-11-27%20at%204.17.09%E2%80%AFAM.png "Deployments")

Two pods are created representing individual replicas of both the application template and the database template.
![Pods](https://awa-apps.fra1.cdn.digitaloceanspaces.com/uploads/Screenshot%202023-11-27%20at%204.16.23%E2%80%AFAM.png "Active Pods")
The service that acts as an access point for the application is also created. with the names defined in the `-service.yaml` files.
![Services](https://awa-apps.fra1.cdn.digitaloceanspaces.com/uploads/Screenshot%202023-11-27%20at%204.16.44%E2%80%AFAM.png "Services")

Secrets generated from our `.env` files are also added to EKS
![Secrets](https://awa-apps.fra1.cdn.digitaloceanspaces.com/uploads/Screenshot%202023-11-27%20at%204.16.52%E2%80%AFAM.png "Secrets")
Lastly, our persistent volumes is also created.
![Persistent Volumes](https://awa-apps.fra1.cdn.digitaloceanspaces.com/uploads/Screenshot%202023-11-27%20at%204.16.59%E2%80%AFAM.png "Persistent Volumes")
