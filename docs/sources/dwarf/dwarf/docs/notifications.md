# Notifications & webhooks (slice 49)

Operators register handlers in `dwarf/state/config.yaml` to fire when
scenario lifecycle events occur. Three event types are supported:

| event                              | fires when                                              |
| ---------------------------------- | ------------------------------------------------------- |
| `on_scenario_fail`                 | a scenario completes with a `fail` exit_status          |
| `on_coverage_regression`           | coverage report regresses versus the prior baseline     |
| `on_assertion_population_shift`    | assertion pass/fail population significantly changes    |

## Handler types

| type      | description                                                              |
| --------- | ------------------------------------------------------------------------ |
| `webhook` | POST a JSON body `{event, body}` to a URL.                              |
| `slack`   | POST a Slack-formatted `{text}` payload to an incoming-webhook URL.     |
| `email`   | SMTP send via `notifications.smtp.host`. Skipped if SMTP unconfigured.  |

## Configuration

```yaml
notifications:
  on_scenario_fail:
    - type: webhook
      url: https://example.com/dwarf-hook
    - type: slack
      url: https://hooks.slack.com/services/T0/B0/XXXX
  on_coverage_regression:
    - type: email
      to: ops@example.com
  on_assertion_population_shift: []
  smtp:
    host: smtp.example.com
    port: 587
    from: dwarf@example.com
    starttls: true
    username: dwarf
    password: <set out-of-band>
```

## Sample payload schemas

### webhook

```json
{
  "event": "on_scenario_fail",
  "body": {
    "run_id": "20260427T154920Z-4bdcb76f",
    "scenario_id": "runtime-byzantine-peer-example-smoke",
    "exit_status": "fail",
    "summary": "2/8 assertions failed",
    "bundle_url": "/operate/runs/20260427T154920Z-4bdcb76f"
  }
}
```

### slack

The framework formats `body.summary` (or the full body if `summary` is
absent) inside a fenced code block. Slack incoming-webhook URLs accept
either `{text}` or `{blocks}`; this slice ships the simpler `text`
variant.

```json
{
  "text": "*dwarf · on scenario fail*\n```2/8 assertions failed```"
}
```

### email

Subject is `[dwarf] <event_type>`; body is JSON-pretty-printed `body`.

## Failure semantics

Handler dispatch is best-effort with a 5-second timeout per handler.
Failures are appended to `dwarf/state/notifications.log` as ndjson:

```ndjson
{"event": "on_scenario_fail", "type": "webhook", "ok": false, "detail": "transport: connection refused"}
```

A downstream outage **never** breaks a scenario run — the dispatcher
catches transport errors, records the outcome, and moves on.

## Verifying a handler

After editing `state/config.yaml`, restart the dashboard so the new
config is read. Then trigger a known-failing scenario or call the
dispatch helper directly:

```python
from profile_manager.data.notifications import dispatch
dispatch("on_scenario_fail", {"run_id": "test", "summary": "manual probe"})
```

Tail `state/notifications.log` to see the outcome.
