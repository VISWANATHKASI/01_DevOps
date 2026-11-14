
# 3. How Does Jenkins Solve This Problem?

## 3.1 Introduction

In the previous lessons, we understood:

- What Jenkins is.
- Why Jenkins is required.
- What problems developers and operations teams face during software delivery.

Now, let's understand exactly how Jenkins solves these problems.

To understand Jenkins properly, we first need to understand how software is delivered manually and how the same process works with automation.

Jenkins automates repetitive software development and delivery activities.

Instead of developers or operations engineers manually performing every activity, Jenkins can execute these activities automatically based on predefined instructions.

For example:

1. A developer writes application code.
2. The developer pushes the code to GitHub.
3. Jenkins detects the new code.
4. Jenkins downloads the latest source code.
5. Jenkins builds the application.
6. Jenkins executes automated tests.
7. Jenkins packages the application.
8. Jenkins deploys the application to the target environment.

This entire sequence can be automated using Jenkins.

Before understanding the automated workflow, let's understand the manual workflow.

---

## 3.2 Understanding the Manual Software Delivery Workflow

### 3.2.1 What Is a Manual Workflow?

A manual workflow means developers and operations engineers perform software development and delivery activities themselves instead of relying on an automation tool.

Let's consider a real-time example.

Imagine a company developing an e-commerce application.

The development team makes changes to the application and needs to deliver those changes to a testing environment.

Without Jenkins, the team might perform the following activities manually.

### 3.2.2 Manual Workflow - Step by Step

**Step 1: Developer Writes Application Code**

A developer makes changes to the application.

For example:

- Adding a new login feature.
- Fixing an existing application bug.
- Updating payment functionality.
- Improving application performance.

The developer tests the changes locally.

**Step 2: Developer Pushes Code to GitHub**

After completing the changes, the developer pushes the code to a Git repository.

Example:

```bash
git add .
git commit -m "Added login functionality"
git push origin main
```

Why do we use these commands?

- `git add .` - Stages modified files for the next commit.
- `git commit` - Creates a commit containing the staged changes.
- `git push` - Uploads the commits to the remote repository.

At this point, the latest application code is available in GitHub.

However, pushing code to GitHub does not automatically mean that the application has been built, tested, or deployed.

**Step 3: Operations Engineer Downloads the Code**

The operations engineer connects to the build server and downloads the latest application code.

Example:

```bash
git clone https://github.com/company/ecommerce-app.git
```

If the repository already exists on the server:

```bash
cd ecommerce-app
git pull origin main
```

Why do we use these commands?

- `git clone` downloads a repository for the first time.
- `git pull` downloads and integrates the latest remote changes into the current local branch.

**Step 4: Build the Application**

The engineer manually executes the build command.

For a Maven-based Java application:

```bash
mvn clean package
```

What does this command do?

- `mvn` invokes Maven.
- `clean` removes previously generated build files.
- `package` compiles the application, runs applicable tests, and packages the application.

The generated application artifact might be:

```text
target/ecommerce-app.war
```

**Step 5: Execute Application Tests**

The engineer executes the test cases.

For Maven:

```bash
mvn test
```

This command executes the configured automated tests.

If tests fail, the engineer must investigate the errors and fix the issues.

**Step 6: Package the Application**

After successful testing, the application package is prepared for deployment.

For example:

```text
ecommerce-app.war
```

This file contains the packaged Java web application.

**Step 7: Deploy the Application**

The engineer manually copies the application package to the application server.

For example:

```bash
scp target/ecommerce-app.war ec2-user@SERVER_IP:/opt/tomcat/webapps/
```

This command securely copies the WAR file to the remote server.

**Step 8: Verify the Application**

Finally, the engineer checks whether the application is running correctly.

Verification may include:

- Checking application logs.
- Checking server status.
- Accessing the application URL.
- Performing basic functional testing.

### 3.2.3 Manual Workflow Diagram

```text
Developer Writes Code
          |
          v
Developer Pushes Code
          |
          v
      GitHub
          |
          v
Engineer Connects to Server
          |
          v
Downloads Latest Code
          |
          v
Builds Application
          |
          v
Executes Tests
          |
          v
Packages Application
          |
          v
Deploys Application
          |
          v
Verifies Application
```

