# Native OpenTelemetry report

| Measurement | Value |
|---|---|
| events | 301 |
| spans | 325 |
| completed_agent_calls | 0 |
| completed_tool_calls | 84 |
| failed_tool_calls | 1 |
| reported_api_requests | 68 |
| api_error_events | 0 |
| workflow_wall_time_s | 1981.381 |
| workflow_exit_code | 0 |
| input_tokens | 0.0 |
| output_tokens | 47479.0 |
| cache_read_tokens | 0.0 |
| cache_creation_tokens | 0.0 |
| cost_usd | 0.94958 |

Roles: {}

## Data quality

No parsing/export warnings detected.

Counts cover received completed events; interrupted calls may lack completion records. Spans retain parent IDs for the native call tree. Token/cost totals sum reported API request events once, including any subagent events received; they are not independently verified billing. Periodic metrics are exported separately and are not summed again.

No custom hook collection or file snapshots are used. Agent output correctness and hardware/PPA metrics belong to the project evaluator. Tool details and public assistant text may appear in these local files; prompts and raw API bodies are disabled. Hidden reasoning is not reconstructed.
