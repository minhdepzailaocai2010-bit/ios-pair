import http from 'node:http';
import { randomUUID, timingSafeEqual } from 'node:crypto';

const HOST = process.env.HOST ?? '127.0.0.1';
const PORT = Number(process.env.PORT ?? 8787);
const CLIENT_TOKEN = process.env.IOSPAIR_CLIENT_TOKEN;
const AGENT_TOKEN = process.env.IOSPAIR_AGENT_TOKEN;
const MAX_BODY = 22 * 1024 * 1024;
const JOB_TTL_MS = 15 * 60 * 1000;
const jobs = new Map();

if (!CLIENT_TOKEN || !AGENT_TOKEN || CLIENT_TOKEN === AGENT_TOKEN) {
  throw new Error('Set distinct IOSPAIR_CLIENT_TOKEN and IOSPAIR_AGENT_TOKEN values.');
}

function tokenMatches(header, expected) {
  if (!header?.startsWith('Bearer ')) return false;
  const supplied = Buffer.from(header.slice(7));
  const target = Buffer.from(expected);
  return supplied.length === target.length && timingSafeEqual(supplied, target);
}

function send(res, status, body) {
  const data = Buffer.from(JSON.stringify(body));
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': data.length,
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff'
  });
  res.end(data);
}

async function readJSON(req) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_BODY) throw Object.assign(new Error('Request body too large.'), { status: 413 });
    chunks.push(chunk);
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { throw Object.assign(new Error('Invalid JSON body.'), { status: 400 }); }
}

function cleanExpiredJobs() {
  const cutoff = Date.now() - JOB_TTL_MS;
  for (const [id, job] of jobs) if (job.createdAt < cutoff) jobs.delete(id);
}

const server = http.createServer(async (req, res) => {
  cleanExpiredJobs();
  const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);

  try {
    if (req.method === 'GET' && url.pathname === '/health') {
      return send(res, 200, { status: 'ok', service: 'ios-pair-relay' });
    }

    if (url.pathname === '/v1/jobs' && req.method === 'POST') {
      if (!tokenMatches(req.headers.authorization, CLIENT_TOKEN)) return send(res, 401, { error: 'unauthorized' });
      const body = await readJSON(req);
      const id = randomUUID();
      const job = {
        id,
        status: 'queued',
        createdAt: Date.now(),
        osVersion: String(body.os_version ?? '').slice(0, 32),
        deviceModel: String(body.device_model ?? '').slice(0, 64),
        requestedFormat: 'RPPairing',
        fileName: null,
        mimeType: null,
        fileBase64: null,
        message: 'Waiting for an authorized pairing agent.'
      };
      jobs.set(id, job);
      return send(res, 201, { id, status: job.status, message: job.message });
    }

    const jobMatch = url.pathname.match(/^\/v1\/jobs\/([a-f0-9-]{36})$/i);
    if (req.method === 'GET' && jobMatch) {
      if (!tokenMatches(req.headers.authorization, CLIENT_TOKEN)) return send(res, 401, { error: 'unauthorized' });
      const job = jobs.get(jobMatch[1]);
      if (!job) return send(res, 404, { error: 'job_not_found' });
      return send(res, 200, {
        id: job.id,
        status: job.status,
        file_name: job.fileName,
        mime_type: job.mimeType,
        file_base64: job.fileBase64,
        message: job.message
      });
    }

    if (req.method === 'GET' && url.pathname === '/v1/agent/jobs/next') {
      if (!tokenMatches(req.headers.authorization, AGENT_TOKEN)) return send(res, 401, { error: 'unauthorized' });
      const next = [...jobs.values()].find(job => job.status === 'queued');
      if (!next) return send(res, 204, {});
      next.status = 'in_progress';
      next.message = 'An authorized host agent accepted this job.';
      return send(res, 200, {
        id: next.id,
        os_version: next.osVersion,
        device_model: next.deviceModel,
        requested_format: next.requestedFormat
      });
    }

    const agentMatch = url.pathname.match(/^\/v1\/agent\/jobs\/([a-f0-9-]{36})\/(complete|fail)$/i);
    if (req.method === 'POST' && agentMatch) {
      if (!tokenMatches(req.headers.authorization, AGENT_TOKEN)) return send(res, 401, { error: 'unauthorized' });
      const job = jobs.get(agentMatch[1]);
      if (!job) return send(res, 404, { error: 'job_not_found' });
      const body = await readJSON(req);

      if (agentMatch[2] === 'fail') {
        job.status = 'failed';
        job.message = String(body.message ?? 'Pairing agent failed.').slice(0, 300);
        return send(res, 200, { id: job.id, status: job.status });
      }

      const encoded = String(body.file_base64 ?? '');
      const fileName = String(body.file_name ?? 'ios-pairing.rppairing').split(/[\\/]/).pop();
      if (!encoded || encoded.length > 21 * 1024 * 1024) return send(res, 400, { error: 'invalid_file_payload' });
      if (!/\.(rppairing|pairing|plist|mobiledevicepairing|json)$/i.test(fileName)) return send(res, 400, { error: 'unsupported_file_extension' });
      const bytes = Buffer.from(encoded, 'base64');
      if (!bytes.length || bytes.length > 15 * 1024 * 1024) return send(res, 400, { error: 'invalid_file_size' });
      job.fileBase64 = bytes.toString('base64');
      job.fileName = fileName;
      job.mimeType = String(body.mime_type ?? 'application/octet-stream').slice(0, 100);
      job.status = 'completed';
      job.message = 'Pairing record supplied by the authorized host agent.';
      return send(res, 200, { id: job.id, status: job.status });
    }

    return send(res, 404, { error: 'not_found' });
  } catch (error) {
    return send(res, error.status ?? 500, { error: error.message ?? 'internal_error' });
  }
});

server.listen(PORT, HOST, () => {
  process.stdout.write(`iOS Pair relay listening on http://${HOST}:${PORT}\n`);
  process.stdout.write('Place it behind a TLS reverse proxy before exposing it to the internet.\n');
});