### 3.2.4 Problems with the Manual Workflow

The manual workflow works, but it introduces several challenges.

**1. Time Consumption**

Engineers must repeat the same commands whenever new code is delivered.

**2. Human Errors**

An engineer might:

- Execute the wrong command.
- Download the wrong branch.
- Forget to execute tests.
- Deploy an outdated package.
- Copy files to the wrong server.

**3. Dependency on Engineers**

Software delivery depends on engineers being available to perform the activities.

**4. Lack of Consistency**

Different engineers might follow different procedures.

**5. Difficult to Scale**

Imagine 50 developers pushing code multiple times every day.

Performing every build, test, and deployment manually becomes difficult.

**6. Delayed Feedback**

Developers might discover application errors only after an engineer manually executes the build and testing process.

These are the problems Jenkins helps solve.

---

## 3.3 Understanding the Automated Workflow

### 3.3.1 What Is an Automated Workflow?

An automated workflow means repetitive software development and delivery activities are executed automatically using predefined instructions.

Jenkins acts as the automation server.

We configure Jenkins to perform tasks such as:

- Downloading source code.
- Building applications.
- Running automated tests.
- Packaging applications.
- Deploying applications.
- Sending notifications.

Once configured, Jenkins can execute these tasks whenever a configured trigger occurs.

### 3.3.2 Automated Workflow - Step by Step

Let's use the same e-commerce application example.

**Step 1: Developer Writes Application Code**

The developer modifies the application and completes the required changes.

**Step 2: Developer Pushes Code to GitHub**

The developer pushes the changes to the Git repository.

Example:

```bash
git add .
git commit -m "Added login functionality"
git push origin main
```

**Step 3: Jenkins Detects the Changes**

Jenkins detects that new code has been pushed to GitHub.

This can happen through:

- Webhooks.
- Poll SCM.
- Scheduled execution.
- Manual triggering.

We will study these triggers in detail later in this lesson.

**Step 4: Jenkins Downloads Source Code**

Jenkins checks out the required source code from GitHub.

For example:

```bash
git clone https://github.com/company/ecommerce-app.git
```

In a real Jenkins pipeline, source code checkout is normally configured through Jenkins pipeline steps and Git integration.

**Step 5: Jenkins Builds the Application**

Jenkins executes the configured build command.

For example:

```bash
mvn clean package
```

If the build fails, Jenkins marks the build as failed.

**Step 6: Jenkins Executes Automated Tests**

Jenkins executes the configured test command.

For example:

```bash
mvn test
```

If the tests fail, Jenkins can stop subsequent stages.

**Step 7: Jenkins Packages the Application**

Jenkins makes the application artifact available for subsequent pipeline stages.

For example:

```text
target/ecommerce-app.war
```

**Step 8: Jenkins Deploys the Application**

If the required conditions are satisfied, Jenkins deploys the application to the configured environment.

For example:

```bash
scp target/ecommerce-app.war ec2-user@SERVER_IP:/opt/tomcat/webapps/
```

**Step 9: Jenkins Reports the Result**

Jenkins records the execution result.

For example:

- SUCCESS
- FAILURE
- UNSTABLE
- ABORTED

Jenkins can also send notifications through configured integrations.

### 3.3.3 Automated Workflow Diagram

```text
Developer Writes Code
          |
          v
Developer Pushes Code
          |
          v
       GitHub
          |
          | Webhook / Poll SCM
          v
        Jenkins
          |
          v
    Checkout Source Code
          |
          v
      Build Application
          |
          v
     Execute Tests
          |
          v
    Package Application
          |
          v
    Deploy Application
          |
          v
   Verify Deployment
          |
          v
   Report Execution Result
```

### 3.3.4 Manual vs Automated Workflow

| Activity | Manual Workflow | Automated Workflow |
|---|---|---|
| Code management | Developer uses Git | Developer uses Git |
| Code retrieval | Engineer downloads code | Jenkins checks out code |
| Build | Engineer executes command | Jenkins executes command |
| Testing | Engineer executes tests | Jenkins executes tests |
| Packaging | Engineer prepares package | Jenkins prepares package |
| Deployment | Engineer deploys manually | Jenkins executes deployment steps |
| Execution tracking | Manual tracking | Jenkins records results |
| Notifications | Manual communication | Automated notifications can be configured |

