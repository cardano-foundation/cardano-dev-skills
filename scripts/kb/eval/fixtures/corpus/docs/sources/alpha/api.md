# Harbor client API

Reference for the Harbor client.

## Client constructor

The client constructor takes an endpoint, a region and an optional options object.

## Options object

Options configure the timeout, the retry limit and the user agent suffix.

## Timeout

The timeout option sets the request timeout in milliseconds; the default is thirty seconds.

## Retry limit

The retry limit option caps how many times a failed request is retried; the default is three.

## Backoff

Retries wait with exponential backoff and random jitter between attempts.

## Create queue call

Create a queue by name with optional tags and a visibility window override.

## Send call

Send publishes one message body and returns its identifier.

## Send batch call

Send batch publishes up to ten bodies and reports a result per entry.

## Receive call

Receive returns up to ten visible messages with receipt handles.

## Acknowledge call

Acknowledge deletes a message using its receipt handle.

## Change visibility call

Change visibility extends or shortens the window of a received message.

## List queues call

List queues returns queue names filtered by an optional prefix.

## Queue attributes call

Attributes return the approximate depth and the number of in flight messages.

## Pagination

List calls return a continuation token while more results remain.

## Error types

Errors carry a code, a message and a flag telling whether a retry may help.

## Throttling errors

Throttling errors are retried automatically up to the retry limit.

## Validation errors

Validation errors are never retried and point at the offending field.

## Authentication

Requests are signed with an access key pair read from the environment.

## Credential rotation

The client reloads credentials from the environment before they expire.

## Events

The client emits events for retries, throttling and connection changes.

## Types

Type definitions ship with the package and cover every call and result.

## Versioning

The API follows semantic versioning; removals only happen in major releases.
