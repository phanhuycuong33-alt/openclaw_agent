# Worker Report Specification

Every worker must finish by writing exactly one result file.

Mandatory fields:
- worker
- task
- status
- next_action
- blocker
- provider
- artifact
- summary

Status values:
- PASS
- FAILED
- BLOCKED
- REQUIRES_USER_ACTION

next_action values:
- NONE
- CALL_AUTH
- CALL_PUBLISH
- CALL_GENERATE
- RETRY
- USER_ACTION

A worker never calls another worker directly. Only the Supervisor decides what worker runs next.