**Important:**

Jenkins does not eliminate the need for engineers.

Engineers still write code, configure pipelines, maintain infrastructure, investigate failures, and make deployment decisions.

Jenkins automates the repetitive execution of predefined activities.

---

## 3.4 How Does Jenkins Know When to Start Execution?

This is one of the most important concepts in Jenkins.

Jenkins does not necessarily execute a pipeline continuously.

It executes a job or pipeline when a configured trigger or an authorized manual action starts it.

### 3.4.1 What Is a Trigger?

A trigger is an event or condition that tells Jenkins to start a job or pipeline.

In simple terms:

A trigger answers the question:

**When should Jenkins start executing the pipeline?**

For example:

- Whenever a developer pushes code to GitHub.
- Every five minutes.
- Every day at midnight.
- When an engineer clicks Build Now.
- When another Jenkins job completes.

Jenkins supports different triggering mechanisms.

### 3.4.2 Types of Jenkins Triggers

**1. Manual Trigger**

An engineer manually starts a Jenkins job.

Example:

1. Open the Jenkins dashboard.
2. Select the required job.
3. Click Build Now.
4. Jenkins starts executing the job.

When do we use it?

- Testing a newly created pipeline.
- Running a deployment manually.
- Performing maintenance activities.
- Executing a one-time task.

**2. Poll SCM Trigger**

Jenkins periodically checks the source code repository for changes.

For example:

```text
H/5 * * * *
```

This is a Jenkins cron-style schedule.

It tells Jenkins to check the repository approximately every five minutes, with a hashed minute offset.

If Jenkins detects changes, it can start a build.

When do we use it?

- When repository webhooks are unavailable.
- When periodic repository checks are required.

Important:

Poll SCM checks the repository periodically. It is different from a normal scheduled build.

**3. Webhook Trigger**

A webhook is a notification sent by an external application to another application when a particular event occurs.

For example:

1. Developer pushes code to GitHub.
2. GitHub sends an HTTP notification to Jenkins.
3. Jenkins receives the notification.
4. Jenkins starts the configured pipeline.

This avoids waiting for Jenkins to periodically check the repository.

When do we use it?

- GitHub-to-Jenkins integration.
- GitLab-to-Jenkins integration.
- Event-driven CI/CD pipelines.

**4. Scheduled Trigger**

Jenkins executes a job according to a predefined schedule.

Example:

```text
H 2 * * *
```

This schedules the job approximately once per day around 2 AM.

When do we use it?

- Nightly builds.
- Daily regression tests.
- Scheduled maintenance jobs.
- Periodic reports.

**5. Upstream Trigger**

A Jenkins job can start another Jenkins job after successful completion.

Example:

```text
Job A: Build Application
          |
          v
Job B: Run Tests
          |
          v
Job C: Deploy Application
```

When do we use it?

- Coordinating multiple Jenkins jobs.
- Separating large workflows into smaller jobs.
- Creating dependent job execution.

**Important distinction:**

A trigger starts a job or pipeline. It does not itself perform the build, testing, or deployment activities.

---

## 3.5 Understanding Jenkins Pipeline Execution Stages

Now that we understand how Jenkins starts execution, let's understand what happens after execution begins.

### 3.5.1 What Is a Pipeline?

A Jenkins Pipeline is a defined sequence of automated steps used to build, test, and deliver an application.

A pipeline describes:

- What activities Jenkins must perform.
- In which order they must execute.
- Which conditions must be satisfied.
- What should happen when a step succeeds or fails.

Jenkins Pipelines are commonly written using a file named:

```text
Jenkinsfile
```

This file is generally maintained inside the application's Git repository.

### 3.5.2 What Is a Stage?

A stage is a logical section of a Jenkins Pipeline.

For example:

- Checkout
- Build
- Test
- Package
- Deploy

Each stage represents a particular phase of the software delivery process.

A stage can contain one or more steps.

### 3.5.3 What Is a Step?

A step is an individual operation performed by Jenkins.

For example:

