# Development handoff

## Implemented versus planned

**Currently implemented:** JacHammer blank-canvas web-app scaffolding, its configured Jac/shadcn client dependencies, a minimal client entry, and template UI components. The UniPath LK pathway flow, backend, graph, fixtures, session isolation, tests, and verified real catalogue are not implemented by this documentation-only update.

**Deferred for local development:** the complete student profile and goal flow; owned planning sessions; fixture graph and bounded walker; deterministic eligibility/cost validation; clarification and resume; accessible graph and text-pathway results; actual activity events; optional bounded LLM actions and labeled rules fallback; test suite; source-reviewed real catalogue. Broader programme coverage, administration, refresh automation, advanced financing, Minimum Change Finder, gap analysis, scenario comparisons, Sinhala localization, and evaluation remain later work.

## Local/GitHub/JacHammer round trip

1. In JacHammer, connect the intended GitHub repository through the Git panel and push the project. Do not change repository visibility, create a remote, or enable automatic production deployment without an explicit decision.
2. Clone that repository locally. Check the current branch and commit before making changes; create a feature branch and review diffs before committing.
3. Follow `AGENTS.md`. Preserve one project root and the JacHammer-generated project identity/configuration. Run the checks supported by the checked-out runtime, and report exactly what passed. Do not make an unverified pathway recommendation merely to make a test/demo pass.
4. Review and merge work into the agreed integration branch, then push it to GitHub.
5. Return to the same JacHammer project. Use its Git panel to pull the intended branch/commit and confirm the checked-out commit before relying on preview output.
6. Review the live preview after code/configuration changes. Configure any application provider secrets in the JacHammer Settings environment section; do not commit credentials. Restart preview if an environment change requires it.
7. Choose deployment only through the Deploy tab after an explicit decision. Confirm whether the offered target is temporary sandbox or permanent/production deployment; this repository has not been deployed by this handoff.

## Verification and limitations

The Markdown updates were written in this workspace; no Jac source, runtime check, build, application flow, Git remote operation, provider call, catalogue verification, or deployment is asserted by this documentation-only task. Recheck exact install, check, test, and build commands against the actual Jac 0.34.23 installation and project scripts before claiming them as verified. The initial real catalogue should remain empty until claim-specific official sources are reviewed.

## Prioritized next tasks

1. Implement the smallest Jac graph-backed vertical slice with a fictional fixture and a server-to-client request/resume path.
2. Add deterministic validation, explicit unknowns, bounded traversal, ownership boundaries, and focused tests before expanding UI behavior.
3. Build the responsive profile/results UI, real graph visualization plus accessible text paths, event log, and stale-result rerun behavior.
4. Add an optional constrained Jac `by llm()` planner only after rules fallback and routine tests work without credentials.
5. Review official sources for any real catalogue claim and attach claim-specific evidence.
