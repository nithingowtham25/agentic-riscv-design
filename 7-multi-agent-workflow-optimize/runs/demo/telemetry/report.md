# Native OpenTelemetry report

| Measurement | Value |
|---|---|
| events | 143 |
| spans | 144 |
| completed_agent_calls | 5 |
| completed_tool_calls | 36 |
| failed_tool_calls | 1 |
| reported_api_requests | 35 |
| api_error_events | 0 |
| workflow_wall_time_s | 131.543 |
| workflow_exit_code | 0 |
| input_tokens | 0.0 |
| output_tokens | 10704.0 |
| cache_read_tokens | 0.0 |
| cache_creation_tokens | 0.0 |
| cost_usd | 0.21408 |

Roles: {"organizer": 2, "verifier": 2, "builder": 1}

## Data quality

No parsing/export warnings detected.

Counts cover received completed events; interrupted calls may lack completion records. Spans retain parent IDs for the native call tree. Token/cost totals sum reported API request events once, including any subagent events received; they are not independently verified billing. Periodic metrics are exported separately and are not summed again.

No custom hook collection or file snapshots are used. Agent output correctness and hardware/PPA metrics belong to the project evaluator. Tool details and public assistant text may appear in these local files; prompts and raw API bodies are disabled. Hidden reasoning is not reconstructed.