```groovy
sh 'mvn clean package'
```

This is a step that executes a shell command on a suitable agent.

Another example:

```groovy
sh 'mvn test'
```

This step executes application tests.

### 3.5.4 Understanding the Relationship

```text
Jenkins Pipeline
       |
       |---- Stage 1: Checkout
       |         |
       |         |---- Step: Download Source Code
       |
       |---- Stage 2: Build
       |         |
       |         |---- Step: Execute Maven Build
       |
       |---- Stage 3: Test
       |         |
       |         |---- Step: Execute Test Cases
       |
       |---- Stage 4: Package
       |         |
       |         |---- Step: Generate Artifact
       |
       |---- Stage 5: Deploy
                 |
                 |---- Step: Deploy Application
```

Remember:

- Pipeline = Complete automation workflow.
- Stage = Logical phase of the workflow.
- Step = Individual operation inside a stage.

### 3.5.5 Example Jenkinsfile

Let's look at a simple Declarative Pipeline.

```groovy
pipeline {

    agent any

    stages {

        stage('Checkout') {
            steps {
                echo 'Downloading application source code'
            }
        }

        stage('Build') {
            steps {
                echo 'Building the application'
            }
        }

        stage('Test') {
            steps {
                echo 'Executing application tests'
            }
        }

        stage('Package') {
            steps {
                echo 'Packaging the application'
            }
        }

        stage('Deploy') {
            steps {
                echo 'Deploying the application'
            }
        }
    }
}
```

Let's understand each section.

**pipeline**

Defines the complete Jenkins Pipeline.

**agent any**

Tells Jenkins that the pipeline can run on any available eligible agent.

An agent is the machine or execution environment where pipeline steps run.

**stages**

Contains the logical stages of the pipeline.

**stage('Checkout')**

Defines a stage named Checkout.

**steps**

Contains the individual operations Jenkins executes inside that stage.

**echo**

Prints a message in the Jenkins build console output.

Important:

This is a learning example. It prints messages and does not actually download, build, test, package, or deploy an application.

We will create working pipelines with real commands in upcoming practical lessons.

---

## 3.6 What Happens When a Stage Fails?

This is another important concept.

Imagine a pipeline with five stages:

```text
Checkout
    |
    v
Build
    |
    v
Test
    |
    v
Package
    |
    v
Deploy
```

Suppose the Build stage fails.

What happens?

In a normal sequential Declarative Pipeline, subsequent stages are skipped unless special conditions or error-handling mechanisms change the execution flow.

Example:

```text
Checkout  ---> SUCCESS

Build     ---> FAILURE

Test      ---> SKIPPED

Package   ---> SKIPPED

Deploy    ---> SKIPPED
```

Why is this useful?

Imagine an application has compilation errors.

There is no reason to deploy an application that has not been built successfully.

Jenkins helps prevent such situations by controlling pipeline execution.

### 3.6.1 Common Jenkins Build Results

| Build Result | Meaning |
|---|---|
| SUCCESS | Pipeline completed successfully |
| FAILURE | An error caused the build to fail |
| UNSTABLE | Build completed but one or more conditions, such as test results, indicate problems |
| ABORTED | Execution was stopped before normal completion |
| NOT_BUILT | Build was not executed |

---

## 3.7 How Jenkins Executes the Pipeline Internally

Let's understand the high-level execution flow.

```text
Developer Pushes Code
          |
          v
Trigger Activates Jenkins
          |
          v
Jenkins Schedules Build
          |
          v
Jenkins Selects an Agent
          |
          v
Pipeline Starts Execution
          |
          v
Stages Execute
          |
          v
Steps Execute
          |
          v
Build Result Is Recorded
          |
          v
Notifications / Reporting
```

Let's understand these activities.

**1. Trigger Activation**

A configured trigger or manual action requests execution.

**2. Build Scheduling**

Jenkins schedules the requested job based on its configuration and available execution capacity.

**3. Agent Selection**

Jenkins identifies an eligible execution environment.

**4. Pipeline Execution**

Jenkins reads and executes the pipeline definition.

**5. Stage and Step Execution**

The configured stages and steps perform the required activities.

**6. Result Recording**

Jenkins records the final build result and execution details.

