
GitHub merge-queues provide a way to merge PRs ensuring that the project's `main` branch continues to build in CI.

GitHub concurrency provides a way to cancel redundant jobs when a new commit is pushed to a PR, making the old job obsolete.

Note that these two features do not easily work together. GitHub merge-queues are designed to queue up multiple builds on the same branch. When combined with GitHub concurrency, new jobs in the merge-queue can cancel older jobs. If the old jobs are cancelled, the merge-queue can fail entirely, resulting in the cancellation of the new jobs as well.

To avoid this scenario, concurrency must be carefully configured to avoid interfering with the operation of merge-queues.

Below is an example of a concurrent configuration:

```yaml
    concurrency:
      group: >
        a+${{ github.event_name }}
        b+${{ github.workflow_ref }}
        c+${{ github.job }}
        d+${{ matrix.ghc }}
        e+${{ matrix.cabal }}
        f+${{ matrix.os }}
        g+${{ (startsWith(github.ref, 'refs/heads/gh-readonly-queue/') && github.run_id) || github.event.pull_request.number || github.ref }}
      cancel-in-progress: true
```

The `>` symbol is `yaml` operator, which means that the text in the nested block is used to construct a string with no new lines.

The `group` field defines a concurrency key, instructing GitHub Actions to cancel any older jobs that share the same key. It is crucial to define this field carefully. If it is too general, unintended jobs may be cancelled, and if it is specific, the desired jobs may not be cancelled.

Each line in the `group` block defines a component of the concurrency key. It is conventionally useful to begin each component with `<letter>+`. This helps when printing the key without the prefix (eg, for debugging), as the `>` `yaml` operator combines multiple lines into a single line, making it challenging to determine which substring corresponds to each component in the `yaml` file. By utilizing the `<letter>+` prefix, we can easily identify the substring and associate it with the key component in the workflow.

The components as identified by their prefix are included because:

* `a`: Jobs triggered due to different GitHub events should not cancel each other
* `b`: Jobs triggered due to different GitHub workflow references (for example branches) should not cancel each other
* `c`: Jobs with different job names (for example linting vs building) should not cancel each other
* `d`: Jobs that build with different `ghc` versions should not cancel each other
* `e`: Jobs that build with different `cabal` versions should not cancel each other
* `f`: Jobs that build on different `os`es should not cancel each other
* `g`: Jobs on the merge queue should not cancel each other

The `cancel-in-progress` signals to GitHub Actions that if two jobs with the same concurrency key are running concurrently, the older one should be cancelled.
