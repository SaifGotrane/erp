import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// =====================================================================
// Jabnoun ERP — k6 Overload Load Test
//
// Tests the Supabase backend under heavy concurrent load to identify
// breaking points, latency degradation, and error rates.
//
// Prerequisites:
//   1. Install k6:  https://k6.io/docs/getting-started/installation/
//      - Windows:  choco install k6
//      - Or:       winget install grafana.k6
//   2. Set environment variables (or edit defaults below):
//      $env:K6_SUPABASE_URL = "https://dtivwyjgzjahegqnnqmr.supabase.co"
//      $env:K6_SUPABASE_ANON_KEY = "sb_publishable_odhIPkP5bhG-ocVCq0n5fw_iKM0AjET"
//      $env:K6_TEST_EMAIL = "your_test_employee@example.com"
//      $env:K6_TEST_PASSWORD = "your_password"
//   3. Run:
//      k6 run supabase/tests/k6_overload_test.js
//
// WARNING: This test sends real requests to the Supabase backend.
// Use a staging/test database if possible. Do NOT run against
// production with high VU counts.
// =====================================================================

// --- Configuration ---
const SUPABASE_URL = __ENV.K6_SUPABASE_URL || 'https://dtivwyjgzjahegqnnqmr.supabase.co';
const SUPABASE_ANON_KEY = __ENV.K6_SUPABASE_ANON_KEY || 'sb_publishable_odhIPkP5bhG-ocVCq0n5fw_iKM0AjET';
const TEST_EMAIL = __ENV.K6_TEST_EMAIL || '';
const TEST_PASSWORD = __ENV.K6_TEST_PASSWORD || '';

const HEADERS = {
  'apikey': SUPABASE_ANON_KEY,
  'Content-Type': 'application/json',
};

// --- Custom Metrics ---
const rpcCallSuccess = new Rate('rpc_success');
const rpcCallDuration = new Trend('rpc_duration', true);
const authSuccess = new Rate('auth_success');
const querySuccess = new Rate('query_success');
const queryDuration = new Trend('query_duration', true);

// --- Load Test Stages (Overload Pattern) ---
export const options = {
  stages: [
    // Warmup: 5 VUs for 30s
    { duration: '30s', target: 5 },

    // Ramp to moderate load: 20 VUs for 1m
    { duration: '1m', target: 20 },

    // Ramp to heavy load: 50 VUs for 2m
    { duration: '2m', target: 50 },

    // Spike to overload: 100 VUs for 1m
    { duration: '1m', target: 100 },

    // Hold at overload: 100 VUs for 2m
    { duration: '2m', target: 100 },

    // Drop back to moderate: 20 VUs for 1m
    { duration: '1m', target: 20 },

    // Recovery observation: 5 VUs for 30s
    { duration: '30s', target: 5 },
  ],
  thresholds: {
    // Fail if more than 10% of RPC calls error during overload
    'rpc_success': ['rate>0.90'],
    // Fail if p95 RPC latency exceeds 5s
    'rpc_duration': ['p(95)<5000'],
    // Fail if auth success drops below 95%
    'auth_success': ['rate>0.95'],
    // Fail if p95 query latency exceeds 3s
    'query_duration': ['p(95)<3000'],
    // Fail if more than 5% of queries error
    'query_success': ['rate>0.95'],
    // Overall HTTP errors should stay below 15%
    'http_req_failed': ['rate<0.15'],
  },
  // Don't abort on first error — we want to see the full overload curve
  abortOnFail: false,
};

// --- Authenticate and get JWT token ---
function authenticate() {
  const url = `${SUPABASE_URL}/auth/v1/token?grant_type=password`;
  const payload = JSON.stringify({
    email: TEST_EMAIL,
    password: TEST_PASSWORD,
  });

  const response = http.post(url, payload, {
    headers: { ...HEADERS, 'Content-Type': 'application/json' },
  });

  const success = check(response, {
    'auth status 200': (r) => r.status === 200,
    'auth has access_token': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.access_token !== undefined && body.access_token !== '';
      } catch (e) {
        return false;
      }
    },
  });

  authSuccess.add(success);

  if (!success) {
    console.error(`Auth failed: ${response.status} ${response.body}`);
    return null;
  }

  const body = JSON.parse(response.body);
  return body.access_token;
}

