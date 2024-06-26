# Installing [Jenkins](https://www.jenkins.io) on Kubernetes using Helm

Jenkins is an open-source automation server widely used for continuous integration and continuous delivery (CI/CD) pipelines. 
It helps automate the software development processes including building, testing, and deploying applications. 
Jenkins enables developers to integrate changes to their projects continuously, facilitating faster feedback loops and smoother collaboration among team members.

## Prerequisites

Before you begin, ensure you have the following prerequisites set up:

1. **Sealed Secret for Admin Username and Password:**
   - You need a Sealed Secret containing the admin username and password for Jenkins. This secret will be used to access the Jenkins UI and API.

2. **TLS Certificate Sealed Secret:**
   - Obtain a Sealed Secret that contains the TLS certificate and private key for securing the Jenkins HTTPS endpoint.

3. **Persistent Volume Storage Class:**
   - Identify or create a Persistent Volume (PV) Storage Class that Jenkins can use to persist data, such as job configurations and build logs.

## Installation Steps

### Step 1: Add Jenkins Helm Repository

Add the [official Jenkins Helm repository](https://github.com/jenkinsci/helm-charts) to Helm:

```bash
helm repo add jenkins https://charts.jenkins.io
helm repo update
```

### Step 2: Create Jenkins namespace and use Helm
```bash
kubectl create namespace jenkins
helm install jenkins jenkins/jenkins -n jenkins --values jenkins-values.yml
```

```yaml
controller:
  admin: # admin user pre defined username and password
    existingSecret: "jenkins-admin-secret" # the secret name
    userKey: "jenkins-admin-user" # the key in the secret for the user data
    passwordKey: "jenkins-admin-password" # the key in the secret for the password data
  
  installPlugins: # use this to install plugins
    - kubernetes
    - workflow-aggregator
    - git
    - configuration-as-code
    - ws-cleanup
    - job-dsl
    - docker-plugin
    - envinject
    - docker-workflow
    - generic-webhook-trigger

  ingress:
    enabled: true
    hostName: "jenkins.talrozen.com"
    ingressClassName: nginx
    tls:
      - secretName: cloudflare-tls # the tls secret name
        hosts:
          - jenkins.talrozen.com

persistence:
  enabled: true
  storageClass: "nfs-client"
```

## Configuring K8S Docker Agent

In order to configure our Jenkins builds to run on Docker containers using our own images and templates, we first need to build and push an agent Docker image to our Harbor instance. Once the image is available in Harbor, we can configure different pod templates in the `jenkins-values.yml` file for Jenkins.

### Step 1: Configure Docker Group and Docker Socket (Optional if Docker-in-Docker is Not Required)
To enable Docker for Jenkins inside the agent Docker container, follow these steps:

1. Ensure all cluster nodes have the Docker group with the same group ID (GID).
   
   Verify the following on each node:
   ```bash
   getent group docker
   ```
2. Configure the Docker socket (/var/run/docker.sock) with the Docker group having read and write permissions (660 permissions are recommended).
   ```bash
   sudo chown root:docker /var/run/docker.sock
   sudo chmod 660 /var/run/docker.sock
   ```

### Step 2: Build and Push Docker Image

1. **Create a Dockerfile for your Jenkins agent:**

   ```dockerfile
   # Use an official Jenkins JNLP slave image
   FROM jenkins/inbound-agent:latest
   
   # Switch to root user for installation
   USER root
   
   # Install necessary tools
   RUN apt-get update && apt-get install -y \
       apt-transport-https \
       ca-certificates \
       curl \
       gnupg2 \
       software-properties-common
   
   # Install Docker
   RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
   RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
   RUN apt-get update && apt-get install -y docker-ce-cli
   
   # Install Docker Compose
   RUN curl -L "https://github.com/docker/compose/releases/download/1.25.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
       && chmod +x /usr/local/bin/docker-compose
   
   RUN groupadd -g <docker group id on your cluster nodes> docker && usermod -aG docker jenkins
   
   USER jenkins
   ```

2. **Build the Docker image:**

    ```sh
    docker build -f <Dockerfile.agent> -t <harbor_url>/<harbor_project>/<harbor_repo>:<tag>
    ```

3. **Log in to your Harbor instance:**

    ```sh
    docker login <harbor_url>
    ```

4. **Push the Docker image to Harbor:**

    ```sh
    docker push <harbor_url>/<harbor_project>/<harbor_repo>:<tag>
    ```

### Step 2: Configure Jenkins Agent Pull Secret

The agent pull secret is needed to allow the Jenkins agent pods to pull images from a private Docker registry.

1. **Create a Docker Registry Secret in the Jenkins Namespace:**

    Use the following command to create a Docker registry secret in the `jenkins` namespace:

    ```sh
    kubectl create secret docker-registry agent-pull-secret \
      --docker-server=<your-registry-server> \
      --docker-username=<your-username> \
      --docker-password=<your-password> \
      --namespace=jenkins
    ```

    Replace `<your-registry-server>`, `<your-username>` and `<your-password>` with your actual Docker registry credentials.

2. **Export the Secret to a YAML File:**

    To export the created secret to a YAML file, use the following command:

    ```sh
    kubectl get secret agent-pull-secret --namespace=jenkins -o yaml > agent-pull-secret.yaml
    ```

    This command retrieves the `agent-pull-secret` secret from the `jenkins` namespace and saves it to a file named `agent-pull-secret.yaml`.
   
3. **Seal the secret with kubeseal:**
   ```bash
   kubeseal --format yaml < agent-pull-secret.yaml > agent-pull-sealed-secret.yaml
   ```

By following these steps, you create a pull secret that Jenkins agents can use to authenticate with the private Docker registry and pull the necessary images.


### Step 3.: Configure Jenkins Pod Template

1. **Edit your Jenkins Helm values file (`jenkins-values.yml`):**

    ```yaml
   agent:
     podTemplates:
       k8sWithDocker: |
         - name: k8swithdocker
           label: K8S-With-Docker
           serviceAccount: default
           containers:
             - name: jnlp
               image: harbor.talrozen.com/jenkins/docker-agent:1.0.1
               envVars:
                 - envVar:
                     key: "JENKINS_URL"
                     value: "http://jenkins.jenkins.svc.cluster.local:8080/"
           namespace: jenkins
           volumes:
             - hostPathVolume:
                 hostPath: "/var/run/docker.sock"
                 mountPath: "/var/run/docker.sock"
           runAsUser: 1000 # the user id of the jenkins user
           podRetention: "Never"
           slaveConnectTimeout: 100
           imagePullSecrets:
             - name: "agent-pull-secret"
    ```

Check the Jenkins user ID inside the agent container image:

```bash
docker run --rm -it <harbor_url>/<harbor_project>/<harbor_repo>:<tag> /bin/bash
id jenkins
```
The user ID is `uid=<user id>`, and you can also check the Docker group ID configuration you have set up.

3. **Apply the updated Helm chart:**

    ```sh
    helm upgrade jenkins -f jenkins-values.yml
    ```

### Step 3: Create a Jenkins Pipeline

1. **Create a new Jenkins Pipeline job:**

2. **Define the pipeline script:**

    ```groovy
    pipeline {
        agent {
            label 'K8S-With-Docker' # The label of the Jenkins agent configured in the pod template
        }
        stages {
            stage('Hello World') {
                steps {
                    echo 'Hello World'
                }
            }
        }
    }
    ```

3. **Save and run the pipeline.**

By following these steps, you'll be able to configure your Jenkins instance to use custom Docker agents running in Kubernetes. The agents will be based on the images you push to your Harbor instance, and you can easily define and manage different pod templates in your Jenkins Helm values file.

