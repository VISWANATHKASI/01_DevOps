
# 4. Jenkins Architecture

## 4.1 Introduction

In the previous lessons, we understood:

- What Jenkins is.
- Why Jenkins is required.
- How Jenkins automates software delivery.
- What triggers, pipelines, stages, and steps are.

Now, we need to understand how Jenkins actually works internally.

For example, when a developer pushes code to GitHub:

1. How does Jenkins receive the request?
2. Which machine executes the pipeline?
3. Where does Jenkins download the source code?
4. Where does Jenkins execute Linux commands?
5. How does Jenkins manage multiple jobs?
6. How does Jenkins distribute work across multiple machines?

To answer these questions, we need to understand Jenkins Architecture.

## 4.2 What Is Jenkins Architecture?

Jenkins Architecture describes how different components of Jenkins communicate with each other to execute automation tasks.

Jenkins primarily follows a Controller-Agent architecture.

The two major components are:

1. Jenkins Controller
2. Jenkins Agent

The Controller manages Jenkins, schedules jobs, and coordinates execution.

Agents provide execution environments where pipeline steps and jobs can run.

## 4.3 Understanding Jenkins Controller

### 4.3.1 What Is a Jenkins Controller?

The Jenkins Controller is the central component responsible for managing the Jenkins environment.

It acts as the main management server.

Think of the Controller as a manager in an organization.

The manager does not necessarily perform every task personally. Instead, the manager:

- Receives work requests.
- Assigns work.
- Monitors execution.
- Tracks results.
- Manages resources.

Similarly, the Jenkins Controller manages jobs and coordinates their execution.

### 4.3.2 Responsibilities of Jenkins Controller

**1. Managing Jenkins Configuration**

The Controller manages Jenkins configuration, including:

- Jenkins system settings.
- User accounts.
- Security settings.
- Plugins.
- Credentials.
- Job and pipeline configurations.

**2. Receiving Build Requests**

The Controller receives requests to execute jobs.

For example:

- An engineer clicks Build Now.
- GitHub sends a webhook.
- A scheduled trigger activates a job.
- Another Jenkins job triggers a downstream job.

**3. Scheduling Jobs**

The Controller determines when jobs can execute based on scheduling rules and available resources.

**4. Assigning Jobs to Agents**

The Controller selects an eligible agent based on the job's requirements and agent configuration.

**5. Monitoring Execution**

The Controller tracks job execution and receives information about the execution results.

**6. Managing Build Information**

The Controller maintains information such as:

- Build history.
- Build status.
- Pipeline information.
- Execution metadata.
- Configuration data.

### 4.3.3 Where Is the Controller Installed?

In a typical setup, Jenkins is installed on a dedicated server or virtual machine.

For example:

```text
AWS Cloud
    |
    |
    v
EC2 Instance
    |
    v
Jenkins Controller
    |
    |---- Jenkins Web Interface
    |---- Job Management
    |---- Pipeline Scheduling
    |---- Configuration
    |---- Build Coordination
```

In our practical environment, we installed Jenkins on an AWS EC2 instance.

That EC2 instance is currently acting as our Jenkins Controller.

## 4.4 Understanding Jenkins Agent

### 4.4.1 What Is a Jenkins Agent?

A Jenkins Agent is a machine or execution environment that performs the work assigned by the Jenkins Controller.

The Controller manages the work, while the Agent executes the assigned tasks.

For example:

Suppose we have an application that needs to be built using Maven.

The Controller can assign the build to an Agent.

The Agent then:

1. Checks out the application source code.
2. Executes Maven commands.
3. Runs application tests.
4. Generates build artifacts.
5. Reports execution information.

### 4.4.2 Why Do We Need Jenkins Agents?

Imagine a company has 100 developers.

All developers push code multiple times every day.

If every build, test, and deployment task executes on one machine, that machine may become overloaded.

This can cause:

- High CPU utilization.
- High memory consumption.
- Long build execution times.
- Job queue delays.
- Resource contention.

Agents help distribute workloads across multiple execution environments.

### 4.4.3 Responsibilities of Jenkins Agents

Agents can perform tasks such as:

