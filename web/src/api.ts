import axios from 'axios'

export const api = axios.create({ baseURL: '/' })

export interface FileItem {
  name: string
  size: number
  mtime: string
  type: 'word' | 'cell' | 'slide' | 'pdf' | 'unknown'
}

export const listFiles = () => api.get<FileItem[]>('/api/files').then(r => r.data)

export const newFile = (name: string, kind: string) =>
  api.post<{ name: string }>('/api/files', { name, kind }).then(r => r.data)

export const uploadFile = (name: string, file: File) =>
  api.put(`/api/files/${encodeURIComponent(name)}`, file, {
    headers: { 'Content-Type': 'application/octet-stream' },
  })

export const deleteFile = (name: string) =>
  api.delete(`/api/files/${encodeURIComponent(name)}`)

export const getSecret = () =>
  api.get<{ jwt_secret: string }>('/api/secret').then(r => r.data.jwt_secret)

export const getEditorConfig = (file: string, type: 'desktop' | 'mobile' = 'desktop') =>
  api.get(`/api/editor-config`, { params: { file, type } }).then(r => r.data)
