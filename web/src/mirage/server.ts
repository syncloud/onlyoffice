import { createServer, Response } from 'miragejs'
import type { FileItem } from '../api'

type MirageRequest = {
  params: Record<string, string>
  requestBody?: string
  url: string
}

const state = {
  jwtSecret: 'dev-stub-jwt-secret-replace-with-real-one-on-device',
  files: [
    { name: 'Quarterly report.docx', size: 36563, mtime: '2026-05-03T08:00:00Z', type: 'word' },
    { name: 'Budget 2026.xlsx',      size: 4784,  mtime: '2026-04-29T17:30:00Z', type: 'cell' },
    { name: 'Onboarding deck.pptx',  size: 27387, mtime: '2026-04-21T09:15:00Z', type: 'slide' },
    { name: 'Contract.pdf',          size: 313,   mtime: '2026-04-19T14:00:00Z', type: 'pdf' },
  ] as FileItem[],
}

export function makeServer() {
  return createServer({
    routes() {
      this.get('/api/files', () => state.files)

      this.post('/api/files', (_: unknown, request: MirageRequest) => {
        const body = JSON.parse(request.requestBody ?? '{}') as { name: string; kind: string }
        const f: FileItem = {
          name: body.name,
          size: 1024,
          mtime: new Date().toISOString(),
          type: ({ docx: 'word', xlsx: 'cell', pptx: 'slide', pdf: 'pdf' }[body.kind] ?? 'unknown') as FileItem['type'],
        }
        state.files.unshift(f)
        return new Response(201, {}, { name: f.name })
      })

      this.put('/api/files/:name', (_: unknown, request: MirageRequest) => {
        const name = decodeURIComponent(request.params.name)
        const ext = name.split('.').pop()?.toLowerCase() ?? ''
        const type = ({ docx: 'word', xlsx: 'cell', pptx: 'slide', pdf: 'pdf' } as Record<string, FileItem['type']>)[ext] ?? 'unknown'
        if (!state.files.find(f => f.name === name)) {
          state.files.unshift({ name, size: 2048, mtime: new Date().toISOString(), type })
        }
        return new Response(200, {}, { name })
      })

      this.delete('/api/files/:name', (_: unknown, request: MirageRequest) => {
        const name = decodeURIComponent(request.params.name)
        state.files = state.files.filter(f => f.name !== name)
        return new Response(200, {}, { name })
      })

      this.get('/api/secret', () => ({ jwt_secret: state.jwtSecret }))

      this.get('/api/editor-config', (_: unknown, request: MirageRequest) => {
        const url = new URL(request.url, window.location.origin)
        const file = url.searchParams.get('file') ?? ''
        return {
          document: { fileType: file.split('.').pop(), title: file, key: 'stub-key' },
          documentType: 'word',
          editorConfig: { mode: 'edit', user: { id: 'dev', name: 'dev' } },
        }
      })

      this.get('/web-apps/apps/api/documents/api.js', () => new Response(
        200,
        { 'Content-Type': 'application/javascript' },
        `window.DocsAPI = window.DocsAPI || {};
window.DocsAPI.DocEditor = function(id, cfg) {
  var el = document.getElementById(id);
  if (el) {
    el.innerHTML =
      '<div style="padding:24px;color:#aaa;font-family:sans-serif">' +
      '<h2 style="margin:0 0 12px">' + (cfg.document && cfg.document.title || '') + '</h2>' +
      '<p>dev stub editor — real OO editor renders here in production</p>' +
      '<pre style="font-size:11px;background:#222;padding:12px;border-radius:4px;overflow:auto">' +
      JSON.stringify(cfg, null, 2) +
      '</pre></div>';
  }
  setTimeout(function() {
    if (cfg.events && cfg.events.onAppReady) cfg.events.onAppReady();
  }, 100);
  return { destroyEditor: function() { if (el) el.innerHTML = ''; } };
};
`,
      ))
    },
  })
}