// --- Make an authenticated RPC call ---
function rpc(token, functionName, params = {}) {
  const url = `${SUPABASE_URL}/rest/v1/rpc/${functionName}`;
  const headers = {
    ...HEADERS,
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
  };

  const startTime = Date.now();
  const response = http.post(url, JSON.stringify(params), { headers });
  const duration = Date.now() - startTime;

  rpcCallDuration.add(duration);

  const success = check(response, {
    'rpc status 200': (r) => r.status === 200,
    'rpc not error': (r) => {
      if (r.status !== 200) return false;
      try {
        const body = JSON.parse(r.body);
        return !body.error;
      } catch (e) {
        return true; // Non-JSON 200 response is OK
      }
    },
  });

  rpcCallSuccess.add(success);

  if (!success && response.status !== 200) {
    // Don't log every error during overload (would flood console)
    if (__VU <= 5) {
      console.warn(`RPC ${functionName} failed: ${response.status} ${response.body?.substring(0, 200)}`);
    }
  }

  return { response, success, duration };
}

// --- Make an authenticated table query ---
function queryTable(token, table, select = '*', filters = {}) {
  let url = `${SUPABASE_URL}/rest/v1/${table}?select=${encodeURIComponent(select)}`;

  for (const [key, value] of Object.entries(filters)) {
    url += `&${key}=eq.${encodeURIComponent(value)}`;
  }

  const headers = {
    ...HEADERS,
    'Authorization': `Bearer ${token}`,
    'Range': '0-19', // Limit to 20 rows
  };

  const startTime = Date.now();
  const response = http.get(url, { headers });
  const duration = Date.now() - startTime;

  queryDuration.add(duration);

  const success = check(response, {
    'query status 200': (r) => r.status === 200 || r.status === 206,
  });

  querySuccess.add(success);

  return { response, success, duration };
}

// --- Main test scenario ---
export default function () {
  // Authenticate (each VU authenticates once per iteration)
  const token = authenticate();

  if (!token) {
    console.error(`VU ${__VU}: Authentication failed, skipping iteration`);
    sleep(1);
    return;
  }

  const authHeaders = {
    ...HEADERS,
    'Authorization': `Bearer ${token}`,
  };

  // --- READ operations (high frequency, low impact) ---
  group('Read Operations', () => {
    // Fetch sales list
    queryTable(token, 'sales', 'id,document_number,status,total_ttc,amount_paid,sale_date');

    sleep(0.1);

    // Fetch customers
    queryTable(token, 'customers', 'id,name');

    sleep(0.1);

    // Fetch articles
    queryTable(token, 'articles', 'id,reference,designation');

    sleep(0.1);

    // Fetch suppliers
    queryTable(token, 'suppliers', 'id,name');

    sleep(0.1);

    // Fetch stock levels
    queryTable(token, 'stock_levels', 'id,article_id,quantity');

    sleep(0.1);

    // Fetch payments
    queryTable(token, 'payments', 'id,document_number,amount,status,payment_date');
  });

  // --- REPORT operations (medium frequency, medium impact) ---
  group('Report Operations', () => {
    // Sales summary report
    rpc(token, 'report_sales_summary', {
      p_from: '2025-01-01',
      p_to: '2025-12-31',
    });

    sleep(0.2);

    // Purchases summary report
    rpc(token, 'report_purchases_summary', {
      p_from: '2025-01-01',
      p_to: '2025-12-31',
    });

    sleep(0.2);

    // Stock valuation report
    rpc(token, 'report_stock_valuation');

    sleep(0.2);

    // TVA summary
    rpc(token, 'report_tva_summary', {
      p_from: '2025-01-01',
      p_to: '2025-12-31',
    });
  });

  // --- WRITE operations (low frequency, high impact) ---
  // Only run writes for a subset of VUs to avoid creating too much test data
  if (__VU % 5 === 0) {
    group('Write Operations', () => {
      // Open a POS session
      const openResult = rpc(token, 'open_pos_session', {
        p_showroom_id: null,
        p_opening_cash: 100.000,
      });

      sleep(0.3);

      if (openResult.success) {
        let sessionId = null;
        try {
          const session = JSON.parse(openResult.response.body);
          sessionId = session.id;
        } catch (e) {
          // Session might already be open — that's OK during load test
        }

        if (sessionId) {
          sleep(0.5);

          // Close the POS session
          rpc(token, 'close_pos_session', {
            p_session_id: sessionId,
            p_closing_cash: 100.000,
            p_notes: 'k6 load test',
          });
        }
      }

      sleep(0.3);

      // Fetch employee profile (simulates app initialization)
      const userId = JSON.parse(
        http.post(`${SUPABASE_URL}/auth/v1/token?grant_type=password`,
          JSON.stringify({ email: TEST_EMAIL, password: TEST_PASSWORD }),
          { headers: HEADERS }
        ).body
      )?.user?.id;

      if (userId) {
        queryTable(token, 'employees', 'id,full_name,role,active', { id: userId });
        sleep(0.1);
        queryTable(token, 'employee_permissions', 'module,action,allowed', { employee_id: userId });
      }
    });
  }

  // Think time between iterations
  sleep(Math.random() * 2 + 1); // 1-3 seconds
}