- Checking out source code.
- Executing shell commands.
- Building Java applications.
- Running automated tests.
- Building Docker images.
- Running deployment scripts.
- Generating artifacts.

### 4.4.4 Example of Multiple Agents

Imagine we have three machines:

```text
Machine 1: Jenkins Controller

Machine 2: Jenkins Agent 1
           - Java
           - Maven
           - Linux

Machine 3: Jenkins Agent 2
           - Docker
           - Docker CLI
           - Linux

Machine 4: Jenkins Agent 3
           - Node.js
           - npm
           - Linux
```

The Controller can assign workloads to eligible agents.

For example:

- Java application build → Agent 1.
- Docker-related pipeline → Agent 2.
- Node.js application build → Agent 3.

This allows different workloads to execute in suitable environments.

Important:

An agent must have the tools, permissions, connectivity, and resources required by its assigned workload.

## 4.5 Jenkins Controller-Agent Architecture Diagram

```text
                   Developers
                       |
                       v
                    GitHub
                       |
                       v
              Jenkins Controller
              -------------------
              |                 |
              | Job Management |
              | Scheduling     |
              | Configuration  |
              | Monitoring     |
              |                 |
              -------------------
                  |      |      |
                  |      |      |
             Assign  Assign  Assign
                  |      |      |
                  v      v      v
              Agent 1 Agent 2 Agent 3
              ------- ------- -------
              Java    Docker  Node.js
              Maven   Build   npm
              Tests   Tasks   Tests
```

The Controller coordinates the work, and the Agents execute the assigned tasks.

## 4.6 What Is an Executor in Jenkins?

### 4.6.1 Introduction

An Executor represents an execution slot that allows Jenkins to run a build or task on a node.

A Jenkins node can have one or more executors.

Think of executors as available working slots on a machine.

For example:

If a machine has two executors, it can generally run up to two eligible builds concurrently on that node.

### 4.6.2 Example

Suppose our Jenkins Agent has:

```text
Agent 1

Number of Executors: 2
```

Now, three jobs are submitted:

```text
Job A
Job B
Job C
```

The execution may look like this:

```text
Agent 1

Executor 1 ---> Job A
Executor 2 ---> Job B

Job C ---> Waiting in Queue
```

After Job A or Job B finishes, Job C can be assigned to the available executor, assuming it is otherwise eligible.

### 4.6.3 Why Are Executors Important?

Executors determine how many tasks can run concurrently on a node.

Increasing the number of executors can increase parallel job execution.

However, more executors also increase resource consumption.

For example:

If a machine has:

- 2 CPU cores.
- 4 GB RAM.
- 4 executors.

Running four resource-intensive builds simultaneously may cause performance problems.

Therefore, executor configuration must consider:

- CPU capacity.
- Available RAM.
- Disk space.
- Build requirements.
- Workload characteristics.

Important:

More executors do not automatically mean faster builds.

For resource-intensive builds, fewer executors may provide better performance.

## 4.7 What Is a Jenkins Node?

### 4.7.1 Introduction

A Jenkins Node represents a machine or execution environment that participates in the Jenkins distributed execution system.

A node can be:

- The Jenkins Controller itself.
- A separate Jenkins Agent.

The Controller is also a node.

### 4.7.2 Node vs Agent

These terms are closely related but are not identical.

| Term | Meaning |
|---|---|
| Controller | Central Jenkins management component |
| Node | Machine or environment participating in Jenkins execution |
| Agent | Execution component that runs assigned workloads |
| Executor | Execution slot available on a node |

Remember:

Every agent is associated with a node, but the Controller is also a node.

## 4.8 What Is a Jenkins Workspace?

### 4.8.1 Introduction

A Workspace is a directory on a Jenkins node where Jenkins performs work for a job or pipeline.

For example:

When Jenkins checks out application source code, the files are stored in the workspace.

The workspace may contain:

- Application source code.
- Build scripts.
- Configuration files.
- Generated build files.
- Temporary files.
- Test reports.

### 4.8.2 Workspace Example

Suppose Jenkins is installed on an Ubuntu EC2 instance.

The Jenkins home directory is commonly:

```text
/var/lib/jenkins
```

A job named:

```text
ecommerce-build
```

