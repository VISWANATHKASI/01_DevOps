# 2. Why Do We Need Jenkins?

## 2.1 Real-World Example

Let's understand why Jenkins is required with a real-world example.

Imagine you are working in a software development company.

Your development team consists of:

- 5 Developers
- 1 Testing Team
- 2 Deployment Engineers

Developers write application code and push it to a GitHub repository.

Whenever a developer makes changes to the application, several activities need to be performed.

## 2.2 Manual Software Delivery Process

Without automation, the team needs to perform the following activities manually:

1. Download the latest source code.
2. Compile the application.
3. Check whether compilation is successful.
4. Execute test cases.
5. Generate build files.
6. Deploy the application to a server.

Imagine performing all these activities manually every time a developer changes the code.

## 2.3 Problems with Manual Software Delivery

Manual software delivery has several disadvantages:

- **Time-consuming:** Developers and deployment engineers spend time on repetitive activities.
- **Human Errors:** Manual execution can introduce mistakes.
- **Delayed Delivery:** Every release requires manual effort.
- **Inconsistent Process:** Different engineers may follow different procedures.
- **Difficult to Scale:** As the number of developers and releases increases, manual work also increases.

## 2.4 Why Do We Need Automation?

To overcome these problems, companies use automation tools such as Jenkins.

Jenkins automates repetitive software development activities and executes configured tasks whenever a particular trigger occurs.

Instead of performing every activity manually, we configure Jenkins to execute the required steps automatically.

## 2.5 Conclusion

Jenkins helps organizations reduce manual effort, improve consistency, identify errors early, and deliver software faster.

**In simple words:** We need Jenkins to automate repetitive software development and delivery activities.
