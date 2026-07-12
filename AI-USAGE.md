# AI Usage Disclosure

I used AI extensively during this assignment for analysis, implementation support, testing ideas, and documentation. I treated its output as draft material rather than as an authoritative source.

## How I used AI

AI assisted with:

* reviewing the supplied starter implementation against the assignment requirements and API contract;
* identifying likely correctness, security, tenancy, billing, and asynchronous-state failure modes;
* proposing the Riverpod, repository, API, and fake-backend structure;
* drafting portions of DTOs, providers, error mappings, test cases, and documentation;
* reviewing the final documentation for inconsistencies and claims that were stronger than the implementation supported.

## Examples where AI output was wrong, incomplete, or stale

I did not accept all generated suggestions unchanged. Examples include:

* AI initially produced several ADRs even though the assignment requested one. I removed the additional ADRs and retained only the most consequential architectural decision.
* Some early wording made compile-time configuration sound like secure secret storage. I corrected this because values supplied through `--dart-define` are compiled into the application and must not be treated as production secrets.
* Earlier documentation described planned tests and platform verification as though they were already completed. I revised those sections to match the files and evidence actually included in the repository.
* An early state-management design divided related screen state across too many independent providers. I consolidated the asynchronous SMS-console state into a tenant-keyed `AsyncNotifierProvider.family` while keeping selected-tenant state simple.
* During development, some implementation and documentation drafts became inconsistent as the architecture changed. I reconciled the final README, ADR, review, tests, and provider wiring against the submitted code.

## What I personally owned and verified

I was responsible for:

* deciding the final scope and prioritizing which starter-code problems to fix;
* choosing the final architecture and understanding the tradeoffs behind it;
* deciding which contract ambiguities required documented assumptions rather than invented backend behavior;
* checking the retained review findings against the supplied source and API contract;
* integrating, modifying, and debugging AI-assisted code;
* removing or rewriting claims that were not supported by the final repository;
* making the final submission decisions and taking responsibility for the resulting implementation.

## Final responsibility

AI contributed substantially to the drafting and development process, but it did not replace my responsibility to understand and validate the submission. The final code and committed evidence are the source of truth. Where generated documentation conflicted with the implementation, I corrected the documentation rather than presenting an unsupported claim.
