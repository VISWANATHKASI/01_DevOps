# 1. What is Jenkins?

## 1.1 Introduction

Jenkins is an open-source automation server used to automate software development activities such as building, testing, and deploying applications.

Jenkins is widely used in DevOps to implement Continuous Integration (CI) and Continuous Delivery/Deployment (CD).

### In Simple Words

Jenkins is an automation tool that executes predefined tasks automatically based on configured triggers.

Instead of performing repetitive software development activities manually, we configure Jenkins to perform those activities automatically.

## 1.2 What Is Automation?

Automation means performing tasks automatically without requiring someone to execute every individual step manually.

### Real-World Example

Imagine you are working in a software development company.

Every day, developers write application code and push their changes to a GitHub repository.

Whenever developers make changes, someone needs to:

1. Download the latest source code.
2. Compile the application.
3. Check whether compilation is successful.
4. Execute test cases.
5. Generate build files.
6. Deploy the application to a server.

If these activities are performed manually every day, they consume time and increase the possibility of human errors.

Jenkins helps automate these activities.

## 1.3 What Is the Main Purpose of Jenkins?

The main purpose of Jenkins is to automate repetitive software development and delivery activities.

Jenkins can automate:

- Source code retrieval.
- Application compilation.
- Application building.
- Automated testing.
- Build artifact generation.
- Application deployment.
- Scheduled execution of tasks.

## 1.4 How Does Jenkins Work? (Basic Understanding)

Let's understand Jenkins with a simple example.

Imagine a developer makes changes to an application and pushes the code to GitHub.

Jenkins can be configured to detect these changes and start an automated workflow.

### Basic Jenkins Workflow

```mermaid
flowchart TD
    A[Developer Writes Code] --> B[Push Code to GitHub]
    B --> C[Jenkins Detects Code Changes]
    C --> D[Download Latest Source Code]
    D --> E[Build Application]
    E --> F[Execute Automated Tests]
    F --> G[Generate Build Artifacts]
    G --> H[Deploy Application]
