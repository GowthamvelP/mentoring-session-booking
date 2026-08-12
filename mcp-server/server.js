#!/usr/bin/env node

/**
 * MentorBook MCP Server — stdio wrapper over HTTP API
 * 
 * This is a thin MCP (Model Context Protocol) server that translates
 * stdio JSON-RPC messages into HTTP calls to the Rails booking API.
 * 
 * Usage: node mcp-server/server.js
 * 
 * Kiro/Cursor connects via stdio; this process proxies to localhost:3000
 */

const http = require('http');
const readline = require('readline');

const API_BASE = process.env.MCP_API_URL || 'http://localhost:3000/api/v1/ai/mcp';
const USER_ID = process.env.MCP_USER_ID || '394274ca-5151-45bb-9d3d-6ccb1ba01106';
const ORG_ID = process.env.MCP_ORG_ID || '676d0426-b24e-4f4e-a752-50ea770e3b03';

// JSON-RPC response helper
function respond(id, result) {
  const msg = JSON.stringify({ jsonrpc: '2.0', id, result });
  process.stdout.write(msg + '\n');
}

function respondError(id, code, message) {
  const msg = JSON.stringify({ jsonrpc: '2.0', id, error: { code, message } });
  process.stdout.write(msg + '\n');
}

// HTTP call to Rails MCP endpoint
function callApi(path, body) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, API_BASE.replace('/ai/mcp', ''));
    const postData = body ? JSON.stringify(body) : '';
    
    const options = {
      hostname: url.hostname,
      port: url.port || 3000,
      path: url.pathname,
      method: body ? 'POST' : 'GET',
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': USER_ID,
        'X-Org-Id': ORG_ID,
        'Content-Length': Buffer.byteLength(postData),
      },
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`Invalid JSON: ${data}`));
        }
      });
    });

    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

// Handle MCP protocol messages
async function handleMessage(msg) {
  const { id, method, params } = msg;

  switch (method) {
    case 'initialize':
      respond(id, {
        protocolVersion: '2024-11-05',
        capabilities: { tools: {} },
        serverInfo: {
          name: 'mentorbook-mcp',
          version: '1.0.0',
        },
      });
      break;

    case 'notifications/initialized':
      // No response needed for notifications
      break;

    case 'tools/list':
      try {
        const tools = await callApi('/api/v1/ai/mcp/tools');
        const mcpTools = tools.tools.map((t) => ({
          name: t.name,
          description: t.description,
          inputSchema: t.input_schema,
        }));
        respond(id, { tools: mcpTools });
      } catch (e) {
        respondError(id, -32000, `Failed to list tools: ${e.message}`);
      }
      break;

    case 'tools/call':
      try {
        const { name, arguments: args } = params;
        const result = await callApi('/api/v1/ai/mcp/call', {
          name,
          arguments: args || {},
        });
        respond(id, {
          content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
        });
      } catch (e) {
        respondError(id, -32000, `Tool call failed: ${e.message}`);
      }
      break;

    default:
      if (id) {
        respondError(id, -32601, `Method not found: ${method}`);
      }
  }
}

// Read JSON-RPC from stdin (line-delimited)
const rl = readline.createInterface({ input: process.stdin });

rl.on('line', (line) => {
  try {
    const msg = JSON.parse(line);
    handleMessage(msg);
  } catch (e) {
    // Ignore malformed input
  }
});

// Signal ready
process.stderr.write('MentorBook MCP Server running (stdio → HTTP proxy)\n');
