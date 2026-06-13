# agentsec-aws

**Production AI agent security on AWS — opinionated lessons + runnable Terraform.**

AI agents in production fail in expensive, embarrassing ways: leaked credentials, runaway inference bills, over-permissioned IAM roles, unsecured MCP servers. This repo is a module-per-week stack of fixes. Every module is:

- **A lesson** — an opinionated README explaining the attack/failure mode and the pattern that stops it.
- **A PoC** — `terraform apply` in ~10 minutes, with a cost estimate and a teardown command.

> Built in public by [Adam Koyuncu](https://github.com/adamkoy) — I secure AI agents in production on AWS.

## Modules

| # | Module | Status |
|---|--------|--------|
| 01 | [Bedrock spend kill-switch](modules/01-bedrock-spend-killswitch/) — hard-stop your agent's Bedrock access when spend crosses a budget threshold | 🚧 In progress |
| 02 | Agent IAM — least-privilege role patterns for agents (and the ways your agent leaks AWS credentials) | Planned |
| 03 | MCP secure deployment — running MCP servers on AWS without handing out the keys | Planned |
| 04 | Prompt-injection blast-radius containment | Planned |
| 05 | Agent audit trail — CloudTrail + structured agent action logging | Planned |

## Principles

1. **Deny by default.** Agents get the narrowest possible permissions, with hard backstops.
2. **Runnable or it didn't happen.** Every pattern ships as Terraform you can apply and tear down in minutes.
3. **Cost-honest.** Every module states what it costs to run the demo.

## License

Apache-2.0
