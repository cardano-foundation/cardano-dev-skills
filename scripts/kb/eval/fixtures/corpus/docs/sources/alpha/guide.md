# Harbor guide

This guide walks through installing and using the Harbor queue client.

## Overview

Harbor is a small queue service used to demonstrate the evaluation harness.

## Requirements

You need a recent runtime and about fifty megabytes of free disk space.

## Install via npm

Run the package manager install command with the harbor package name to add the client library.

## Install from source

Clone the repository, then run the build script to produce the client bundle.

## First queue

Create a queue called demo with the create call and check that it appears in the listing.

```sh
# create the demo queue
harbor create demo
## still inside the fence
```

## Sending messages

Publish a message body to a queue; the call returns a message identifier.

## Receiving messages

Poll a queue to receive the oldest visible message and its receipt handle.

## Acknowledging messages

Acknowledge a message with its receipt handle so it is not delivered again.

## Visibility window

A received message stays invisible to other consumers for the visibility window.

## Dead letter queues

Messages that fail repeatedly move to the dead letter queue for inspection.

## Message ordering

Messages are delivered roughly in order; strict ordering needs a single consumer.

## Batching

Send and receive up to ten messages per call to reduce round trips.

## Message size

A message body may hold at most sixty four kilobytes of text.

## Queue naming

Queue names use lowercase letters, digits and dashes, up to sixty characters.

## Tagging queues

Attach key value tags to a queue to group them for billing reports.

## Deleting queues

Deleting a queue discards every message it still holds.

## Purging queues

Purge removes all messages but keeps the queue and its settings.

## Local development

Start the embedded server on localhost to develop without a network.

~~~
# also not a heading
~~~

## Environment variables

Set the endpoint and region variables to point the client at a deployment.

## Logging

Enable debug logging to print each request and response summary.

## Upgrading

Read the release notes before upgrading across a major version.

## Uninstalling

Remove the package and delete the local data directory.

## Getting help

Open an issue in the project tracker with the client version and a short reproduction.
