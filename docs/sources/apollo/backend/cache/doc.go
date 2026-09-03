// Package cache wraps any chain backend with time-based caching of the
// responses that rarely change, notably protocol and genesis parameters, to
// cut repeated provider requests during a build.
package cache