may have a workspace at:

```text
/var/lib/jenkins/workspace/ecommerce-build
```

Example directory structure:

```text
/var/lib/jenkins/
    |
    |---- jobs/
    |
    |---- workspace/
    |       |
    |       |---- ecommerce-build/
    |       |       |
    |       |       |---- src/
    |       |       |---- pom.xml
    |       |       |---- target/
    |       |
    |       |---- payment-build/
    |
    |---- plugins/
    |
    |---- users/
    |
    |---- secrets/
```

This is an illustrative structure. Actual workspace paths depend on Jenkins configuration and the node where the job executes.

### 4.8.3 Why Is Workspace Important?

The workspace is where pipeline steps interact with application files.

For example:

```bash
pwd
```

Displays the current working directory.

```bash
ls -la
```

Displays the files and directories in the current directory.

```bash
mvn clean package
```

Builds the application using the Maven project files available in the workspace.

### 4.8.4 Does Every Agent Have Its Own Workspace?

Yes.

Each node maintains its own workspace directories for jobs running on that node.

For example:

```text
Controller:
    /var/lib/jenkins/workspace/job-A

Agent 1:
    /home/jenkins/workspace/job-A

Agent 2:
    /home/jenkins/workspace/job-A
```

These are separate directories on separate machines.

The contents are not automatically synchronized between nodes.

If a pipeline executes on Agent 1 and another stage executes on Agent 2, you may need to transfer artifacts explicitly.

We will learn artifact handling and transfer in later lessons.

## 4.9 What Is JENKINS_HOME?

### 4.9.1 Introduction

JENKINS_HOME is the directory where Jenkins stores its important data and configuration.

It is one of the most important directories in a Jenkins installation.

On many Linux installations, the default location is:

```text
/var/lib/jenkins
```

### 4.9.2 What Does JENKINS_HOME Contain?

It commonly contains:

| Directory/File | Purpose |
|---|---|
| config.xml | Main Jenkins configuration |
| jobs/ | Job and pipeline configurations and build-related data |
| plugins/ | Installed Jenkins plugins |
| users/ | User-related information |
| secrets/ | Sensitive Jenkins security data |
| nodes/ | Agent/node configuration data |
| workspace/ | Job workspaces |
| credentials.xml | Stored credential configuration |

The exact contents depend on the Jenkins version, configuration, and installed plugins.

### 4.9.3 Why Is JENKINS_HOME Important?

Imagine our Jenkins EC2 instance crashes.

If we lose the entire JENKINS_HOME directory without a backup, we may lose:

- Job configurations.
- Pipeline configurations.
- Build history.
- Plugin configurations.
- Jenkins system configuration.
- Stored credential data.

Therefore, backing up JENKINS_HOME is an important Jenkins administration responsibility.

Important:

JENKINS_HOME may contain sensitive information. Backups must be protected using appropriate access controls and encryption.

## 4.10 How Controller and Agent Communicate

The Controller and Agent must communicate to coordinate execution.

Jenkins supports different agent connection mechanisms.

One commonly used method is SSH.

### 4.10.1 SSH-Based Agent Connection

In this approach:

1. Jenkins Controller connects to the Agent using SSH.
2. The Agent machine must be accessible through the network.
3. SSH authentication is configured.
4. Jenkins starts its agent process.
5. The Agent connects to the Controller for coordination.

Example architecture:

```text
Jenkins Controller
       |
       | SSH Connection
       |
       v
Jenkins Agent
       |
       v
Execute Pipeline Tasks
```

SSH is commonly used when connecting Linux agents.

### 4.10.2 Other Connection Methods

Jenkins can also use:

- WebSocket-based agent connections.
- Inbound agent connections.
- Cloud-based agent provisioning.

The appropriate method depends on network architecture, infrastructure, and security requirements.

## 4.11 What Happens When Jenkins Executes a Job?

Let's connect all the concepts.

Imagine a developer pushes code to GitHub.

The execution process looks like this:

**Step 1: Trigger**

GitHub sends a webhook notification to Jenkins.

**Step 2: Controller Receives Request**

The Jenkins Controller receives the build request.

**Step 3: Job Scheduling**

