# DWP Prompt Library — Prompt Engineering Examples (Day 2)

## Example 1

### Wrong Prompt
"write something for the user about their email"

### Correct Prompt
You are a DWP service-desk analyst. Review the user's email and create a professional incident closure note. Summarize the issue reported, actions taken, resolution provided, and customer impact in no more than 5 bullet points. Use only information present in the email. If any detail is missing, state "to confirm". Return only the closure note.

---

## Example 2

### Wrong Prompt
"you are a helpful assistant who always gives detailed, accurate, professional, well-structured, clear and concise answers. Tell me about Intune."

### Correct Prompt
You are a DWP analyst. Explain Microsoft Intune to a new IT support engineer. Provide:
1. Purpose
2. Key capabilities
3. Common use cases
4. Integration with Microsoft 365
5. Three real-world examples

Keep the explanation under 300 words and use simple technical language.

---

## Example 3

### Wrong Prompt
"A user says their laptop is slow. What is the problem and fix it."

### Correct Prompt
You are a DWP service-desk analyst. A user reports that a newly deployed Windows 11 laptop is running slowly. List the five most likely causes in order of probability. For each cause provide:
- Likely reason; Single fastest validation step; Recommended remediation

---

## Example 4

### Wrong Prompt
"List every possible reason a Windows 11 device might have any kind of issue connecting to any kind of network resource."

### Correct Prompt
You are a DWP service-desk analyst. Create a troubleshooting guide for network connectivity issues on Windows 11 devices. Group causes into:
- Network connectivity; DNS; Firewall; Authentication problem; Security; Server Issues

For each category provide the top three causes and the first troubleshooting check.

---

## Example 5

### Wrong Prompt
"Rewrite this so it sounds better: 'Device non-compliant due to BitLocker not enabled. Remediation applied. Compliance restored.'"

### Correct Prompt
You are a DWP service-desk analyst preparing customer-facing closure notes. Rewrite the following statement in a professional and concise manner suitable for an incident ticket update. Preserve the original meaning and avoid adding new information.

---

## Example 6

### Wrong Prompt
"You are a senior DWP engineer with 20 years experience. A user cannot log in. Solve this completely and give me the guaranteed fix."

### Correct Prompt
You are a DWP Senior support engineer. A user reports being unable to sign in. Based on the information provided, generate:
- Most likely causes (ranked); Required diagnostic checks; Possible resolutions; Missing information needed for confirmation

Do not claim a guaranteed fix or assume facts not provided.
