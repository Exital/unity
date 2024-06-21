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