Jenkins places the job in the queue and determines when it can execute.

**Step 4: Agent Selection**

Jenkins selects an eligible execution node.

**Step 5: Executor Allocation**

An available executor is allocated for the work.

**Step 6: Workspace Preparation**

Jenkins prepares the job workspace.

**Step 7: Pipeline Execution**

The pipeline executes its configured stages and steps.

**Step 8: Result Reporting**

Execution results and relevant information are recorded by Jenkins.

Diagram:

```text
GitHub Push
     |
     v
Webhook
     |
     v
Jenkins Controller
     |
     v
Job Queue
     |
     v
Agent Selection
     |
     v
Executor Allocation
     |
     v
Workspace Preparation
     |
     v
Pipeline Execution
     |
     v
Build Result
```

## 4.12 Real-Time DevOps Architecture Example

Imagine an organization running several application projects.

The organization has:

- One Jenkins Controller.
- Three Jenkins Agents.
- Multiple GitHub repositories.
- Java, Node.js, and Docker workloads.

Architecture:

```text
                  GitHub
                     |
                     v
            Jenkins Controller
                     |
          -------------------------
          |           |           |
          v           v           v
       Agent 1     Agent 2     Agent 3
       Java        Node.js     Docker
       Maven       npm         Docker CLI
          |           |           |
          v           v           v
       Java App   Node App    Docker Image
          |           |           |
          v           v           v
       Deployment Targets / Environments
```

Benefits:

1. Workloads can be distributed across multiple machines.
2. Different agents can provide different tool environments.
3. Multiple jobs can execute concurrently.
4. The Controller manages jobs centrally.
5. Workloads can be scaled by adding suitable agents.

## 4.13 Important Jenkins Architecture Concepts

| Component | Responsibility |
|---|---|
| Controller | Manages Jenkins and coordinates execution |
| Agent | Executes assigned workloads |
| Node | Represents a Jenkins execution machine/environment |
| Executor | Provides an execution slot |
| Workspace | Stores files used during job execution |
| JENKINS_HOME | Stores Jenkins configuration and operational data |
| Job Queue | Holds jobs waiting for execution |
| Pipeline | Defines the automation workflow |

## 4.14 Lesson Summary

In this lesson, we understood Jenkins architecture and its major components.

We covered:

1. Jenkins Controller.
2. Jenkins Agent.
3. Controller-Agent architecture.
4. Executors.
5. Nodes.
6. Workspaces.
7. JENKINS_HOME.
8. Controller-Agent communication.
9. Job scheduling and execution.
10. Real-time DevOps architecture.

The most important concept:

**The Jenkins Controller manages and coordinates execution, while Jenkins Agents provide execution environments for running workloads. Executors determine how many builds can run concurrently on a node.**

## 4.15 Interview Questions

**Q1. What is Jenkins Controller?**

The Jenkins Controller is the central management component responsible for managing configurations, scheduling jobs, and coordinating execution.

**Q2. What is a Jenkins Agent?**

A Jenkins Agent is an execution environment that performs tasks assigned by the Controller.

**Q3. What is an Executor?**

An Executor is an execution slot that allows Jenkins to run a build or task on a node.

**Q4. What is a Jenkins Node?**

A Node is a machine or environment participating in the Jenkins execution system. Both the Controller and Agents are nodes.

**Q5. What is a Workspace?**

A Workspace is the directory where Jenkins checks out source code and performs job-related activities.

**Q6. What is JENKINS_HOME?**

JENKINS_HOME is the directory where Jenkins stores its configuration, job data, plugins, credentials-related data, and other operational information.

**Q7. Can Jenkins execute multiple jobs simultaneously?**

Yes. Jenkins can execute multiple jobs concurrently depending on executor availability, resource capacity, and job restrictions.

**Q8. Can we use the Controller to execute jobs?**

Yes. The Controller can execute jobs, but using dedicated Agents for build workloads is generally recommended in production environments.

**Q9. What happens when all Executors are busy?**

New eligible jobs wait in the queue until an executor becomes available.

**Q10. Why do we need multiple Agents?**

Multiple Agents help distribute workloads, provide different execution environments, and improve scalability.

---

**End of Lesson 04**