**7. Notifications**

If configured, Jenkins sends notifications about the execution result.

---

## 3.8 Real-Time DevOps Example

Let's consider an organization that develops an e-commerce application.

The organization has:

- 5 developers.
- 2 testing engineers.
- 2 operations engineers.
- 1 GitHub repository.
- 1 Jenkins server.
- 1 testing environment.
- 1 production environment.

Without Jenkins:

Every time developers push code, engineers may need to manually download the code, build the application, execute tests, and deploy it.

With Jenkins:

1. Developers push code to GitHub.
2. GitHub sends a webhook notification.
3. Jenkins starts the pipeline.
4. Jenkins checks out the source code.
5. Jenkins builds the application.
6. Jenkins executes automated tests.
7. Jenkins packages the application.
8. Jenkins deploys to the testing environment.
9. Engineers verify the application.
10. A separately configured production deployment process can deploy approved changes.

This improves consistency, reduces repetitive manual work, and provides faster feedback.

**Important:** Production deployment should be protected using suitable approvals, access controls, and deployment strategies.

---

## 3.9 Important Concepts to Remember

| Concept | Explanation |
|---|---|
| Trigger | Determines when a job or pipeline starts |
| Job | A configured unit of work in Jenkins |
| Pipeline | Defines the complete automation workflow |
| Jenkinsfile | File containing pipeline instructions |
| Stage | Logical section of a pipeline |
| Step | Individual operation inside a stage |
| Agent | Execution environment for pipeline steps |
| Build | One execution of a Jenkins job or pipeline |
| Artifact | Generated output of the build process |
| Console Output | Execution logs produced during a build |

---

## 3.10 Lesson Summary

In this lesson, we understood how Jenkins solves the problems associated with manual software delivery.

We covered:

1. Manual software delivery workflow.
2. Problems with manual execution.
3. Automated software delivery workflow.
4. How Jenkins detects changes.
5. Different types of Jenkins triggers.
6. Jenkins Pipeline.
7. Stages and steps.
8. What happens when a stage fails.
9. How Jenkins executes a pipeline.
10. A real-time DevOps example.

The most important concept from this lesson is:

**Jenkins automates the execution of predefined software delivery activities using pipelines, stages, steps, and triggers.**

---

## 3.11 Interview Questions

**Q1. How does Jenkins solve the problems of manual software delivery?**

Jenkins automates repetitive software delivery activities such as source code checkout, application builds, testing, packaging, and deployment.

**Q2. What is a Jenkins trigger?**

A trigger is an event or condition that starts a Jenkins job or pipeline.

**Q3. What is the difference between Webhook and Poll SCM?**

Webhook is an event-based notification sent by the source control system to Jenkins.

Poll SCM periodically checks the source repository for changes.

**Q4. What is a Jenkins Pipeline?**

A Jenkins Pipeline is a defined sequence of automated activities used to build, test, and deliver software.

**Q5. What is the difference between a stage and a step?**

A stage is a logical phase of a pipeline, while a step is an individual operation performed within that stage.

**Q6. What is a Jenkinsfile?**

A Jenkinsfile is a text file that contains the Jenkins Pipeline definition and is commonly stored in the application's source code repository.

**Q7. What happens if the Build stage fails?**

In a normal sequential Declarative Pipeline, subsequent stages are skipped unless the pipeline explicitly defines alternative execution or error-handling behavior.

**Q8. Does Jenkins write application code?**

No. Developers write application code. Jenkins automates the configured activities required to build, test, and deliver that code.

---

## 3.12 Practical Learning - What We Will Implement Later

In upcoming practical lessons, we will implement this workflow using our Jenkins server on AWS EC2.

Our practical implementation will gradually include:

1. Connect Jenkins with GitHub.
2. Create our first Jenkins job.
3. Configure manual execution.
4. Configure automatic execution.
5. Understand Webhooks.
6. Create a Jenkinsfile.
7. Configure Checkout, Build, and Test stages.
8. Execute real Linux commands through Jenkins.
9. Understand build failures and console logs.
10. Build a complete CI pipeline.

We will implement each concept step by step rather than trying to configure everything at once.

---

**End of Lesson 03**