// --- Setup: verify connectivity ---
export function setup() {
  if (!TEST_EMAIL || !TEST_PASSWORD) {
    console.error('ERROR: K6_TEST_EMAIL and K6_TEST_PASSWORD must be set!');
    console.error('Example:');
    console.error('  $env:K6_TEST_EMAIL = "admin@jabnoun.tn"');
    console.error('  $env:K6_TEST_PASSWORD = "your_password"');
    return { skip: true };
  }

  // Quick connectivity check
  const response = http.get(`${SUPABASE_URL}/rest/v1/`, {
    headers: HEADERS,
  });

  if (response.status === 401 || response.status === 403) {
    console.warn('Supabase API key may be invalid — proceeding anyway');
  }

  console.info(`Target: ${SUPABASE_URL}`);
  console.info(`Test user: ${TEST_EMAIL}`);
  console.info('Load test starting...');

  return { skip: false };
}

// --- Teardown: summary ---
export function teardown(data) {
  if (data.skip) return;
  console.info('Load test complete. Check metrics below.');
}

// --- Handle summary output ---
export function handleSummary(data) {
  const summary = {
    'overload_test_summary': {
      'timestamp': new Date().toISOString(),
      'target': SUPABASE_URL,
      'vu_peak': 100,
      'duration_total': '~8 minutes',
      'metrics': {
        'http_reqs': data.metrics.http_reqs?.values?.count || 0,
        'http_req_failed_pct': ((data.metrics.http_req_failed?.values?.rate || 0) * 100).toFixed(2) + '%',
        'http_req_duration_p95': (data.metrics.http_req_duration?.values?.['p(95)'] || 0).toFixed(0) + 'ms',
        'rpc_success_rate': ((data.metrics.rpc_success?.values?.rate || 0) * 100).toFixed(2) + '%',
        'rpc_duration_p95': (data.metrics.rpc_duration?.values?.['p(95)'] || 0).toFixed(0) + 'ms',
        'auth_success_rate': ((data.metrics.auth_success?.values?.rate || 0) * 100).toFixed(2) + '%',
        'query_success_rate': ((data.metrics.query_success?.values?.rate || 0) * 100).toFixed(2) + '%',
        'query_duration_p95': (data.metrics.query_duration?.values?.['p(95)'] || 0).toFixed(0) + 'ms',
      },
      'thresholds_passed': data.thresholds ? Object.entries(data.thresholds).map(([k, v]) => ({ [k]: v.ok })) : [],
    }
  };

  return {
    'stdout': JSON.stringify(summary, null, 2),
    'supabase/tests/k6_overload_results.json': JSON.stringify(summary, null, 2),
  };
}
