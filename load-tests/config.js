// Shared configuration — dev and production profiles import from here
export const profiles = {
  dev: {
    concurrency: { vus: 5, iterations: 5, maxDuration: '15s' },
    idempotency: { vus: 3, iterations: 10, maxDuration: '15s' },
    rateLimiting: { vus: 1, iterations: 15, maxDuration: '10s' },
    multiTenant: { vus: 3, iterations: 10, maxDuration: '10s' },
    bookingFlow: { stages: [{d:'5s',t:5},{d:'10s',t:10},{d:'5s',t:0}] },
    thresholds: {
      concurrency: { bookings: 'count==1', checks: 'rate>0.8' },
      idempotency: { created: 'count<=1', checks: 'rate>0.8' },
      bookingFlow: { duration: 'p(95)<1000', failed: 'rate<0.3' },
    },
  },
  production: {
    concurrency: { vus: 100, iterations: 100, maxDuration: '30s' },
    idempotency: { vus: 50, iterations: 500, maxDuration: '60s' },
    rateLimiting: { vus: 1, iterations: 30, maxDuration: '10s' },
    multiTenant: { vus: 20, iterations: 100, maxDuration: '15s' },
    bookingFlow: { stages: [{d:'10s',t:20},{d:'20s',t:100},{d:'20s',t:200},{d:'10s',t:0}] },
    thresholds: {
      concurrency: { bookings: 'count==1', checks: 'rate>0.95' },
      idempotency: { created: 'count<=1', checks: 'rate>0.95' },
      bookingFlow: { duration: 'p(95)<200', failed: 'rate<0.05' },
    },
  },
}
