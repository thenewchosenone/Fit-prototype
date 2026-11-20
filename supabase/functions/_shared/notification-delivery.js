export function isTransientPushFailure(statusCode) {
  return statusCode <= 0 || statusCode === 408 || statusCode === 429
    || statusCode === 401 || statusCode === 403 || statusCode >= 500;
}

export function shouldMarkApnsDeliveryComplete(delivered, transientFailure) {
  return delivered || !transientFailure;
}
