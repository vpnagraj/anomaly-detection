1.  **Technical Challenges** Describe the greatest challenge(s) you encountered in translating the template from CloudFormation to Terraform. (1-2 paragraphs)

    To be honest, the translation from CF to Terraform couldn't have been easier. Per the guidance in the instruction, I used GenAI (Claude Opus 4.6 with Extended Thinking) and with *one shot* (!) I was able to fully convert the CF template into a working Terraform implementation, complete with learning-focused documentation (tips, tricks, and pointers to useful Terraform API features). 

    I think this process was as smooth as it was thanks to the struggle I had in getting the CF template to work in the first place. For example, I wrestled with converting the bootstrap sh script into a cloud-init format. But since I did that hard work up front, that spec was lifted verbatim into a separate file that was called in Terraform.  

2.  **Access Permissions** What element (specify file and line #) grants the SNS subscription permission to send messages to your API? Locate and explain your answer.

    This is kind of a tricky question. As I have it implemented, I don't think the SNS subscription is *granted permission to the API. Instead, the EC2 instance is allowed to subscribe to the endpoint defined in the SNS topic. Line 67 in `main.tf` grants that permission to the EC2 instance role, with a scope specific to the topic ARN.

3.  **Event flow and reliability**: Trace the path of a single CSV file from the moment it is uploaded to raw/ in S3 until the FastAPI app processes it. What happens if the EC2 instance is down or the /notify endpoint returns an error? How does SNS behave (e.g., retries, dead-letter behavior), and what would you change if this needed to be production-grade?

    If the instance is down or the endpoint errors out, while the file that triggered the SNS message will remain in S3 the message itself will eventually disappear. To fix in production, we'd probably want to configure a dead letter queue setting (that would go to SQS) so the messages weren't lost like tears in the rain.

4.  **IAM and least privilege**: The IAM policy for the EC2 instance grants full access to one S3 bucket. List the specific S3 operations the application actually performs (e.g., GetObject, PutObject, ListBucket). Could you replace the “full access” policy with a minimal set of permissions that still allows the app to work? What would that policy look like?

    The IAM policy grants access to GetObject, PutObject, DeleteObject, and ListBucket for the bucket created in this stack. The app uses all of these except the DeleteObject. To better scope the policy, we could remove the allowance for the s3:DeleteObject action in the launch template.

5.  **Architecture and scaling**: This solution uses batch-file events (S3 + SNS) to drive processing, with a rolling statistical baseline in memory and in S3. How would the design change if you needed to handle 100x more CSV files per hour, or if multiple EC2 instances were processing files from the same bucket? Address consistency of the shared baseline.json, concurrent processing, and any tradeoffs.

    In think the key failure point is similar to what we saw in the Lab 5 questions. If we expect a large amount of requests, then we would need to have muliple FastAPI endpoints, and the stack isn't set up for that as-is. Also, if those endpoints were hit concurrently, there would be a race condition for the shared baseline.json. A more robust solution would be a database, which would handle concurrency. The tradeoff is that including a database in the stack adds more complexity, both in terms of initial setup and long-term maintenance.